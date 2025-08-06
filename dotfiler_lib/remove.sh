#!/usr/bin/env bash
# remove.sh - Remove files or directories from tracking
# Compatible with bash 3.2+ (macOS default)

cmd_remove() {
    local path="${1:-}"
    
    # Validate arguments
    if [[ -z "$path" ]]; then
        log_error "Usage: $PROGRAM_NAME remove <path>"
        return 1
    fi
    
    # Normalize path
    local full_path="$(normalize_path "$path")"
    local repo_path="$(get_repo_path "$full_path")"
    
    # Check if item is tracked
    if ! is_tracked "$full_path"; then
        log_error "Not tracking: $repo_path"
        return 1
    fi
    
    # Warn user about removal
    log_warning "This will stop managing '$repo_path'"
    
    if ! confirm "Continue with removing '$repo_path' from tracking?"; then
        return 1
    fi
    
    # Remove from tracked items
    if [[ -f "$TRACKED_ITEMS" ]]; then
        grep -v "^${repo_path}$" "$TRACKED_ITEMS" > "$TRACKED_ITEMS.tmp" || true
        mv "$TRACKED_ITEMS.tmp" "$TRACKED_ITEMS"
    fi
    
    log_success "Removed from tracking: $repo_path"
    
    # Ask if user wants to delete from repository
    if confirm "Delete '$repo_path' from repository?"; then
        local repo_file_path="$REPO_FILES/$repo_path"
        if [[ -e "$repo_file_path" ]]; then
            rm -rf "$repo_file_path"
            log_success "Deleted from repository: $repo_path"
            
            # Remove empty parent directories
            local parent="$(dirname "$repo_file_path")"
            while [[ "$parent" != "$REPO_FILES" ]] && [[ -d "$parent" ]]; do
                if rmdir "$parent" 2>/dev/null; then
                    log_debug "Removed empty directory: ${parent#$REPO_FILES/}"
                    parent="$(dirname "$parent")"
                else
                    break
                fi
            done
        fi
    fi
    
    return 0
}

# List items that would be affected by removing a path
list_affected_items() {
    local path="$1"
    local repo_path="$(get_repo_path "$path")"
    local affected=()
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r tracked || [[ -n "$tracked" ]]; do
            [[ -z "$tracked" || "$tracked" == \#* ]] && continue
            
            # Check if tracked item is under the path being removed
            if [[ "$tracked" == "$repo_path"* ]]; then
                affected+=("$tracked")
            fi
        done < "$TRACKED_ITEMS"
    fi
    
    printf '%s\n' "${affected[@]}"
}