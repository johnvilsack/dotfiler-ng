#!/usr/bin/env bash
# sync.sh - Rsync-based sync engine
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
    
    log_info "Starting dotfiles sync..."
    
    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed"
        return 1
    fi
    
    # Phase 1: Tombstone lifecycle management
    log_info "Phase 1: Managing tombstone lifecycle"
    cleanup_tombstones
    
    # Phase 2: Symlink migration (if repo-first or detect symlinks)
    if [[ "$repo_first" == "true" ]] || has_symlinks; then
        log_info "Phase 2: Migrating symlinks to real files"
        migrate_symlinks_to_files
    fi
    
    # Phase 3: Automatic deletion detection (unless repo-first)
    if [[ "$repo_first" == "false" ]]; then
        log_info "Phase 3: Detecting deletions"
        auto_detect_deletions
        log_info "Phase 3: Deletion detection complete"
    else
        log_info "Phase 3: Skipping deletion detection (--repo-first mode)"
    fi
    
    # Phase 4: Filesystem → Repository sync (unless repo-first)
    if [[ "$repo_first" == "false" ]]; then
        log_info "Phase 4: Syncing filesystem → repository"
        sync_filesystem_to_repo_rsync
    else
        log_info "Phase 4: Skipping filesystem → repository (--repo-first mode)"
    fi
    
    # Phase 5: Repository → Filesystem sync
    log_info "Phase 5: Syncing repository → filesystem"
    sync_repo_to_filesystem_rsync "$repo_first"
    
    # Phase 6: Cross-machine deletion enforcement
    log_info "Phase 6: Enforcing cross-machine deletions"
    enforce_cross_machine_deletions
    
    # Phase 7: Auto-add new repo files
    if [[ "$(get_config AUTO_ADD_NEW)" == "true" ]]; then
        log_info "Phase 7: Auto-adding new repository files"
        auto_add_new_files_rsync
    fi
    
    log_success "Sync completed successfully"
    return 0
}

# Auto-detect deletions using rsync --delete --dry-run
auto_detect_deletions() {
    if [[ ! -f "$TRACKED_ITEMS" ]] || [[ ! -s "$TRACKED_ITEMS" ]]; then
        log_debug "No tracked items for deletion detection"
        return 0
    fi
    
    local deletion_count=0
    local temp_deletions="$(mktemp)"
    
    # Generate rsync filters for current tracked items
    local filter_file="$(generate_rsync_filters)"
    
    # For each tracked item, check for deletions
    local item_count=0
    local total_items="$(grep -c . "$TRACKED_ITEMS" 2>/dev/null || echo 0)"
    
    while IFS= read -r item; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        ((item_count++))
        log_debug "Checking deletions [$item_count/$total_items]: $item"
        
        local filesystem_path="$(get_filesystem_path "$item")"
        local repo_path="$REPO_FILES/$item"
        
        # Skip if not in repo (can't detect deletion)
        [[ ! -e "$repo_path" ]] && continue
        
        # Simple existence check - if filesystem path doesn't exist, it's deleted
        if ! path_exists "$filesystem_path"; then
            log_info "Auto-detected deletion: $item"
            echo "$item" >> "$temp_deletions"
            ((deletion_count++))
        fi
        
    done < "$TRACKED_ITEMS"
    
    # Process detected deletions
    if [[ $deletion_count -gt 0 ]]; then
        log_info "Processing $deletion_count auto-detected deletions"
        
        while IFS= read -r deleted_item; do
            # Add to tombstone with timestamp
            add_tombstone "$deleted_item"
            
            # Remove from tracking
            remove_from_tracking "$deleted_item"
            
            # Add to ignore list to prevent re-adding
            if [[ -f "$IGNORED_ITEMS" ]] && ! grep -q "^${deleted_item}$" "$IGNORED_ITEMS"; then
                echo "$deleted_item" >> "$IGNORED_ITEMS"
                sort -u "$IGNORED_ITEMS" -o "$IGNORED_ITEMS"
            fi
            
        done < "$temp_deletions"
        
        log_success "Auto-processed $deletion_count deletions"
    fi
    
    # Cleanup
    rm -f "$temp_deletions" "$filter_file"
}

