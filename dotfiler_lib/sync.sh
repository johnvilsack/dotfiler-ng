#!/usr/bin/env bash
# sync.sh - Simple rsync-based sync engine
# Compatible with bash 3.2+ (macOS default)

cmd_sync() {
    local repo_first=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo-first)
                repo_first=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    log_info "Starting sync..."
    
    # Validate configuration
    if ! validate_config; then
        return 1
    fi
    
    if [[ "$repo_first" == "true" ]]; then
        sync_repo_first
    else
        sync_normal
    fi
    
    log_success "Sync complete"
}

# Normal bidirectional sync
sync_normal() {
    # Step 1: Enforce deletions FIRST (before any syncing)
    log_info "Enforcing deletions..."
    enforce_deletions
    
    # Step 2: Detect deletions from filesystem
    log_info "Detecting filesystem deletions..."
    detect_deletions
    
    # Step 3: Detect deletions from repository (including files in directories)
    log_info "Detecting repository deletions..."
    detect_repo_deletions
    detect_repo_dir_deletions
    
    # Step 4: Discover new items in repository
    log_info "Discovering new repository items..."
    discover_repo_items
    
    # Step 5: Repository → Filesystem FIRST (to avoid re-syncing deleted files)
    log_info "Syncing repository to filesystem..."
    sync_repo_to_fs
    
    # Step 6: Filesystem → Repository
    log_info "Syncing filesystem to repository..."
    sync_fs_to_repo
    
    # Step 7: Cleanup old tombstones
    cleanup_tombstones
    
    # Step 8: Sync config files to repository
    sync_config_files
}

# Repo-first sync (for fresh installs)
sync_repo_first() {
    log_info "Repo-first sync - overwriting filesystem from repository..."
    
    # Replace any symlinks with real files
    replace_symlinks

    # Restore config from repository if it exists
    local config_repo_path="$REPO_FILES/HOME/.config/dotfiler"
    if [[ -d "$config_repo_path" ]]; then
        local config_fs_path="$HOME/.config/dotfiler"
        ensure_dir "$config_fs_path"
        
        # Backup current config
        if [[ -d "$config_fs_path.bak" ]]; then
            rm -rf "$config_fs_path.bak"
        fi
        cp -r "$config_fs_path" "$config_fs_path.bak" 2>/dev/null || true
        
        # Restore config from repository
        rsync -a "$config_repo_path/" "$config_fs_path/"
        log_info "Restored configuration from repository"
        
        # Reload config files
        source "$CONFIG_DIR/config" 2>/dev/null || true
        TRACKED_ITEMS="$CONFIG_DIR/tracked.conf"
        IGNORED_ITEMS="$CONFIG_DIR/ignored.conf"
        DELETED_ITEMS="$CONFIG_DIR/deleted.conf"
    fi

    # Copy everything from repo to filesystem (overwrite mode)
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r item || [[ -n "$item" ]]; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            
            local fs_path="$(to_filesystem_path "$item")"
            local repo_subpath="$(to_repo_path "$item")"
            local repo_full_path="$REPO_FILES/$repo_subpath"
            
            if [[ ! -e "$repo_full_path" ]]; then
                log_warning "Not in repository: $item"
                continue
            fi
            
            # Ensure parent directory exists
            ensure_dir "$(dirname "$fs_path")"
            
            # Copy from repo to filesystem (overwrite)
            if [[ -d "$repo_full_path" ]]; then
                rsync -a --delete "$repo_full_path/" "$fs_path/"
            else
                rsync -a "$repo_full_path" "$fs_path"
            fi
            
            log_success "Restored: $item"
        done < "$TRACKED_ITEMS"
    else
        log_warning "No tracked items found - use 'dotfiler track' to add items"
    fi
}

# Discover new items in repository that should be tracked
discover_repo_items() {
    # Conservative discovery - only discover items that are:
    # 1. Not already tracked
    # 2. Not in a tracked parent directory
    # 3. Not ignored or deleted
    
    # This function is intentionally minimal to avoid auto-tracking
    # large directory structures. Users should explicitly track items.
    
    # For now, disable auto-discovery until it can be made smarter
    # Auto-discovery was causing issues with tracking too many items
    log_debug "Repository discovery disabled - use 'dotfiler track' to add new items"
    return 0
}

