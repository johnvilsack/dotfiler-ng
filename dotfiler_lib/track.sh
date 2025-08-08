#!/usr/bin/env bash
# track.sh - Add files/directories to tracking
# Compatible with bash 3.2+ (macOS default)

cmd_track() {
    local path="${1:-}"
    
    if [[ -z "$path" ]]; then
        log_error "Usage: $PROGRAM_NAME track <path>"
        return 1
    fi
    
    # Normalize the path
    local fs_path="$(normalize_path "$path")"
    
    # Check if path exists
    if [[ ! -e "$fs_path" ]]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    # Check if already tracked
    if is_tracked "$fs_path"; then
        log_info "Already tracked: $(to_config_path "$fs_path")"
        return 0
    fi
    
    # Check if ignored
    if is_ignored "$fs_path"; then
        log_warning "Path is in ignore list: $(to_config_path "$fs_path")"
        return 1
    fi
    
    # Add to tracking
    add_to_tracking "$fs_path"
    
    # Sync the newly tracked item to repo
    sync_single_item "$fs_path"
    
    return 0
}

# Sync a single tracked item to repository
sync_single_item() {
    local fs_path="$1"
    local config_path="$(to_config_path "$fs_path")"
    local repo_subpath="$(to_repo_path "$config_path")"
    local repo_full_path="$REPO_FILES/$repo_subpath"
    
    log_info "Syncing to repository: $config_path"
    
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
            fi
        done < "$IGNORED_ITEMS"
    fi
    
    # Use rsync to copy item to repo
    if [[ -d "$fs_path" ]]; then
        # Directory - sync contents with excludes
        eval rsync -a --delete $excludes "$fs_path/" "$repo_full_path/"
    else
        # File - copy directly
        rsync -a "$fs_path" "$repo_full_path"
    fi
    
    log_success "Synced to repository: $config_path"
}

# Backward compatibility
cmd_add() {
    cmd_track "$@"
}