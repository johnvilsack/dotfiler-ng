#!/usr/bin/env bash
# build.sh - Main sync operations using rsync
# Compatible with bash 3.2+ (macOS default)

cmd_build() {
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
    
    log_info "Starting dotfiler build..."
    
    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed"
        return 1
    fi
    
    # Phase 1: Cleanup and maintenance
    log_info "Phase 1: Cleanup and maintenance"
    cleanup_tombstones
    
    # Phase 2: Detect deletions (unless repo-first mode)
    if [[ "$repo_first" == "false" ]]; then
        log_info "Phase 2: Detecting deletions"
        detect_deletions
    fi
    
    # Phase 3: Sync filesystem to repo (unless repo-first mode)
    if [[ "$repo_first" == "false" ]]; then
        log_info "Phase 3: Syncing filesystem → repository"
        sync_filesystem_to_repo
    else
        log_info "Phase 3: Skipping filesystem → repository sync (--repo-first mode)"
    fi
    
    # Phase 4: Sync repo to filesystem
    log_info "Phase 4: Syncing repository → filesystem"
    sync_repo_to_filesystem "$repo_first"
    
    # Phase 5: Auto-add new repo files
    if [[ "$(get_config AUTO_ADD_NEW)" == "true" ]]; then
        log_info "Phase 5: Auto-adding new repository files"
        auto_add_new_files
    fi
    
    log_success "Build completed successfully"
    return 0
}

# Sync filesystem to repository (new files only)
sync_filesystem_to_repo() {
    if [[ ! -f "$TRACKED_ITEMS" ]] || [[ ! -s "$TRACKED_ITEMS" ]]; then
        log_info "No tracked items to sync"
        return 0
    fi
    
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local filesystem_path="$(get_filesystem_path "$item")"
        local repo_path="$REPO_FILES/$item"
        
        # Skip if filesystem path doesn't exist
        if ! path_exists "$filesystem_path"; then
            log_debug "Skipping missing path: $item"
            continue
        fi
        
        # Create destination directory
        ensure_dir "$(dirname "$repo_path")"
        
        # Sync using rsync
        sync_path_to_repo "$filesystem_path" "$repo_path" "$item"
        
    done < "$TRACKED_ITEMS"
}

# Sync repository to filesystem
sync_repo_to_filesystem() {
    local overwrite="${1:-false}"
    
    if [[ ! -d "$REPO_FILES" ]]; then
        log_warning "Repository files directory not found: $REPO_FILES"
        return 0
    fi
    
    # Find all files in repo and sync them to filesystem
    find "$REPO_FILES" -type f | while read -r repo_file; do
        # Get relative path from repo base
        local relative_path="${repo_file#$REPO_FILES/}"
        local filesystem_path="$(get_filesystem_path "$relative_path")"
        
        # Check if file is ignored
        if is_ignored "$filesystem_path"; then
            log_debug "Skipping ignored file: $relative_path"
            continue
        fi
        
        # Check if file is tombstoned
        if is_tombstoned "$relative_path"; then
            log_debug "Skipping tombstoned file: $relative_path"
            continue
        fi
        
        # Create destination directory
        ensure_dir "$(dirname "$filesystem_path")"
        
        # Handle overwrite logic
        if [[ -e "$filesystem_path" ]] && [[ "$overwrite" == "false" ]]; then
            # Check if repo file is newer or different
            if ! files_are_same "$repo_file" "$filesystem_path"; then
                log_info "Updating: $relative_path"
                cp -a "$repo_file" "$filesystem_path"
            fi
        else
            # Overwrite or create new file
            if [[ "$overwrite" == "true" ]] || [[ ! -e "$filesystem_path" ]]; then
                log_info "Installing: $relative_path"
                cp -a "$repo_file" "$filesystem_path"
            fi
        fi
    done
}

