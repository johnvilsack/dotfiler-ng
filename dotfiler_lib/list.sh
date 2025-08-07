#!/usr/bin/env bash
# list.sh - List tracked items
# Compatible with bash 3.2+ (macOS default)

cmd_list() {
    if [[ ! -f "$TRACKED_ITEMS" ]] || [[ ! -s "$TRACKED_ITEMS" ]]; then
        log_info "No tracked items"
        return 0
    fi
    
    echo "Tracked items:"
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local fs_path="$(to_filesystem_path "$item")"
        if [[ -e "$fs_path" ]]; then
            if [[ -d "$fs_path" ]]; then
                echo "  [DIR]  $item"
            else
                echo "  [FILE] $item"
            fi
        else
            echo "  [MISS] $item"
        fi
    done < "$TRACKED_ITEMS"
}