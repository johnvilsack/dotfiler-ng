# DOTFILES ADDRER
# Dotfiles add function
# Dotfiles add function with smart path resolution
dadd() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: dadd <file_or_directory>"
        return 1
    fi
    
    local input="$1"
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
        echo "Error: Cannot find $input"
        return 1
    fi
    
    echo "Found: $source_path"
    
    # Determine destination based on whether it's in HOME or not
    if [[ "$source_path" == "$HOME"* ]]; then
        # It's in HOME, so copy to HOME directory with relative path
        if [[ "$source_path" == "$HOME" ]]; then
            echo "Error: Cannot add the entire HOME directory"
            return 1
        fi
        relative_path="${source_path#$HOME/}"
        dest_path="$DOTFILESPATH/mac/files/HOME/$relative_path"
    else
        # It's outside HOME, copy with full path structure (minus leading slash)
        relative_path="${source_path#/}"
        dest_path="$DOTFILESPATH/mac/files/$relative_path"
    fi
    
    # Create destination directory
    dest_dir="$(dirname "$dest_path")"
    mkdir -p "$dest_dir"
    
    # Remove destination if it already exists to avoid nested copying
    if [[ -e "$dest_path" ]]; then
        echo "Removing existing: $dest_path"
        rm -rf "$dest_path"
    fi
    
    # Copy the file or directory
    cp -r "$source_path" "$dest_path"
    
    if [[ -d "$source_path" ]]; then
        echo "Copied directory: $source_path -> $dest_path"
    else
        echo "Copied file: $source_path -> $dest_path"
    fi
}
#############