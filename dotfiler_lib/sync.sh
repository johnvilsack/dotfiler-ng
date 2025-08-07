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
    # Step 1: Detect deletions
    log_info "Detecting deletions..."
    detect_deletions
    
    # Step 2: Discover new items in repository
    log_info "Discovering new repository items..."
    discover_repo_items
    
    # Step 3: Filesystem → Repository
    log_info "Syncing filesystem to repository..."
    sync_fs_to_repo
    
    # Step 4: Repository → Filesystem
    log_info "Syncing repository to filesystem..."
    sync_repo_to_fs
    
    # Step 5: Enforce deletions
    log_info "Enforcing deletions..."
    enforce_deletions
    
    # Step 6: Cleanup old tombstones
    cleanup_tombstones
}

# Repo-first sync (for fresh installs)
sync_repo_first() {
    log_info "Repo-first sync - overwriting filesystem from repository..."
    
    # Replace any symlinks with real files
    replace_symlinks
    
    # Copy everything from repo to filesystem (overwrite mode)
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
                # Convert config path to simple pattern for rsync
                local simple_pattern="${pattern##*/}"
                excludes="$excludes --exclude='$simple_pattern'"
            done < "$IGNORED_ITEMS"
        fi
        
        # Add .gitignore patterns if it exists
        if [[ -f "$fs_path/.gitignore" ]]; then
            excludes="$excludes --exclude-from='$fs_path/.gitignore'"
        fi
        
        # Sync to repo
        if [[ -d "$fs_path" ]]; then
            eval rsync -a --delete $excludes "$fs_path/" "$repo_full_path/"
        else
            rsync -a "$fs_path" "$repo_full_path"
        fi
        
        log_debug "Synced to repo: $item"
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
        
        # Only sync if repo version is newer or filesystem doesn't exist
        if [[ ! -e "$fs_path" ]] || [[ "$repo_full_path" -nt "$fs_path" ]]; then
            if [[ -d "$repo_full_path" ]]; then
                # For directories, use rsync with update flag
                rsync -au "$repo_full_path/" "$fs_path/"
            else
                rsync -au "$repo_full_path" "$fs_path"
            fi
            log_debug "Updated from repo: $item"
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
            # Check if already in deleted.conf
            if ! grep -q "^$item|" "$DELETED_ITEMS" 2>/dev/null; then
                echo "$item|$timestamp" >> "$DELETED_ITEMS"
                log_info "Detected deletion: $item"
                
                # Remove from repository
                local repo_subpath="$(to_repo_path "$item")"
                local repo_full_path="$REPO_FILES/$repo_subpath"
                if [[ -e "$repo_full_path" ]]; then
                    rm -rf "$repo_full_path"
                    log_debug "Removed from repo: $item"
                fi
                
                # Remove from tracking (only when first detected)
                remove_from_tracking "$fs_path"
            fi
        fi
    done < "$TRACKED_ITEMS"
}

# Enforce deletions from deleted.conf
enforce_deletions() {
    local current_time="$(date +%s)"
    local ninety_days=$((90 * 24 * 60 * 60))
    
    while IFS='|' read -r item timestamp || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
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
        fi
    done < "$DELETED_ITEMS"
}

# Cleanup old tombstones
cleanup_tombstones() {
    local current_time="$(date +%s)"
    local one_twenty_days=$((120 * 24 * 60 * 60))
    local temp_file="$DELETED_ITEMS.tmp"
    
    > "$temp_file"
    
    while IFS='|' read -r item timestamp || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local age=$((current_time - timestamp))
        
        # Keep tombstones less than 120 days old
        if [[ $age -lt $one_twenty_days ]]; then
            echo "$item|$timestamp" >> "$temp_file"
        else
            log_debug "Removed old tombstone: $item"
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

# Backward compatibility
cmd_build() {
    cmd_sync "$@"
}