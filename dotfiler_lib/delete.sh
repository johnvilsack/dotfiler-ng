#!/usr/bin/env bash
# delete.sh - Deletion management and tombstone system
# Compatible with bash 3.2+ (macOS default)

cmd_delete() {
    local path="${1:-}"
    
    # Validate arguments
    if [[ -z "$path" ]]; then
        log_error "Usage: $PROGRAM_NAME delete <path>"
        log_info "Note: Automatic deletion detection is now available!"
        log_info "Simply delete files in filesystem - next sync will detect and manage them"
        return 1
    fi
    
    # Normalize path
    local full_path="$(normalize_path "$path")"
    local repo_path="$(get_repo_path "$full_path")"
    
    # Inform about new workflow
    log_info "Auto-detection available: You can also just delete files normally"
    log_info "Next 'dotfiler sync' will auto-detect and manage the deletion"
    echo ""
    
    # Confirm deletion
    log_warning "Manual deletion - this will delete '$repo_path' from:"
    echo "  - Filesystem: $full_path"
    echo "  - Repository: $REPO_FILES/$repo_path"
    echo "  - Cross-machine enforcement for $(get_config DELETE_ACTIVE_DAYS 90) days"
    
    if ! confirm "Proceed with manual deletion?"; then
        return 1
    fi
    
    # Use the same process as auto-detection for consistency
    manual_deletion_process "$repo_path" "$full_path"
    
    return 0
}

# Process deletion (used by both manual delete and auto-detection)
manual_deletion_process() {
    local repo_path="$1"
    local full_path="$2"
    
    # Step 1: Add tombstone
    add_tombstone "$repo_path"
    
    # Step 2: Remove from tracking
    remove_from_tracking "$repo_path"
    
    # Step 3: Add to ignore list (prevent re-adding)
    if [[ -f "$IGNORED_ITEMS" ]] && ! grep -q "^${repo_path}$" "$IGNORED_ITEMS"; then
        echo "$repo_path" >> "$IGNORED_ITEMS"
        sort -u "$IGNORED_ITEMS" -o "$IGNORED_ITEMS"
        log_info "Added to ignore list: $repo_path"
    fi
    
    # Step 4: Remove from repository
    local repo_file_path="$REPO_FILES/$repo_path"
    if [[ -e "$repo_file_path" ]]; then
        rm -rf "$repo_file_path"
        log_info "Removed from repository: $repo_path"
        
        # Remove empty parent directories
        remove_empty_dirs "$(dirname "$repo_file_path")" "$REPO_FILES"
    fi
    
    # Step 5: Delete from filesystem
    if path_exists "$full_path"; then
        rm -rf "$full_path"
        log_success "Deleted from filesystem: $full_path"
    fi
    
    log_success "Successfully processed deletion: $repo_path"
    log_info "Tombstone will enforce deletion across machines for $(get_config DELETE_ACTIVE_DAYS 90) days"
}

# Remove item from tracking (shared function)
remove_from_tracking() {
    local item="$1"
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        grep -v "^${item}$" "$TRACKED_ITEMS" > "$TRACKED_ITEMS.tmp" || true
        mv "$TRACKED_ITEMS.tmp" "$TRACKED_ITEMS"
        log_info "Removed from tracking: $item"
    fi
}

# Add tombstone entry
add_tombstone() {
    local path="$1"
    local timestamp="$(date +%s)"
    
    # Check if already tombstoned
    if is_tombstoned "$path"; then
        log_debug "Already tombstoned: $path"
        return 0
    fi
    
    # Add tombstone entry
    echo "${path}|${timestamp}" >> "$DELETED_ITEMS"
    log_info "Added tombstone: $path"
}

# Check if item is tombstoned
is_tombstoned() {
    local path="$1"
    
    if [[ ! -f "$DELETED_ITEMS" ]]; then
        return 1
    fi
    
    grep -q "^${path}|" "$DELETED_ITEMS" 2>/dev/null
}

# Get tombstone timestamp
get_tombstone_timestamp() {
    local path="$1"
    
    if [[ ! -f "$DELETED_ITEMS" ]]; then
        return 1
    fi
    
    local entry="$(grep "^${path}|" "$DELETED_ITEMS" 2>/dev/null)"
    if [[ -n "$entry" ]]; then
        echo "${entry#*|}"
        return 0
    fi
    
    return 1
}

