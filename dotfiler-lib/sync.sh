cmd_sync() {
    # Ensure config migration happens
    migrate_config_files
    
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        echo "[ERROR] No tracked files found. Use 'dadd' to start tracking files."
        return 1
    fi
    
    # First cleanup any ignored files that are currently managed
    cleanup_ignored_files
    
    echo "[INFO] Syncing tracked dotfiles (new items only)..."
    local synced_count=0
    
        while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # expand literal $HOME into this machine's real $HOME
        source_path="${line/#\$\HOME/$HOME}"

        # Check if this path should be ignored
        if should_ignore "$source_path"; then
            echo "[INFO] Ignoring: $source_path"
            continue
        fi

        # Check if source exists (or is a symlink, even if broken)
        if [[ ! -e "$source_path" ]] && [[ ! -L "$source_path" ]]; then
            echo "[WARNING] Source missing: $line"
            continue
        fi
        
        if [[ -d "$source_path" ]]; then
            echo "[INFO] Checking directory for new items: $source_path"
        else
            echo "[INFO] Checking file: $source_path"
        fi
        
        cmd_newsync "$source_path"
        synced_count=$((synced_count + 1))
    done < "$TRACKED_ITEMS"
    
    echo "[INFO] Processed $synced_count tracked items"
}