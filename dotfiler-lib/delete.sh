#!/usr/bin/env bash

# Delete function with tombstoning
# Permanently deletes files/directories from all systems with cross-machine enforcement

# Add entry to deleted items list with timestamp  
add_to_deleted_list() {
    local target="$1"
    local timestamp=$(date +%s)
    
    # Ensure config migration happens
    migrate_config_files
    
    # Check if already in deleted list
    if [[ -f "$DELETED_ITEMS" ]] && grep -q "^${target}|" "$DELETED_ITEMS"; then
        log_info "Item already in deletion list: $target"
        return 0
    fi
    
    # Add to deleted list with timestamp
    echo "${target}|${timestamp}" >> "$DELETED_ITEMS"
    log_info "Added to deletion list: $target"
}

# Add entry to ignored items list
add_to_ignored_list() {
    local target="$1"
    
    # Check if already in ignored list
    if [[ -f "$IGNORED_ITEMS" ]] && grep -Fxq "$target" "$IGNORED_ITEMS"; then
        log_info "Item already in ignore list: $target"
        return 0
    fi
    
    # Add to ignored list
    echo "$target" >> "$IGNORED_ITEMS"
    log_info "Added to ignore list: $target"
}

# Remove from filesystem (handles both files and directories)
remove_from_filesystem() {
    local target="$1"
    local needs_sudo="$2"
    
    if [[ ! -e "$target" ]] && [[ ! -L "$target" ]]; then
        log_info "Item already removed from filesystem: $target"
        return 0
    fi
    
    if [[ "$needs_sudo" == true ]]; then
        log_info "Removing with sudo: $target"
        sudo rm -rf "$target"
    else
        log_info "Removing: $target"
        rm -rf "$target"
    fi
    
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        log_error "Failed to remove: $target"
        return 1
    fi
    
    log_success "Removed from filesystem: $target"
}

# Remove from repository
remove_from_repository() {
    local target="$1"
    local target_tracked="$2"
    
    if [[ -z "$DOTFILESPATH" ]]; then
        log_error "DOTFILESPATH environment variable is not set"
        return 1
    fi
    
    if [[ -z "$OS" ]]; then
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    
    local repo_files_dir="$DOTFILESPATH/$OS/files"
    
    # Determine repo path
    local repo_path
    if [[ "$target_tracked" == '$HOME'* ]]; then
        local rel_path="${target_tracked#\$HOME/}"
        repo_path="$repo_files_dir/HOME/$rel_path"
    else
        local rel_path="${target_tracked#/}"
        repo_path="$repo_files_dir/$rel_path"
    fi
    
    if [[ -e "$repo_path" ]]; then
        log_info "Removing from repository: $repo_path"
        rm -rf "$repo_path"
        
        # Clean up empty parent directories
        local parent_dir="$(dirname "$repo_path")"
        while [[ "$parent_dir" != "$repo_files_dir" ]] && [[ "$parent_dir" != "/" ]]; do
            if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
                rmdir "$parent_dir" 2>/dev/null
                log_info "Removed empty directory: $parent_dir"
                parent_dir="$(dirname "$parent_dir")"
            else
                break
            fi
        done
        
        log_success "Removed from repository: $repo_path"
    else
        log_info "Item not in repository: $repo_path"
    fi
}

# Main delete command
cmd_delete() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: dotfiler delete <file_or_directory>"
        return 1
    fi
    
    # Ensure config migration happens
    migrate_config_files
    
    # Convert to absolute path
    local target_abs
    if [[ "$target" == "~"* ]]; then
        target_abs="${target/#\~/$HOME}"
    elif [[ "$target" != "/"* ]]; then
        if [[ -e "$target" ]]; then
            target_abs=$(realpath "$target")
        elif [[ -e "$HOME/$target" ]]; then
            target_abs=$(realpath "$HOME/$target")
        else
            target_abs="$target"
        fi
    else
        target_abs="$target"
    fi
    
    # Validate the path for security
    if ! validate_path "$target_abs" "target path"; then
        return 1
    fi
    
    # Convert to tracking format
    local target_tracked
    if [[ "$target_abs" == "$HOME"* ]]; then
        target_tracked='$HOME'"${target_abs#$HOME}"
    else
        target_tracked="$target_abs"
    fi
    
    log_warning "This will permanently delete '$target_abs' from all systems with tombstone protection."
    echo ""
    
    # Show what will be deleted
    if [[ -e "$target_abs" ]] || [[ -L "$target_abs" ]]; then
        if [[ -d "$target_abs" ]]; then
            echo "Directory contents:"
            ls -la "$target_abs" 2>/dev/null | head -10
            if [[ $(ls -1 "$target_abs" | wc -l) -gt 10 ]]; then
                echo "... and $(( $(ls -1 "$target_abs" | wc -l) - 10 )) more items"
            fi
        else
            echo "File: $(ls -la "$target_abs" 2>/dev/null)"
        fi
        echo ""
    fi
    
    # Confirmation prompt
    if ! prompt_user "Continue with permanent deletion?"; then
        log_info "Delete operation cancelled"
        return 0
    fi
    
    # Step 1: Add to deleted list (tombstone)
    log_info "Step 1: Creating tombstone..."
    add_to_deleted_list "$target_tracked"
    
    # Step 2: Add to ignored list
    log_info "Step 2: Adding to ignore list..."
    add_to_ignored_list "$target_tracked"
    
    # Step 3: Remove from repository
    log_info "Step 3: Removing from repository..."
    remove_from_repository "$target_abs" "$target_tracked"
    
    # Step 4: Remove from tracking list if it's directly tracked
    if [[ -f "$TRACKED_ITEMS" ]] && grep -Fxq "$target_tracked" "$TRACKED_ITEMS"; then
        log_info "Step 4: Removing from tracking list..."
        local temp_file
        temp_file=$(mktemp)
        
        while IFS= read -r line; do
            if [[ "$line" != "$target_tracked" ]]; then
                echo "$line" >> "$temp_file"
            fi
        done < "$TRACKED_ITEMS"
        
        cat "$temp_file" > "$TRACKED_ITEMS"
        rm "$temp_file"
        
        log_info "Removed from tracking: $target_tracked"
    fi
    
    # Step 5: Remove from filesystem
    log_info "Step 5: Removing from filesystem..."
    local needs_sudo=false
    if [[ "$target_abs" != "$HOME"* ]] && [[ "$target_abs" == "/"* ]]; then
        needs_sudo=true
    fi
    
    remove_from_filesystem "$target_abs" "$needs_sudo"
    
    log_success "Successfully deleted: $target_abs"
    log_info "This deletion will be enforced on other systems during their next build."
    log_info "Tombstone will be automatically cleaned up after 120 days if file doesn't reappear."
}

