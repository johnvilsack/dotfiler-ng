#!/usr/bin/env bash
# ignore.sh - Add patterns to ignore list
# Compatible with bash 3.2+ (macOS default)

cmd_ignore() {
    local pattern="${1:-}"
    
    # Validate arguments
    if [[ -z "$pattern" ]]; then
        log_error "Usage: $PROGRAM_NAME ignore <pattern>"
        return 1
    fi
    
    # If pattern is a path, normalize it
    if [[ "$pattern" == /* ]] || [[ "$pattern" == ~* ]] || [[ "$pattern" == \$* ]]; then
        pattern="$(get_repo_path "$(normalize_path "$pattern")")"
    fi
    
    # Check if pattern already in ignore list
    if [[ -f "$IGNORED_ITEMS" ]] && grep -q "^${pattern}$" "$IGNORED_ITEMS"; then
        log_warning "Pattern already ignored: $pattern"
        return 0
    fi
    
    # Check if pattern would affect tracked items
    local affected_items=()
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r tracked || [[ -n "$tracked" ]]; do
            [[ -z "$tracked" || "$tracked" == \#* ]] && continue
            
            # Check if tracked item matches pattern
            if [[ "$tracked" == $pattern ]] || [[ "$tracked" == $pattern/* ]]; then
                affected_items+=("$tracked")
            fi
        done < "$TRACKED_ITEMS"
    fi
    
    # Warn user about affected items
    if [[ ${#affected_items[@]} -gt 0 ]]; then
        log_warning "Ignoring '$pattern' would affect these tracked items:"
        for item in "${affected_items[@]}"; do
            echo "  - $item"
        done
        
        if ! confirm "Continue with ignoring '$pattern'?"; then
            return 1
        fi
        
        # Remove affected items from tracking
        for item in "${affected_items[@]}"; do
            remove_from_tracking "$item"
        done
    fi
    
    # Add pattern to ignore list
    echo "$pattern" >> "$IGNORED_ITEMS"
    
    # Sort ignore list
    sort -u "$IGNORED_ITEMS" -o "$IGNORED_ITEMS"
    
    log_success "Added to ignore list: $pattern"
    
    # Clean up any files matching the pattern from repo
    cleanup_ignored_pattern "$pattern"
    
    return 0
}

# Remove item from tracking
remove_from_tracking() {
    local item="$1"
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        grep -v "^${item}$" "$TRACKED_ITEMS" > "$TRACKED_ITEMS.tmp" || true
        mv "$TRACKED_ITEMS.tmp" "$TRACKED_ITEMS"
        log_info "Removed from tracking: $item"
    fi
}

# Clean up ignored pattern from repository
cleanup_ignored_pattern() {
    local pattern="$1"
    
    # Find and remove files matching pattern from repo
    local repo_base="$REPO_FILES"
    
    # Handle different pattern types
    if [[ "$pattern" == *"*"* ]] || [[ "$pattern" == *"?"* ]]; then
        # Wildcard pattern - use find with pattern matching
        log_info "Cleaning up wildcard pattern from repo: $pattern"
        
        # Convert shell pattern to find pattern
        find "$repo_base" -name "$pattern" -type f 2>/dev/null | while read -r file; do
            log_debug "Removing ignored file: ${file#$repo_base/}"
            rm -f "$file"
        done
        
        # Remove empty directories
        find "$repo_base" -type d -empty -delete 2>/dev/null || true
        
    else
        # Exact path - remove if exists
        local full_pattern_path="$repo_base/$pattern"
        if [[ -e "$full_pattern_path" ]]; then
            log_info "Removing ignored item from repo: $pattern"
            rm -rf "$full_pattern_path"
            
            # Remove empty parent directories
            local parent="$(dirname "$full_pattern_path")"
            while [[ "$parent" != "$repo_base" ]] && [[ -d "$parent" ]]; do
                if rmdir "$parent" 2>/dev/null; then
                    log_debug "Removed empty directory: ${parent#$repo_base/}"
                    parent="$(dirname "$parent")"
                else
                    break
                fi
            done
        fi
    fi
}