# Sync a single path to repository using rsync
sync_path_to_repo() {
    local source="$1"
    local dest="$2" 
    local item="$3"
    
    # Prepare rsync options
    local rsync_opts="-av --update"
    
    # Create temporary exclude file for this sync
    local temp_exclude="$(mktemp)"
    
    # Add ignore patterns to exclude file
    if [[ -f "$IGNORED_ITEMS" ]]; then
        cat "$IGNORED_ITEMS" > "$temp_exclude"
    fi
    
    # Add .gitignore patterns from source directory
    if [[ -d "$source" ]] && [[ -f "$source/.gitignore" ]]; then
        cat "$source/.gitignore" >> "$temp_exclude"
    fi
    
    # Add .gitignore patterns from parent directories
    local check_dir="$(dirname "$source")"
    while [[ "$check_dir" != "/" && "$check_dir" != "$HOME" ]]; do
        if [[ -f "$check_dir/.gitignore" ]]; then
            # Add patterns with appropriate path prefixes
            while IFS= read -r pattern || [[ -n "$pattern" ]]; do
                [[ -z "$pattern" || "$pattern" == \#* ]] && continue
                echo "$pattern" >> "$temp_exclude"
            done < "$check_dir/.gitignore"
        fi
        check_dir="$(dirname "$check_dir")"
    done
    
    # Use exclude file if it has content
    if [[ -s "$temp_exclude" ]]; then
        rsync_opts="$rsync_opts --exclude-from=$temp_exclude"
    fi
    
    # Perform sync
    if [[ -d "$source" ]]; then
        # Directory sync - ensure trailing slashes
        rsync $rsync_opts "$source/" "$dest/" 2>/dev/null || {
            log_warning "Failed to sync directory: $item"
        }
    else
        # File sync
        rsync $rsync_opts "$source" "$dest" 2>/dev/null || {
            log_warning "Failed to sync file: $item"
        }
    fi
    
    # Cleanup
    rm -f "$temp_exclude"
    
    log_debug "Synced to repo: $item"
}

# Auto-add new files from repository
auto_add_new_files() {
    if [[ ! -d "$REPO_FILES" ]]; then
        return 0
    fi
    
    local added_count=0
    
    # Find files in repo that aren't tracked
    find "$REPO_FILES" -type f | while read -r repo_file; do
        local relative_path="${repo_file#$REPO_FILES/}"
        local filesystem_path="$(get_filesystem_path "$relative_path")"
        
        # Check if already tracked
        if is_tracked "$filesystem_path"; then
            continue
        fi
        
        # Check if ignored
        if is_ignored "$filesystem_path"; then
            continue
        fi
        
        # Check if tombstoned
        if is_tombstoned "$relative_path"; then
            continue
        fi
        
        # Decide whether to track file or its parent directory
        local dir_path="$(dirname "$filesystem_path")"
        
        if [[ ! -d "$dir_path" ]]; then
            # Directory doesn't exist, track the directory
            local repo_dir_path="$(get_repo_path "$dir_path")"
            echo "$repo_dir_path" >> "$TRACKED_ITEMS"
            log_info "Auto-added directory: $repo_dir_path"
        else
            # Directory exists, track the specific file
            local repo_file_path="$(get_repo_path "$filesystem_path")"
            echo "$repo_file_path" >> "$TRACKED_ITEMS"
            log_info "Auto-added file: $repo_file_path"
        fi
        
        ((added_count++))
    done
    
    if [[ $added_count -gt 0 ]]; then
        # Sort and remove duplicates
        sort -u "$TRACKED_ITEMS" -o "$TRACKED_ITEMS"
        log_success "Auto-added $added_count new items from repository"
    fi
}

# Detect deletions using rsync dry-run
detect_deletions() {
    if [[ ! -f "$TRACKED_ITEMS" ]] || [[ ! -s "$TRACKED_ITEMS" ]]; then
        return 0
    fi
    
    log_info "Detecting deletions..."
    local deletion_count=0
    
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local filesystem_path="$(get_filesystem_path "$item")"
        local repo_path="$REPO_FILES/$item"
        
        # Check if file exists in filesystem but not in repo location
        if ! path_exists "$filesystem_path" && [[ -e "$repo_path" ]]; then
            # File was deleted from filesystem
            log_info "Detected deletion: $item"
            add_tombstone "$item"
            ((deletion_count++))
        fi
    done < "$TRACKED_ITEMS"
    
    if [[ $deletion_count -gt 0 ]]; then
        log_info "Detected $deletion_count deletions"
    fi
}

# Check if two files are the same
files_are_same() {
    local file1="$1"
    local file2="$2"
    
    # Use diff to compare files (returns 0 if same)
    diff -q "$file1" "$file2" >/dev/null 2>&1
}

# Cleanup tombstones (placeholder for delete.sh integration)
cleanup_tombstones() {
    log_debug "Tombstone cleanup (to be implemented)"
}

# Add tombstone (placeholder for delete.sh integration) 
add_tombstone() {
    local item="$1"
    log_debug "Adding tombstone: $item (to be implemented)"
}

# Check if item is tombstoned (placeholder for delete.sh integration)
is_tombstoned() {
    local item="$1"
    return 1  # Not tombstoned by default
}