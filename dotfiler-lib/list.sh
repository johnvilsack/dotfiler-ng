# Show what's being tracked
cmd_list() {
    echo "[INFO] Listing tracked dotfiles..."

    if [[ ! -f "$TRACKEDFOLDERLIST" ]]; then
        echo "[ERROR] No tracked files found"
        return 1
    fi
    
    echo "[INFO] Tracked dotfiles:"
    while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # expand literal $HOME into this machine’s real $HOME
    source_path="${line/#\$\HOME/$HOME}"

    if [[ ! -e "$source_path" ]]; then
        echo "[WARNING] Source missing: $line"
        continue
    fi
    done < "$TRACKEDFOLDERLIST"
}