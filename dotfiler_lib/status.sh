#!/usr/bin/env bash
# status.sh - Show configuration and sync status
# Compatible with bash 3.2+ (macOS default)

cmd_status() {
    echo "Dotfiler Status"
    echo "==============="
    echo ""
    echo "Configuration:"
    echo "  Config dir:  $CONFIG_DIR"
    echo "  Repo path:   $REPO_PATH"
    echo "  Repo files:  $REPO_FILES"
    echo "  OS:          $OS"
    echo ""
    
    # Count tracked items
    local tracked_count=0
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r item || [[ -n "$item" ]]; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            tracked_count=$((tracked_count + 1))
        done < "$TRACKED_ITEMS"
    fi
    
    # Count ignored patterns
    local ignored_count=0
    if [[ -f "$IGNORED_ITEMS" ]]; then
        while IFS= read -r item || [[ -n "$item" ]]; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            ignored_count=$((ignored_count + 1))
        done < "$IGNORED_ITEMS"
    fi
    
    # Count deletions
    local deletion_count=0
    if [[ -f "$DELETED_ITEMS" ]]; then
        while IFS= read -r item || [[ -n "$item" ]]; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            deletion_count=$((deletion_count + 1))
        done < "$DELETED_ITEMS"
    fi
    
    echo "Statistics:"
    echo "  Tracked items:    $tracked_count"
    echo "  Ignored patterns: $ignored_count"
    echo "  Pending deletions: $deletion_count"
    echo ""
    
    # Check sync status
    echo "Sync Status:"
    local out_of_sync=0
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r item || [[ -n "$item" ]]; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            
            local fs_path="$(to_filesystem_path "$item")"
            local repo_subpath="$(to_repo_path "$item")"
            local repo_full_path="$REPO_FILES/$repo_subpath"
            
            if [[ ! -e "$fs_path" ]]; then
                echo "  [MISSING] $item (not on filesystem)"
                out_of_sync=$((out_of_sync + 1))
            elif [[ ! -e "$repo_full_path" ]]; then
                echo "  [NOT SYNCED] $item (not in repository)"
                out_of_sync=$((out_of_sync + 1))
            elif [[ "$fs_path" -nt "$repo_full_path" ]]; then
                echo "  [MODIFIED] $item (filesystem newer)"
                out_of_sync=$((out_of_sync + 1))
            elif [[ "$repo_full_path" -nt "$fs_path" ]]; then
                echo "  [OUTDATED] $item (repository newer)"
                out_of_sync=$((out_of_sync + 1))
            fi
        done < "$TRACKED_ITEMS"
    fi
    
    if [[ $out_of_sync -eq 0 ]]; then
        echo "  All tracked items are in sync"
    else
        echo ""
        echo "  $out_of_sync item(s) need syncing - run 'dotfiler sync'"
    fi
}