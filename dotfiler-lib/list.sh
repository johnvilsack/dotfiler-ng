# Show what's being tracked
cmd_list() {
    echo "[INFO] Listing tracked dotfiles..."

    if [[ ! -f "$TRACKEDFOLDERLIST" ]]; then
        echo "[ERROR] No tracked files found"
        return 1
    fi
    
    echo "[INFO] Tracked dotfiles:"
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        if [[ -e "$file_path" ]]; then
            echo "[INFO] $file_path"
        else
            echo "[WARNING] $file_path (missing)"
        fi
    done < "$TRACKEDFOLDERLIST"
}