# Cleanup expired deletion tombstones (called during build)
cleanup_deleted_items() {
    if [[ ! -f "$DELETED_ITEMS" ]]; then
        return 0
    fi
    
    log_info "Cleaning up deletion tombstones..."
    
    local temp_file
    temp_file=$(mktemp)
    local current_time=$(date +%s)
    local retention_days=120
    local retention_seconds=$((retention_days * 24 * 60 * 60))
    local removed_count=0
    local updated_count=0
    
    while IFS='|' read -r item_path timestamp; do
        [[ -z "$item_path" ]] && continue
        
        # Add timestamp if missing (manual entries)
        if [[ -z "$timestamp" ]]; then
            echo "${item_path}|${current_time}" >> "$temp_file"
            log_info "Added timestamp to deletion entry: $item_path"
            updated_count=$((updated_count + 1))
            continue
        fi
        
        # Check if tombstone has expired
        local age_seconds=$((current_time - timestamp))
        if [[ $age_seconds -gt $retention_seconds ]]; then
            # Check if item exists on current filesystem
            local item_abs="${item_path/#\$HOME/$HOME}"
            if [[ -e "$item_abs" ]] || [[ -L "$item_abs" ]]; then
                # Item exists, keep tombstone and ignore entry (automated file)
                echo "${item_path}|${timestamp}" >> "$temp_file"
                log_info "Keeping tombstone for existing automated file: $item_path"
            else
                # Item doesn't exist, safe to remove tombstone and ignore entry
                log_info "Removing expired tombstone: $item_path (${retention_days} days old)"
                removed_count=$((removed_count + 1))
                
                # Remove from ignore list
                if [[ -f "$IGNORED_ITEMS" ]]; then
                    local temp_ignore
                    temp_ignore=$(mktemp)
                    while IFS= read -r ignore_line; do
                        if [[ "$ignore_line" != "$item_path" ]]; then
                            echo "$ignore_line" >> "$temp_ignore"
                        fi
                    done < "$IGNORED_ITEMS"
                    cat "$temp_ignore" > "$IGNORED_ITEMS"
                    rm "$temp_ignore"
                fi
            fi
        else
            # Keep unexpired tombstone
            echo "${item_path}|${timestamp}" >> "$temp_file"
        fi
        
    done < "$DELETED_ITEMS"
    
    # Update deleted items file
    cat "$temp_file" > "$DELETED_ITEMS"
    rm "$temp_file"
    
    # Remove file if empty
    if [[ ! -s "$DELETED_ITEMS" ]]; then
        rm "$DELETED_ITEMS"
        log_info "No more deletion tombstones, removed deleted.conf"
    fi
    
    if [[ $removed_count -gt 0 ]] || [[ $updated_count -gt 0 ]]; then
        log_success "Tombstone cleanup: $removed_count removed, $updated_count updated"
    fi
}

# Enforce deletions on other systems (called during build)
enforce_deletions() {
    if [[ ! -f "$DELETED_ITEMS" ]]; then
        return 0
    fi
    
    log_info "Enforcing cross-system deletions..."
    
    local current_time=$(date +%s)
    local enforcement_days=90
    local enforcement_seconds=$((enforcement_days * 24 * 60 * 60))
    local enforced_count=0
    
    while IFS='|' read -r item_path timestamp; do
        [[ -z "$item_path" ]] && continue
        [[ -z "$timestamp" ]] && continue
        
        # Only enforce deletions within enforcement window
        local age_seconds=$((current_time - timestamp))
        if [[ $age_seconds -le $enforcement_seconds ]]; then
            local item_abs="${item_path/#\$HOME/$HOME}"
            
            if [[ -e "$item_abs" ]] || [[ -L "$item_abs" ]]; then
                log_warning "Enforcing deletion on this system: $item_abs"
                
                # Determine if sudo needed
                local needs_sudo=false
                if [[ "$item_abs" != "$HOME"* ]] && [[ "$item_abs" == "/"* ]]; then
                    needs_sudo=true
                fi
                
                remove_from_filesystem "$item_abs" "$needs_sudo"
                enforced_count=$((enforced_count + 1))
            fi
        fi
        
    done < "$DELETED_ITEMS"
    
    if [[ $enforced_count -gt 0 ]]; then
        log_success "Enforced $enforced_count deletions on this system"
    fi
}

# Prompt user for confirmation (reuse from ignore.sh)
prompt_user() {
    local message="$1"
    echo -n "$message (y/N): "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}