# Generate rsync filter file from ignored.conf and .gitignore files
generate_rsync_filters() {
    local filter_file="$(mktemp)"
    
    # Add patterns from ignored.conf
    if [[ -f "$IGNORED_ITEMS" ]]; then
        while IFS= read -r pattern; do
            [[ -z "$pattern" || "$pattern" == \#* ]] && continue
            # Convert to rsync exclude format
            echo "- $pattern" >> "$filter_file"
        done < "$IGNORED_ITEMS"
    fi
    
    # Add .gitignore patterns from tracked directories
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r item; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            
            local filesystem_path="$(get_filesystem_path "$item")"
            
            # Check for .gitignore in tracked directory
            if [[ -d "$filesystem_path" ]] && [[ -f "$filesystem_path/.gitignore" ]]; then
                while IFS= read -r gitpattern; do
                    [[ -z "$gitpattern" || "$gitpattern" == \#* ]] && continue
                    echo "- $gitpattern" >> "$filter_file"
                done < "$filesystem_path/.gitignore"
            fi
            
            # Check parent directories for .gitignore
            local check_dir="$(dirname "$filesystem_path")"
            while [[ "$check_dir" != "/" && "$check_dir" != "$HOME" ]]; do
                if [[ -f "$check_dir/.gitignore" ]]; then
                    while IFS= read -r gitpattern; do
                        [[ -z "$gitpattern" || "$gitpattern" == \#* ]] && continue
                        echo "- $gitpattern" >> "$filter_file"
                    done < "$check_dir/.gitignore"
                fi
                check_dir="$(dirname "$check_dir")"
            done
        done < "$TRACKED_ITEMS"
    fi
    
    echo "$filter_file"
}

# Revolutionary filesystem → repository sync using pure rsync
sync_filesystem_to_repo_rsync() {
    if [[ ! -f "$TRACKED_ITEMS" ]] || [[ ! -s "$TRACKED_ITEMS" ]]; then
        log_info "No tracked items to sync"
        return 0
    fi
    
    log_info "Syncing filesystem to repository"
    
    local filter_file="$(generate_rsync_filters)"
    local synced_count=0
    
    # Sync each tracked item using rsync
    local sync_count=0
    local total_sync_items="$(grep -c . "$TRACKED_ITEMS" 2>/dev/null || echo 0)"
    
    while IFS= read -r item; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        ((sync_count++))
        log_debug "Syncing to repo [$sync_count/$total_sync_items]: $item"
        
        local filesystem_path="$(get_filesystem_path "$item")"
        local repo_path="$REPO_FILES/$item"
        
        # Skip if filesystem path doesn't exist
        if ! path_exists "$filesystem_path"; then
            log_debug "Skipping missing path: $item"
            continue
        fi
        
        # Create destination directory
        ensure_dir "$(dirname "$repo_path")"
        
        # Use rsync for intelligent sync
        local rsync_opts="-av --update --filter=merge $filter_file"
        
        if [[ -d "$filesystem_path" ]]; then
            # Directory sync with trailing slashes
            if rsync $rsync_opts "$filesystem_path/" "$repo_path/" 2>/dev/null; then
                log_debug "Synced directory: $item"
                ((synced_count++))
            else
                log_warning "Failed to sync directory: $item"
            fi
        else
            # File sync
            if rsync $rsync_opts "$filesystem_path" "$repo_path" 2>/dev/null; then
                log_debug "Synced file: $item"
                ((synced_count++))
            else
                log_warning "Failed to sync file: $item"
            fi
        fi
        
    done < "$TRACKED_ITEMS"
    
    if [[ $synced_count -gt 0 ]]; then
        log_success "Synced $synced_count items to repository"
    fi
    
    # Cleanup
    rm -f "$filter_file"
}

# Revolutionary repository → filesystem sync using pure rsync
sync_repo_to_filesystem_rsync() {
    local overwrite="${1:-false}"
    
    if [[ ! -d "$REPO_FILES" ]]; then
        log_warning "Repository files directory not found: $REPO_FILES"
        return 0
    fi
    
    log_info "Syncing repository to filesystem"
    
    local filter_file="$(generate_rsync_filters)"
    local rsync_opts="-av --filter=merge $filter_file"
    
    # Add overwrite behavior
    if [[ "$overwrite" == "true" ]]; then
        rsync_opts="$rsync_opts --force"
        log_info "Repository-first mode: overwriting filesystem files"
    else
        rsync_opts="$rsync_opts --update"
        log_info "Update mode: only newer files from repository"
    fi
    
    # Sync each tracked item
    local synced_count=0
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r item; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            
            local filesystem_path="$(get_filesystem_path "$item")"
            local repo_path="$REPO_FILES/$item"
            
            # Skip if not in repo
            [[ ! -e "$repo_path" ]] && continue
            
            # Check if tombstoned
            if is_tombstoned "$item"; then
                log_debug "Skipping tombstoned item: $item"
                continue
            fi
            
            # Create destination directory
            ensure_dir "$(dirname "$filesystem_path")"
            
            # Use rsync for sync
            if [[ -d "$repo_path" ]]; then
                # Directory sync
                if rsync $rsync_opts "$repo_path/" "$filesystem_path/" 2>/dev/null; then
                    log_debug "Synced directory from repo: $item"
                    ((synced_count++))
                fi
            else
                # File sync
                if rsync $rsync_opts "$repo_path" "$filesystem_path" 2>/dev/null; then
                    log_debug "Synced file from repo: $item"
                    ((synced_count++))
                fi
            fi
            
        done < "$TRACKED_ITEMS"
    fi
    
    if [[ $synced_count -gt 0 ]]; then
        log_success "Deployed $synced_count items to filesystem"
    fi
    
    # Cleanup
    rm -f "$filter_file"
}

# Detect existing symlinks that need migration
has_symlinks() {
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        return 1
    fi
    
    while IFS= read -r item; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local filesystem_path="$(get_filesystem_path "$item")"
        
        if [[ -L "$filesystem_path" ]]; then
            return 0  # Found at least one symlink
        fi
    done < "$TRACKED_ITEMS"
    
    return 1  # No symlinks found
}

# Migrate existing symlinks to real files
migrate_symlinks_to_files() {
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        return 0
    fi
    
    local migrated_count=0
    
    while IFS= read -r item; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local filesystem_path="$(get_filesystem_path "$item")"
        local repo_path="$REPO_FILES/$item"
        
        # Check if it's a symlink
        if [[ -L "$filesystem_path" ]]; then
            local symlink_target="$(readlink "$filesystem_path")"
            
            log_info "Migrating symlink to real file: $item"
            log_debug "Symlink: $filesystem_path → $symlink_target"
            
            # Remove symlink
            rm "$filesystem_path"
            
            # Copy from repository if exists, otherwise from original target
            if [[ -e "$repo_path" ]]; then
                cp -a "$repo_path" "$filesystem_path"
                log_debug "Copied from repository: $item"
            elif [[ -e "$symlink_target" ]]; then
                cp -a "$symlink_target" "$filesystem_path"
                log_debug "Copied from symlink target: $item"
            else
                log_warning "Could not migrate symlink (target missing): $item"
                continue
            fi
            
            ((migrated_count++))
        fi
        
    done < "$TRACKED_ITEMS"
    
    if [[ $migrated_count -gt 0 ]]; then
        log_success "Migrated $migrated_count symlinks to real files"
    fi
}

# Enforce deletions on cross-machine basis
enforce_cross_machine_deletions() {
    if [[ ! -f "$DELETED_ITEMS" ]]; then
        log_debug "No tombstone file for cross-machine deletions"
        return 0
    fi
    
    local current_time="$(date +%s)"
    local active_days="$(get_config DELETE_ACTIVE_DAYS 90)"
    local active_seconds=$((active_days * 24 * 3600))
    local enforced_count=0
    
    while IFS='|' read -r path timestamp; do
        [[ -z "$path" || "$path" == \#* ]] && continue
        
        # Handle entries without timestamp
        if [[ -z "$timestamp" ]]; then
            timestamp="$current_time"
        fi
        
        local age=$((current_time - timestamp))
        
        # Only enforce during active period
        if [[ $age -lt $active_seconds ]]; then
            local filesystem_path="$(get_filesystem_path "$path")"
            
            if path_exists "$filesystem_path"; then
                log_info "Enforcing cross-machine deletion: $path"
                rm -rf "$filesystem_path"
                ((enforced_count++))
            fi
        fi
        
    done < "$DELETED_ITEMS"
    
    if [[ $enforced_count -gt 0 ]]; then
        log_success "Enforced $enforced_count cross-machine deletions"
    fi
}

# Auto-add new files from repository using rsync discovery
auto_add_new_files_rsync() {
    if [[ ! -d "$REPO_FILES" ]]; then
        return 0
    fi
    
    local added_count=0
    local temp_new_files="$(mktemp)"
    
    # Use rsync to discover new files in repository
    rsync -av --dry-run --existing "$REPO_FILES/" /dev/null 2>/dev/null | \
        grep -E "^[^d]" | \
        awk '{print $NF}' > "$temp_new_files" || true
    
    # Process discovered files
    while IFS= read -r repo_relative_path; do
        [[ -z "$repo_relative_path" ]] && continue
        
        local filesystem_path="$(get_filesystem_path "$repo_relative_path")"
        
        # Check if already tracked
        if is_tracked "$filesystem_path"; then
            continue
        fi
        
        # Check if ignored
        if is_ignored "$filesystem_path"; then
            continue
        fi
        
        # Check if tombstoned
        if is_tombstoned "$repo_relative_path"; then
            continue
        fi
        
        # Decide whether to track file or parent directory
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
        
    done < "$temp_new_files"
    
    if [[ $added_count -gt 0 ]]; then
        # Sort and remove duplicates
        sort -u "$TRACKED_ITEMS" -o "$TRACKED_ITEMS"
        log_success "Auto-added $added_count new items from repository"
    fi
    
    # Cleanup
    rm -f "$temp_new_files"
}