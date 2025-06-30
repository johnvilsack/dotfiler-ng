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
        find "$source_path" -type f -o -type d | while read -r item; do
            # Calculate relative path from source
            item_relative="${item#$source_path}"
            [[ "$item_relative" == "$item" ]] && continue  # Skip if same (root dir)
            
            dest_item="$dest_base$item_relative"
            
            if [[ ! -e "$dest_item" ]]; then
                if [[ -d "$item" ]]; then
                    echo "[INFO] Creating new directory: $dest_item"
                    mkdir -p "$dest_item"
                else
                    echo "[INFO] Adding new file: $dest_item"
                    mkdir -p "$(dirname "$dest_item")"
                    cp "$item" "$dest_item"
                fi
            fi
        done
    else
        # For files, just check if destination exists
        if [[ ! -e "$dest_base" ]]; then
            echo "[INFO] Adding new file: $dest_base"
            mkdir -p "$(dirname "$dest_base")"
            cp "$source_path" "$dest_base"
        fi
    fi
}