# Sync filesystem to repository
sync_fs_to_repo() {
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local fs_path="$(to_filesystem_path "$item")"
        local repo_subpath="$(to_repo_path "$item")"
        local repo_full_path="$REPO_FILES/$repo_subpath"
        
        if [[ ! -e "$fs_path" ]]; then
            log_debug "Not on filesystem (will be handled by deletion detection): $item"
            continue
        fi
        
        # Ensure parent directory exists in repo
        ensure_dir "$(dirname "$repo_full_path")"
        
        # Build rsync exclude list from ignored.conf
        local excludes=""
        if [[ -f "$IGNORED_ITEMS" ]]; then
            while IFS= read -r pattern || [[ -n "$pattern" ]]; do
                [[ -z "$pattern" || "$pattern" == \#* ]] && continue
                # Check if it's a glob pattern or a specific path
                if [[ "$pattern" == *"*"* ]]; then
                    # It's a glob pattern, use as-is
                    excludes="$excludes --exclude='$pattern'"
                else
                    # It's a specific path, extract filename
                    local fs_pattern="$(to_filesystem_path "$pattern")"
                    local rel_pattern="${fs_pattern##*/}"
                    excludes="$excludes --exclude='$rel_pattern'"
                fi
            done < "$IGNORED_ITEMS"
        fi
        
        # Add .gitignore patterns if it exists
        if [[ -f "$fs_path/.gitignore" ]]; then
            excludes="$excludes --exclude-from='$fs_path/.gitignore'"
        fi
        
        # Sync to repo (only if newer or different)
        if [[ -d "$fs_path" ]]; then
            # Directory sync with update option
            log_debug "Syncing directory: $fs_path => $repo_full_path"
            log_debug "Expanded paths for rsync: $fs_path/ => $repo_full_path/"
            eval rsync -au --delete $excludes "$fs_path/" "$repo_full_path/"
        else
            # File sync with update option
            if [[ ! -f "$repo_full_path" ]] || [[ "$fs_path" -nt "$repo_full_path" ]]; then
                log_info "Syncing file: $fs_path => Repository"
                rsync -au "$fs_path" "$repo_full_path"
            fi
        fi
    done < "$TRACKED_ITEMS"
}

# Sync repository to filesystem
sync_repo_to_fs() {
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local fs_path="$(to_filesystem_path "$item")"
        local repo_subpath="$(to_repo_path "$item")"
        local repo_full_path="$REPO_FILES/$repo_subpath"
        
        if [[ ! -e "$repo_full_path" ]]; then
            log_debug "Not in repository (may have been deleted): $item"
            continue
        fi
        
        # Ensure parent directory exists
        ensure_dir "$(dirname "$fs_path")"
        
        # Sync with update option (only if newer)
        if [[ -d "$repo_full_path" ]]; then
            # Directory sync
            log_debug "Syncing directory: $repo_full_path => $fs_path"
            rsync -au "$repo_full_path/" "$fs_path/"
        else
            # File sync
            if [[ ! -f "$fs_path" ]] || [[ "$repo_full_path" -nt "$fs_path" ]]; then
                log_info "Syncing file: Repository => $fs_path"
                rsync -au "$repo_full_path" "$fs_path"
            fi
        fi
    done < "$TRACKED_ITEMS"
}

# Detect deletions from filesystem
detect_deletions() {
    local timestamp="$(date +%s)"
    
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local fs_path="$(to_filesystem_path "$item")"
        
        # If tracked item doesn't exist on filesystem, add to deleted.conf
        if [[ ! -e "$fs_path" ]]; then
            # Check if already in deleted.conf (escape $ in grep pattern)
            local escaped_item="$(echo "$item" | sed 's/\$/\\$/g')"
            if ! grep -q "^${escaped_item}|" "$DELETED_ITEMS" 2>/dev/null; then
                echo "$item|$timestamp" >> "$DELETED_ITEMS"
                log_info "Detected deletion: $item"
                
                # Add to ignore list to prevent re-tracking
                echo "$item" >> "$IGNORED_ITEMS"
                log_debug "Added to ignore list: $item"
                
                # Remove from repository
                local repo_subpath="$(to_repo_path "$item")"
                local repo_full_path="$REPO_FILES/$repo_subpath"
                if [[ -e "$repo_full_path" ]]; then
                    rm -rf "$repo_full_path"
                    log_debug "Removed from repo: $item"
                fi
                
                # Remove from tracking immediately to prevent re-sync
                remove_from_tracking "$fs_path"
            fi
        fi
    done < "$TRACKED_ITEMS"
}

# Detect deletions of files within tracked directories
detect_repo_dir_deletions() {
    local timestamp="$(date +%s)"
    
    # Only check tracked directories
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local fs_path="$(to_filesystem_path "$item")"
        local repo_subpath="$(to_repo_path "$item")"
        local repo_full_path="$REPO_FILES/$repo_subpath"
        
        # Only process if it's a directory
        if [[ -d "$fs_path" ]] && [[ -d "$repo_full_path" ]]; then
            # Use rsync dry-run to detect what would be copied FROM filesystem TO repo
            # These are files that exist in filesystem but not in repo (potential deletions)
            local would_sync=$(rsync -aun --delete "$fs_path/" "$repo_full_path/" 2>/dev/null | grep -v "^deleting " | grep -v "^$" | grep -v "/$")
            
            if [[ -n "$would_sync" ]]; then
                # Files exist in filesystem but not in repo - they were deleted from repo
                while IFS= read -r file; do
                    [[ -z "$file" ]] && continue
                    local full_fs_path="$fs_path/$file"
                    local full_config_path="$(to_config_path "$full_fs_path")"
                    
                    # Add to deleted.conf
                    local escaped_path="$(echo "$full_config_path" | sed 's/\$/\\$/g')"
                    if ! grep -q "^${escaped_path}|" "$DELETED_ITEMS" 2>/dev/null; then
                        echo "$full_config_path|$timestamp" >> "$DELETED_ITEMS"
                        log_info "Detected deletion in tracked directory: $full_config_path"
                        
                        # Add to ignore list
                        echo "$full_config_path" >> "$IGNORED_ITEMS"
                        
                        # Remove from filesystem
                        rm -rf "$full_fs_path"
                        log_info "Removed from filesystem: $full_config_path"
                    fi
                done <<< "$would_sync"
            fi
        fi
    done < "$TRACKED_ITEMS"
}

# Detect deletions from repository
detect_repo_deletions() {
    local timestamp="$(date +%s)"
    
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local repo_subpath="$(to_repo_path "$item")"
        local repo_full_path="$REPO_FILES/$repo_subpath"
        local fs_path="$(to_filesystem_path "$item")"
        
        # If tracked item doesn't exist in repository but exists on filesystem
        # This indicates the file was deleted from the repository (e.g., on another machine)
        if [[ ! -e "$repo_full_path" ]] && [[ -e "$fs_path" ]]; then
            # Check if already in deleted.conf (escape $ in grep pattern)
            local escaped_item="$(echo "$item" | sed 's/\$/\\$/g')"
            if ! grep -q "^${escaped_item}|" "$DELETED_ITEMS" 2>/dev/null; then
                echo "$item|$timestamp" >> "$DELETED_ITEMS"
                log_info "Detected repository deletion: $item"
                
                # Add to ignore list to prevent re-tracking
                echo "$item" >> "$IGNORED_ITEMS"
                log_debug "Added to ignore list: $item"
                
                # Remove from filesystem to sync with repository state
                rm -rf "$fs_path"
                log_info "Removed from filesystem to match repository: $item"
                
                # Remove from tracking immediately
                remove_from_tracking "$fs_path"
            fi
        fi
    done < "$TRACKED_ITEMS"
}

# Enforce deletions from deleted.conf
enforce_deletions() {
    local current_time="$(date +%s)"
    local ninety_days=$((90 * 24 * 60 * 60))
    
    [[ ! -f "$DELETED_ITEMS" ]] && return 0
    
    while IFS='|' read -r item timestamp || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        # Parse timestamp (handle missing timestamps gracefully)
        if [[ -z "$timestamp" ]]; then
            timestamp="$current_time"
        fi
        
        local age=$((current_time - timestamp))
        
        # Enforce deletion if within 90 days
        if [[ $age -lt $ninety_days ]]; then
            local fs_path="$(to_filesystem_path "$item")"
            local repo_subpath="$(to_repo_path "$item")"
            local repo_full_path="$REPO_FILES/$repo_subpath"
            
            # Remove from filesystem if it exists
            if [[ -e "$fs_path" ]]; then
                rm -rf "$fs_path"
                log_info "Enforced deletion: $item"
            fi
            
            # Remove from repository if it exists
            if [[ -e "$repo_full_path" ]]; then
                rm -rf "$repo_full_path"
                log_debug "Removed from repo: $item"
            fi
            
            # Remove from tracking if still present
            if is_tracked "$fs_path"; then
                remove_from_tracking "$fs_path"
            fi
        fi
    done < "$DELETED_ITEMS"
}

# Cleanup old tombstones
cleanup_tombstones() {
    local current_time="$(date +%s)"
    local one_twenty_days=$((120 * 24 * 60 * 60))
    local temp_file="$DELETED_ITEMS.tmp"
    
    [[ ! -f "$DELETED_ITEMS" ]] && return 0
    
    > "$temp_file"
    
    while IFS='|' read -r item timestamp || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        # Parse timestamp (handle missing timestamps gracefully)
        if [[ -z "$timestamp" ]]; then
            timestamp="$current_time"
        fi
        
        local age=$((current_time - timestamp))
        
        # Keep tombstones less than 120 days old
        if [[ $age -lt $one_twenty_days ]]; then
            echo "$item|$timestamp" >> "$temp_file"
        else
            log_debug "Removed old tombstone: $item"
            # Remove from tracking when tombstone expires
            local fs_path="$(to_filesystem_path "$item")"
            remove_from_tracking "$fs_path"
            # Also remove from ignore list when tombstone expires
            if [[ -f "$IGNORED_ITEMS" ]]; then
                local escaped_item="$(echo "$item" | sed 's/[\$\/]/\\&/g')"
                sed -i.bak "/^${escaped_item}$/d" "$IGNORED_ITEMS"
                rm -f "${IGNORED_ITEMS}.bak"
                log_debug "Removed from ignore list: $item"
            fi
        fi
    done < "$DELETED_ITEMS"
    
    mv "$temp_file" "$DELETED_ITEMS"
}

# Replace symlinks with real files
replace_symlinks() {
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local fs_path="$(to_filesystem_path "$item")"
        
        # Check if it's a symlink
        if [[ -L "$fs_path" ]]; then
            local target="$(readlink "$fs_path")"
            log_info "Replacing symlink with real file: $item"
            
            # Remove symlink
            rm "$fs_path"
            
            # Copy target to location
            if [[ -e "$target" ]]; then
                if [[ -d "$target" ]]; then
                    cp -R "$target" "$fs_path"
                else
                    cp "$target" "$fs_path"
                fi
                log_success "Replaced symlink: $item"
            else
                log_warning "Symlink target not found: $target"
            fi
        fi
    done < "$TRACKED_ITEMS"
}

# Sync config files to repository
sync_config_files() {
    local config_repo_dir="$REPO_FILES/HOME/.config/dotfiler"
    
    # Ensure repo config directory exists
    ensure_dir "$config_repo_dir"
    
    # Sync config files to repository
    if [[ -f "$CONFIG_FILE" ]]; then
        rsync -a "$CONFIG_FILE" "$config_repo_dir/"
        log_debug "Synced config to repository"
    fi
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        rsync -a "$TRACKED_ITEMS" "$config_repo_dir/"
        log_debug "Synced tracked.conf to repository"
    fi
    
    if [[ -f "$IGNORED_ITEMS" ]]; then
        rsync -a "$IGNORED_ITEMS" "$config_repo_dir/"
        log_debug "Synced ignored.conf to repository"
    fi
    
    if [[ -f "$DELETED_ITEMS" ]]; then
        rsync -a "$DELETED_ITEMS" "$config_repo_dir/"
        log_debug "Synced deleted.conf to repository"
    fi
}

# Backward compatibility
cmd_build() {
    cmd_sync "$@"
}