# Cleanup old tombstones and enforce deletions
cleanup_tombstones() {
    if [[ ! -f "$DELETED_ITEMS" ]]; then
        log_debug "No tombstone file found"
        return 0
    fi
    
    local current_time="$(date +%s)"
    local active_days="$(get_config DELETE_ACTIVE_DAYS 90)"
    local passive_days="$(get_config DELETE_PASSIVE_DAYS 120)"
    local active_seconds=$((active_days * 24 * 3600))
    local passive_seconds=$((passive_days * 24 * 3600))
    
    local temp_file="$(mktemp)"
    local enforced_count=0
    local cleaned_count=0
    
    while IFS='|' read -r path timestamp; do
        [[ -z "$path" || "$path" == \#* ]] && continue
        
        # Handle entries without timestamp (legacy)
        if [[ -z "$timestamp" ]]; then
            timestamp="$current_time"
            log_info "Added timestamp to legacy tombstone: $path"
        fi
        
        local age=$((current_time - timestamp))
        
        if [[ $age -lt $active_seconds ]]; then
            # Active enforcement period
            echo "${path}|${timestamp}" >> "$temp_file"
            enforce_deletion "$path"
            enforced_count=$((enforced_count + 1))
            
        elif [[ $age -lt $passive_seconds ]]; then
            # Passive protection period
            echo "${path}|${timestamp}" >> "$temp_file"
            log_debug "Passive protection for: $path"
            
        else
            # Check if file still exists before cleanup
            local filesystem_path="$(get_filesystem_path "$path")"
            local repo_file_path="$REPO_FILES/$path"
            
            if [[ -e "$filesystem_path" ]] || [[ -e "$repo_file_path" ]]; then
                # File reappeared - keep tombstone indefinitely (automated file)
                echo "${path}|${timestamp}" >> "$temp_file"
                log_info "File reappeared, maintaining tombstone: $path"
            else
                # Safe to remove tombstone
                log_debug "Cleaned up old tombstone: $path"
                cleaned_count=$((cleaned_count + 1))
            fi
        fi
    done < "$DELETED_ITEMS"
    
    # Replace tombstone file
    mv "$temp_file" "$DELETED_ITEMS"
    
    if [[ $enforced_count -gt 0 ]]; then
        log_info "Enforced $enforced_count active deletions"
    fi
    
    if [[ $cleaned_count -gt 0 ]]; then
        log_info "Cleaned up $cleaned_count old tombstones"
    fi
}

# Enforce deletion on current system
enforce_deletion() {
    local path="$1"
    local filesystem_path="$(get_filesystem_path "$path")"
    local repo_file_path="$REPO_FILES/$path"
    
    # Delete from filesystem if exists
    if path_exists "$filesystem_path"; then
        log_info "Enforcing deletion from filesystem: $path"
        rm -rf "$filesystem_path"
    fi
    
    # Delete from repository if exists
    if [[ -e "$repo_file_path" ]]; then
        log_info "Enforcing deletion from repository: $path"
        rm -rf "$repo_file_path"
        remove_empty_dirs "$(dirname "$repo_file_path")" "$REPO_FILES"
    fi
    
    # Remove from tracking if still there
    if [[ -f "$TRACKED_ITEMS" ]] && grep -q "^${path}$" "$TRACKED_ITEMS"; then
        grep -v "^${path}$" "$TRACKED_ITEMS" > "$TRACKED_ITEMS.tmp" || true
        mv "$TRACKED_ITEMS.tmp" "$TRACKED_ITEMS"
        log_info "Removed from tracking during enforcement: $path"
    fi
}

# Remove empty directories up to a base directory
remove_empty_dirs() {
    local dir="$1"
    local base="$2"
    
    while [[ "$dir" != "$base" ]] && [[ "$dir" != "/" ]]; do
        if [[ -d "$dir" ]] && rmdir "$dir" 2>/dev/null; then
            log_debug "Removed empty directory: ${dir#$base/}"
            dir="$(dirname "$dir")"
        else
            break
        fi
    done
}

# Show tombstone status
show_tombstones() {
    echo "Tombstoned Items:"
    echo "================="
    
    if [[ ! -f "$DELETED_ITEMS" ]] || [[ ! -s "$DELETED_ITEMS" ]]; then
        echo "No tombstoned items."
        return 0
    fi
    
    local current_time="$(date +%s)"
    local active_days="$(get_config DELETE_ACTIVE_DAYS 90)"
    local passive_days="$(get_config DELETE_PASSIVE_DAYS 120)"
    local active_seconds=$((active_days * 24 * 3600))
    local passive_seconds=$((passive_days * 24 * 3600))
    
    while IFS='|' read -r path timestamp; do
        [[ -z "$path" || "$path" == \#* ]] && continue
        
        # Handle entries without timestamp
        if [[ -z "$timestamp" ]]; then
            echo "  ⚠ $path (no timestamp - will be updated)"
            continue
        fi
        
        local age=$((current_time - timestamp))
        local days=$((age / 86400))
        
        if [[ $age -lt $active_seconds ]]; then
            echo "  🗑 $path (active enforcement - ${days} days)"
        elif [[ $age -lt $passive_seconds ]]; then
            echo "  🛡 $path (passive protection - ${days} days)"
        else
            echo "  🧹 $path (cleanup candidate - ${days} days)"
        fi
    done < "$DELETED_ITEMS"
}