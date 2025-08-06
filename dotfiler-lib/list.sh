# Show what's being tracked
cmd_list() {
    # Ensure config migration happens
    migrate_config_files
    
    echo "[INFO] Listing tracked dotfiles..."

    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        echo "[ERROR] No tracked files found"
        return 1
    fi
    
    echo "[INFO] Tracked dotfiles:"
    while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # expand literal $HOME into this machine’s real $HOME
    source_path="${line/#\$\HOME/$HOME}"

    # Check if source exists (or is a symlink, even if broken)
    if [[ ! -e "$source_path" ]] && [[ ! -L "$source_path" ]]; then
        echo "[WARNING] Source missing: $line"
        continue
    fi
    
    # Handle broken symlinks
    if [[ -L "$source_path" ]] && [[ ! -e "$source_path" ]]; then
        echo "[WARNING] Broken symlink: $line -> $(readlink "$source_path" 2>/dev/null || echo "unknown")"
        continue
    fi
    
    echo "  - $line"
    done < "$TRACKED_ITEMS"
}