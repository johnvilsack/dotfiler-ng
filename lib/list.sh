#!/usr/bin/env bash
# list.sh - List tracked items and show status
# Compatible with bash 3.2+ (macOS default)

cmd_list() {
    echo "Tracked Items:"
    echo "=============="
    
    if [[ ! -f "$TRACKED_ITEMS" ]] || [[ ! -s "$TRACKED_ITEMS" ]]; then
        echo "No items are currently being tracked."
        return 0
    fi
    
    local count=0
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local filesystem_path="$(get_filesystem_path "$item")"
        local repo_file_path="$REPO_FILES/$item"
        local status_icon=""
        local status_text=""
        
        # Check status
        if [[ -e "$filesystem_path" ]] && [[ -e "$repo_file_path" ]]; then
            status_icon="✓"
            status_text="synced"
        elif [[ -e "$filesystem_path" ]] && [[ ! -e "$repo_file_path" ]]; then
            status_icon="⚠"
            status_text="missing from repo"
        elif [[ ! -e "$filesystem_path" ]] && [[ -e "$repo_file_path" ]]; then
            status_icon="⚠"
            status_text="missing from filesystem"
        else
            status_icon="✗"
            status_text="missing both"
        fi
        
        echo -e "  ${status_icon} ${item} (${status_text})"
        ((count++))
    done < "$TRACKED_ITEMS"
    
    echo ""
    echo "Total: $count items"
}

cmd_status() {
    echo "Dotfiler-NG Status:"
    echo "==================="
    show_config
    echo ""
    
    # Show tracked items count
    local tracked_count=0
    if [[ -f "$TRACKED_ITEMS" ]]; then
        tracked_count=$(grep -v '^#' "$TRACKED_ITEMS" | grep -v '^$' | wc -l | tr -d ' ')
    fi
    
    echo "Statistics:"
    echo "  Tracked items: $tracked_count"
    
    # Show ignored patterns count
    local ignored_count=0
    if [[ -f "$IGNORED_ITEMS" ]]; then
        ignored_count=$(grep -v '^#' "$IGNORED_ITEMS" | grep -v '^$' | wc -l | tr -d ' ')
    fi
    echo "  Ignore patterns: $ignored_count"
    
    # Show deleted items count
    local deleted_count=0
    if [[ -f "$DELETED_ITEMS" ]]; then
        deleted_count=$(grep -v '^#' "$DELETED_ITEMS" | grep -v '^$' | wc -l | tr -d ' ')
    fi
    echo "  Tombstoned items: $deleted_count"
    
    # Check for sync issues
    echo ""
    echo "Sync Status:"
    check_sync_status
}

# Check sync status between repo and filesystem
check_sync_status() {
    local issues=0
    
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        echo "  No tracked items"
        return 0
    fi
    
    while IFS= read -r item || [[ -n "$item" ]]; do
        [[ -z "$item" || "$item" == \#* ]] && continue
        
        local filesystem_path="$(get_filesystem_path "$item")"
        local repo_file_path="$REPO_FILES/$item"
        
        # Check for issues
        if [[ ! -e "$filesystem_path" ]] && [[ -e "$repo_file_path" ]]; then
            if [[ $issues -eq 0 ]]; then
                echo "  Issues found:"
            fi
            echo "    - Missing from filesystem: $item"
            ((issues++))
        elif [[ -e "$filesystem_path" ]] && [[ ! -e "$repo_file_path" ]]; then
            if [[ $issues -eq 0 ]]; then
                echo "  Issues found:"
            fi
            echo "    - Missing from repository: $item"
            ((issues++))
        fi
    done < "$TRACKED_ITEMS"
    
    if [[ $issues -eq 0 ]]; then
        echo "  All tracked items are in sync"
    else
        echo ""
        echo "  Run 'dotfiler build' to resolve sync issues"
    fi
}