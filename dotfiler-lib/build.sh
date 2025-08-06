cmd_build() {
    local repo_first=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
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
    
    # Ensure config migration happens
    migrate_config_files
    
    # First cleanup any ignored files that are currently managed
    cleanup_ignored_files
    
    # Cleanup expired deletion tombstones and enforce deletions
    cleanup_deleted_items
    enforce_deletions
    
    # Auto-sync new files before building symlinks (unless --repo-first is specified)
    if [[ "$repo_first" == true ]]; then
        log_info "Repo-first mode: Skipping sync, building symlinks from repository only"
    elif [[ -f "$TRACKED_ITEMS" ]]; then
        log_info "Syncing new files before building symlinks..."
        
        # Call sync logic directly without the error check since we already know tracked files exist
        local synced_count=0
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # expand literal $HOME into this machine's real $HOME
            source_path="${line/#\$\HOME/$HOME}"

            # Check if this path should be ignored
            if should_ignore "$source_path"; then
                log_info "Ignoring: $source_path"
                continue
            fi

            # Check if source exists (or is a symlink, even if broken)
            if [[ ! -e "$source_path" ]] && [[ ! -L "$source_path" ]]; then
                log_warning "Source missing: $line"
                continue
            fi
            
            if [[ -d "$source_path" ]]; then
                log_info "Checking directory for new items: $source_path"
            else
                log_info "Checking file: $source_path"
            fi
            
            cmd_newsync "$source_path"
            synced_count=$((synced_count + 1))
        done < "$TRACKED_ITEMS"
        
        log_info "Processed $synced_count tracked items for sync"
    else
        log_info "No tracked files found, skipping sync"
    fi
    
    log_info "Linking config files with find"
    
    local dotfiles_base="$DOTFILESPATH/$OS/files"
    
    # Find all subdirectories in the files directory
    find "$dotfiles_base" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        # Get the directory name (e.g., "HOME", "Library")
        dir_name=$(basename "$dir")
        
        # Determine target base directory and if we need sudo
        local needs_sudo=false
        if [[ "$dir_name" == "HOME" ]]; then
            target_base="$HOME"
        else
            target_base="/$dir_name"
            needs_sudo=true
        fi
        
        # Find all files in this directory recursively
        find "$dir" -type f -not -name ".DS_Store" | while read -r file; do
            # Convert repo path back to original path for ignore checking
            local relative_from_dir="${file#$dir/}"
            local original_path
            if [[ "$dir_name" == "HOME" ]]; then
                original_path="$HOME/$relative_from_dir"
            else
                original_path="/$dir_name/$relative_from_dir"
            fi
            
            # Check if this file should be ignored
            if should_ignore "$original_path"; then
                log_info "Skipping ignored file: $original_path"
                continue
            fi
            # Get relative path from the current directory
            relative_path="${file#$dir/}"
            target="$target_base/$relative_path"
            
            # Create parent directory if it doesn't exist (with or without sudo)
            target_dir="$(dirname "$target")"
            if [[ ! -d "$target_dir" ]]; then
                if [[ "$needs_sudo" == true ]]; then
                    log_info "Creating directory: $target_dir with sudo"
                    sudo mkdir -p "$target_dir"
                else
                    log_info "Creating directory: $target_dir"
                    mkdir -p "$target_dir"
                fi
            fi
            
            # Check if we need to create/update the symlink
            if [[ -L "$target" ]]; then
                current_link=$(readlink "$target")
                if [[ "$current_link" == "$file" ]]; then
                    # Already linked to the correct file, skip
                    continue
                else
                    log_info "Updating: $target (was linked to $current_link)"
                    if [[ "$needs_sudo" == true ]]; then
                        log_info "Using sudo to update symlink: $target"
                        sudo ln -sf "$file" "$target"
                    else
                        ln -sf "$file" "$target"
                    fi
                fi
            elif [[ -e "$target" ]]; then
                log_warning "Overwriting: $target (was a regular file)"
                if [[ "$needs_sudo" == true ]]; then
                    log_info "Using sudo to overwrite file: $target"
                    sudo ln -sf "$file" "$target"
                else
                    ln -sf "$file" "$target"
                fi
            else
                log_info "Linking: $target"
                if [[ "$needs_sudo" == true ]]; then
                    log_info "Using sudo to create symlink: $target"
                    sudo ln -sf "$file" "$target"
                else
                    ln -sf "$file" "$target"
                fi
            fi
        done
    done
}