cmd_remove() {
    local input="$1"
    
    if [[ -z "$input" ]]; then
        log_error "Usage: dotfiler remove <file_or_directory>"
        return 1
    fi
    
    # Ensure required environment variables are set
    if [[ -z "$DOTFILESPATH" ]]; then
        log_error "DOTFILESPATH environment variable is not set"
        return 1
    fi
    
    if [[ -z "$OS" ]]; then
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    
    # Resolve the path
    local target_path=""
    local tracked_path=""
    
    # Handle absolute paths first
    if [[ "$input" == /* ]]; then
        if [[ -L "$input" ]] || [[ -e "$input" ]]; then
            target_path="$input"
        else
            log_error "Cannot find $input"
            return 1
        fi
    # Then check current directory
    elif [[ -L "$input" ]] || [[ -e "$input" ]]; then
        target_path="$(pwd)/$input"
    # Then check in HOME
    elif [[ -L "$HOME/$input" ]] || [[ -e "$HOME/$input" ]]; then
        target_path="$HOME/$input"
    else
        log_error "Cannot find $input"
        return 1
    fi
    
    # Normalize the path (remove ./ and ../ etc) for non-symlinks
    if [[ -e "$target_path" ]] && [[ ! -L "$target_path" ]]; then
        target_path=$(realpath "$target_path")
    fi
    
    # Check if this file is tracked
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        log_error "No tracked files found"
        return 1
    fi
    
    # Find the tracked entry
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "${line// }" ]] && continue
        # Expand $HOME in the tracked path for comparison
        expanded_line="${line//\$HOME/$HOME}"
        if [[ "$expanded_line" == "$target_path" ]]; then
            tracked_path="$line"
            break
        fi
    done < "$TRACKED_ITEMS"
    
    if [[ -z "$tracked_path" ]]; then
        log_error "$input is not being tracked"
        return 1
    fi
    
    log_info "Found tracked item: $tracked_path"
    
    # Determine the dotfiles repository path
    local dotfiles_path=""
    if [[ "$target_path" == "$HOME"* ]]; then
        relative_path="${target_path#$HOME/}"
        dotfiles_path="$DOTFILESPATH/$OS/files/HOME/$relative_path"
    else
        relative_path="${target_path#/}"
        dotfiles_path="$DOTFILESPATH/$OS/files/$relative_path"
    fi
    
    # Check if the dotfiles copy exists
    if [[ ! -e "$dotfiles_path" ]]; then
        log_error "Dotfiles copy not found at: $dotfiles_path"
        return 1
    fi
    
    # Determine if we need sudo
    local needs_sudo=false
    if [[ "$target_path" != "$HOME"* ]] && [[ "$target_path" == "/"* ]]; then
        needs_sudo=true
    fi
    
    # Handle the removal
    if [[ -L "$target_path" ]]; then
        # It's a symlink - check if it points to our dotfiles
        local link_target=$(readlink "$target_path")
        if [[ "$link_target" == "$dotfiles_path" ]]; then
            log_info "Restoring original file from dotfiles repository"
            
            # Remove the symlink
            if [[ "$needs_sudo" == true ]]; then
                sudo rm "$target_path"
            else
                rm "$target_path"
            fi
            
            # Copy the file back from dotfiles repo
            if [[ "$needs_sudo" == true ]]; then
                sudo cp -r "$dotfiles_path" "$target_path"
                log_success "Restored file to original location (with sudo): $target_path"
            else
                cp -r "$dotfiles_path" "$target_path"
                log_success "Restored file to original location: $target_path"
            fi
        else
            log_warning "Symlink doesn't point to dotfiles repository. Removing from tracking only."
        fi
    elif [[ -e "$target_path" ]]; then
        log_warning "Target exists but is not a symlink. Removing from tracking only."
    else
        log_warning "Target doesn't exist. Removing from tracking only."
    fi
    
    # Remove from dotfiles repository
    if [[ -e "$dotfiles_path" ]]; then
        log_info "Removing from dotfiles repository: $dotfiles_path"
        rm -rf "$dotfiles_path"
        
        # Clean up empty parent directories
        local parent_dir="$(dirname "$dotfiles_path")"
        while [[ "$parent_dir" != "$DOTFILESPATH/$OS/files" ]] && [[ "$parent_dir" != "/" ]]; do
            if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir")" ]]; then
                rmdir "$parent_dir"
                log_info "Removed empty directory: $parent_dir"
                parent_dir="$(dirname "$parent_dir")"
            else
                break
            fi
        done
    fi
    
    # Remove from tracking - using a temporary file
    log_info "Removing from tracking list"
    local temp_file
    temp_file=$(mktemp)

    # Copy all lines except the one we want to remove into the temp file
    while IFS= read -r line; do
        if [[ "$line" != "$tracked_path" ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$TRACKED_ITEMS"

    # Overwrite the original list with the temp file's content using redirection.
    # This follows the symlink and preserves it.
    cat "$temp_file" > "$TRACKED_ITEMS"

    # Clean up the temporary file
    rm "$temp_file"

    log_success "Removed from tracking: $tracked_path"
    
    # If tracking file is now empty, remove it
    if [[ ! -s "$TRACKED_ITEMS" ]]; then
        rm "$TRACKED_ITEMS"
        log_info "No more tracked files, removed tracking list"
    fi
}