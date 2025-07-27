cmd_build() {
    # First cleanup any ignored files that are currently managed
    cleanup_ignored_files
    
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