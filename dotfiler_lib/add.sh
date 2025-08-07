#!/usr/bin/env bash
# add.sh - Add files or directories to tracking
# Compatible with bash 3.2+ (macOS default)

cmd_add() {
    local path="${1:-}"
    
    # Validate arguments
    if [[ -z "$path" ]]; then
        log_error "Usage: $PROGRAM_NAME add <path>"
        return 1
    fi
    
    # Normalize and expand path
    local full_path="$(normalize_path "$path")"
    local repo_path="$(get_repo_path "$full_path")"
    
    # Check if path exists
    if ! path_exists "$full_path"; then
        log_error "Path does not exist: $full_path"
        return 1
    fi
    
    # Check if already tracked
    if is_tracked "$full_path"; then
        log_warning "Already tracking: $repo_path"
        return 0
    fi
    
    # Check if path is ignored
    if is_ignored "$full_path"; then
        log_warning "Path is in ignore list: $full_path"
        if ! confirm "Do you want to track it anyway?"; then
            return 1
        fi
        # Remove from ignore list if user confirms
        remove_from_ignore "$repo_path"
    fi
    
    # Check if parent directory is already tracked
    local parent_tracked=""
    local check_path="$(dirname "$full_path")"
    while [[ "$check_path" != "/" && "$check_path" != "." ]]; do
        if is_tracked "$check_path"; then
            parent_tracked="$check_path"
            break
        fi
        check_path="$(dirname "$check_path")"
    done
    
    if [[ -n "$parent_tracked" ]]; then
        log_info "Parent directory already tracked: $(get_repo_path "$parent_tracked")"
        log_info "File will be included automatically"
        return 0
    fi
    
    # Add to tracked items
    echo "$repo_path" >> "$TRACKED_ITEMS"
    
    # Sort and remove duplicates
    sort -u "$TRACKED_ITEMS" -o "$TRACKED_ITEMS"
    
    log_success "Added to tracking: $repo_path"
    
    # Initial sync to repo
    if [[ -d "$full_path" ]]; then
        sync_directory_to_repo "$full_path"
    else
        sync_file_to_repo "$full_path"
    fi
    
    return 0
}

# Sync a single file to repository
sync_file_to_repo() {
    local source="$1"
    local repo_path="$(get_repo_path "$source")"
    local repo_file_path="$(get_repo_file_path "$repo_path")"
    local dest_path="$REPO_FILES/$repo_file_path"
    local dest_dir="$(dirname "$dest_path")"
    
    # Create destination directory
    ensure_dir "$dest_dir"
    
    # Copy file to repo
    if [[ -f "$source" ]]; then
        cp -a "$source" "$dest_path"
        log_success "Synced file to repo: $repo_path"
    fi
}

# Sync a directory to repository
sync_directory_to_repo() {
    local source="$1"
    local repo_path="$(get_repo_path "$source")"
    local repo_file_path="$(get_repo_file_path "$repo_path")"
    local dest_path="$REPO_FILES/$repo_file_path"
    
    # Create destination directory
    ensure_dir "$dest_path"
    
    # Use rsync to sync directory contents
    # -a: archive mode (preserves attributes)
    # -v: verbose
    # --exclude-from: use ignore patterns
    local rsync_opts="-av"
    
    # Add exclude options
    if [[ -f "$IGNORED_ITEMS" ]]; then
        rsync_opts="$rsync_opts --exclude-from=$IGNORED_ITEMS"
    fi
    
    # Check for .gitignore in source directory
    if [[ -f "$source/.gitignore" ]]; then
        rsync_opts="$rsync_opts --exclude-from=$source/.gitignore"
    fi
    
    # Sync directory
    log_info "Syncing directory to repo: $repo_path"
    rsync $rsync_opts "$source/" "$dest_path/" 2>/dev/null || true
    
    log_success "Synced directory to repo: $repo_path"
}

# Remove from ignore list
remove_from_ignore() {
    local pattern="$1"
    
    if [[ -f "$IGNORED_ITEMS" ]]; then
        # Create temp file without the pattern
        grep -v "^${pattern}$" "$IGNORED_ITEMS" > "$IGNORED_ITEMS.tmp" || true
        mv "$IGNORED_ITEMS.tmp" "$IGNORED_ITEMS"
        log_info "Removed from ignore list: $pattern"
    fi
}