#!/usr/bin/env bash
# delete.sh - Delete and tombstone files
# Compatible with bash 3.2+ (macOS default)

cmd_delete() {
    local path="${1:-}"
    
    if [[ -z "$path" ]]; then
        log_error "Usage: $PROGRAM_NAME delete <path>"
        return 1
    fi
    
    # Normalize the path
    local fs_path="$(normalize_path "$path")"
    local config_path="$(to_config_path "$fs_path")"
    
    # Check if tracked
    if ! is_tracked "$fs_path"; then
        log_warning "Not tracked: $config_path"
        return 1
    fi
    
    # Add to deleted.conf with timestamp
    local timestamp="$(date +%s)"
    echo "$config_path|$timestamp" >> "$DELETED_ITEMS"
    log_info "Added to deletion list: $config_path"
    
    # Add to ignore list to prevent re-tracking
    echo "$config_path" >> "$IGNORED_ITEMS"
    log_info "Added to ignore list: $config_path"
    
    # Remove from filesystem
    if [[ -e "$fs_path" ]]; then
        rm -rf "$fs_path"
        log_success "Deleted from filesystem: $config_path"
    fi
    
    # Remove from repository
    local repo_subpath="$(to_repo_path "$config_path")"
    local repo_full_path="$REPO_FILES/$repo_subpath"
    if [[ -e "$repo_full_path" ]]; then
        rm -rf "$repo_full_path"
        log_success "Deleted from repository: $config_path"
    fi
    
    # Remove from tracking
    remove_from_tracking "$fs_path"
    
    return 0
}

# Remove command (backward compatibility and alternative)
cmd_remove() {
    local path="${1:-}"
    
    if [[ -z "$path" ]]; then
        log_error "Usage: $PROGRAM_NAME remove <path>"
        return 1
    fi
    
    # Normalize the path
    local fs_path="$(normalize_path "$path")"
    
    # Just remove from tracking without deletion
    if is_tracked "$fs_path"; then
        remove_from_tracking "$fs_path"
        log_success "Removed from tracking: $(to_config_path "$fs_path")"
    else
        log_warning "Not tracked: $(to_config_path "$fs_path")"
        return 1
    fi
    
    return 0
}