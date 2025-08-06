# Recursively copy directory while respecting ignore patterns
copy_with_ignore() {
    local source_dir="$1"
    local dest_dir="$2"
    
    # Create the destination directory
    mkdir -p "$dest_dir"
    
    # Find all files and directories in source
    find "$source_dir" -type f -o -type d | while read -r item; do
        # Skip the root directory itself
        [[ "$item" == "$source_dir" ]] && continue
        
        # Check if this item should be ignored
        if should_ignore "$item"; then
            log_info "Skipping ignored: $item"
            continue
        fi
        
        # Calculate relative path from source
        local source_with_slash="$source_dir"
        [[ "$source_with_slash" != */ ]] && source_with_slash="$source_with_slash/"
        
        local item_relative="${item#$source_with_slash}"
        local dest_item="$dest_dir/$item_relative"
        
        if [[ -d "$item" ]]; then
            # Create directory
            mkdir -p "$dest_item"
        else
            # Create parent directory and copy file
            mkdir -p "$(dirname "$dest_item")"
            cp "$item" "$dest_item"
        fi
    done
}

cmd_add() {
    local track=true
    local input=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-track)
                track=false
                shift
                ;;
            *)
                input="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$input" ]]; then
        echo "Usage: dotfiler add [--no-track] <file_or_directory>"
        return 1
    fi
    
    local source_path=""
    
    # Try to resolve the path in order of preference
    if [[ -e "$input" ]]; then
        # File/directory exists relative to current directory
        source_path=$(realpath "$input")
    elif [[ -e "$HOME/$input" ]]; then
        # Check if it exists in HOME
        source_path=$(realpath "$HOME/$input")
    elif command -v "$input" >/dev/null 2>&1; then
        # It's a command, find its path
        source_path=$(which "$input")
    else
        echo "[ERROR] Cannot find $input"
        return 1
    fi
    
    echo "[INFO] Found: $source_path"
    
    # Validate the path for security
    if ! validate_path "$source_path" "source path"; then
        return 1
    fi
    
    # Check for conflicts with ignore patterns
    if find_conflicting_ignore_patterns "$source_path"; then
        echo ""
        if ! prompt_user "Remove conflicting ignore patterns and continue?"; then
            log_info "Add operation cancelled"
            return 0
        fi
    fi
    
    # Remove any matching ignore patterns to prevent conflicts
    remove_from_ignore_list "$source_path"
    
    # Check if source is already a symlink and handle appropriately
    if [[ -L "$source_path" ]]; then
        local link_target=$(readlink "$source_path")
        
        # Convert source path to tracking format to determine expected repo path
        local expected_tracked_path
        if [[ "$source_path" == "$HOME"* ]]; then
            expected_tracked_path='$HOME'"${source_path#$HOME}"
        else
            expected_tracked_path="$source_path"
        fi
        
        # Determine what our repo path would be
        local expected_repo_path
        if [[ "$expected_tracked_path" == '$HOME'* ]]; then
            local rel_path="${expected_tracked_path#\$HOME/}"
            expected_repo_path="$DOTFILESPATH/$OS/files/HOME/$rel_path"
        else
            local rel_path="${expected_tracked_path#/}"
            expected_repo_path="$DOTFILESPATH/$OS/files/$rel_path"
        fi
        
        # Check if it's already symlinked to our repo
        if [[ "$link_target" == "$expected_repo_path" ]]; then
            # Already managed by us - just add to tracking if not already there
            log_info "File already managed by dotfiler, adding to tracking: $source_path"
        else
            # Symlinked to something else - error out
            log_error "Cannot add symlink that points to external location: $source_path -> $link_target"
            log_error "Please resolve the symlink first or use a different file"
            return 1
        fi
    fi
    
    # Determine destination based on whether it's in HOME or not
    if [[ "$source_path" == "$HOME"* ]]; then
        # It's in HOME, so copy to HOME directory with relative path
        if [[ "$source_path" == "$HOME" ]]; then
            echo "[ERROR] Cannot add the entire HOME directory"
            return 1
        fi
        relative_path="${source_path#$HOME/}"
        dest_path="$DOTFILESPATH/$OS/files/HOME/$relative_path"
    else
        # It's outside HOME, copy with full path structure (minus leading slash)
        relative_path="${source_path#/}"
        dest_path="$DOTFILESPATH/$OS/files/$relative_path"
    fi
    
    # Create destination directory
    dest_dir="$(dirname "$dest_path")"
    mkdir -p "$dest_dir"
    
    # Copy the file or directory (respecting ignore patterns)
    # Skip copying if it's already our symlink
    if [[ -L "$source_path" ]]; then
        local link_target=$(readlink "$source_path")
        if [[ "$link_target" == "$dest_path" ]]; then
            log_info "File already in repository, skipping copy: $source_path"
        else
            log_error "Unexpected symlink state during copy phase"
            return 1
        fi
    elif [[ -d "$source_path" ]]; then
        # For directories, do selective copying
        copy_with_ignore "$source_path" "$dest_path"
    else
        # For files, check if it should be ignored
        if should_ignore "$source_path"; then
            log_warning "Skipping ignored file: $source_path"
            return 0
        fi
        cp "$source_path" "$dest_path"
    fi
    
    if [[ -d "$source_path" ]]; then
        echo "[INFO] Copied directory: $source_path -> $dest_path"
    else
        echo "[INFO] Copied file: $source_path -> $dest_path"
    fi
    
    # Add to tracking unless --no-track was specified
    if [[ "$track" == true ]]; then
        mkdir -p "$(dirname "$TRACKED_ITEMS")"
        
        # Write path with $HOME variable if applicable
        local tracked_path="$source_path"
        if [[ "$source_path" == "$HOME"* ]]; then
            tracked_path='$HOME'"${source_path#$HOME}"
        fi
        
        # Append the new path to the list
        echo "$tracked_path" >> "$TRACKED_ITEMS"
        
        # Now, sort the file while preserving the symlink
        local temp_file
        temp_file=$(mktemp)
        # Sort the list and write to a temporary file
        sort -u "$TRACKED_ITEMS" > "$temp_file"
        # Overwrite the original file by redirecting content, which follows the symlink
        cat "$temp_file" > "$TRACKED_ITEMS"
        # Remove the temporary file
        rm "$temp_file"
        
        echo "[INFO] Added to tracking: $tracked_path"
    fi
}