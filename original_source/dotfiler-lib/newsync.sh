# Sync new files only - don't touch existing ones
cmd_newsync() {
    local source_path="$1"
    
    # Determine destination path
    if [[ "$source_path" == "$HOME"* ]]; then
        relative_path="${source_path#$HOME/}"
        dest_base="$DOTFILESPATH/$OS/files/HOME/$relative_path"
    else
        relative_path="${source_path#/}"
        dest_base="$DOTFILESPATH/$OS/files/$relative_path"
    fi
    
    if [[ -d "$source_path" ]]; then
        # For directories, find new files/folders
        find "$source_path" -type f -o -type d -o -type l | while read -r item; do
            # Check if this item should be ignored
            if should_ignore "$item"; then
                continue
            fi
            # Calculate relative path from source
            # Ensure source_path ends with / for proper path prefix removal
            local source_with_slash="$source_path"
            [[ "$source_with_slash" != */ ]] && source_with_slash="$source_with_slash/"
            
            item_relative="${item#$source_with_slash}"
            
            # Enhanced validation to prevent directory loops
            if [[ "$item_relative" == "$item" ]]; then
                continue  # Skip if prefix removal failed (root dir or unrelated path)
            fi
            
            if [[ -z "$item_relative" ]]; then
                continue  # Skip empty relative paths
            fi
            
            if [[ "$item_relative" == *"$source_path"* ]]; then
                log_warning "Skipping potentially recursive path: $item"
                continue  # Skip paths that could create loops
            fi
            
            # Ensure proper path joining
            if [[ "$item_relative" == /* ]]; then
                dest_item="$dest_base$item_relative"
            else
                dest_item="$dest_base/$item_relative"
            fi
            
            if [[ ! -e "$dest_item" ]]; then
                if [[ -d "$item" ]]; then
                    echo "[INFO] Creating new directory: $dest_item"
                    mkdir -p "$dest_item"
                elif [[ -L "$item" ]]; then
                    # Check if symlink target exists
                    if [[ -e "$item" ]]; then
                        echo "[INFO] Adding new symlink (copying target): $dest_item"
                        mkdir -p "$(dirname "$dest_item")"
                        # Copy the content that the symlink points to, not the symlink itself
                        cp -L "$item" "$dest_item"
                    else
                        log_warning "Skipping broken symlink: $item -> $(readlink "$item" 2>/dev/null || echo "unknown")"
                        # Remove the broken symlink to clean up
                        log_info "Removing broken symlink: $item"
                        rm -f "$item"
                    fi
                else
                    echo "[INFO] Adding new file: $dest_item"
                    mkdir -p "$(dirname "$dest_item")"
                    cp "$item" "$dest_item"
                fi
            fi
        done
    else
        # For files, just check if destination exists and if it should be ignored
        if should_ignore "$source_path"; then
            return 0
        fi
        
        if [[ ! -e "$dest_base" ]]; then
            if [[ -L "$source_path" ]]; then
                # Handle symlinks (same logic as directory scan)
                if [[ -e "$source_path" ]]; then
                    echo "[INFO] Adding new symlink (copying target): $dest_base"
                    mkdir -p "$(dirname "$dest_base")"
                    cp -L "$source_path" "$dest_base"
                else
                    log_warning "Skipping broken symlink: $source_path -> $(readlink "$source_path" 2>/dev/null || echo "unknown")"
                    # Remove the broken symlink to clean up
                    log_info "Removing broken symlink: $source_path"
                    rm -f "$source_path"
                fi
            else
                echo "[INFO] Adding new file: $dest_base"
                mkdir -p "$(dirname "$dest_base")"
                cp "$source_path" "$dest_base"
            fi
        fi
    fi
}