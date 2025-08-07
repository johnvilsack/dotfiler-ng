#!/usr/bin/env bash
# ignore.sh - Add patterns to ignore list
# Compatible with bash 3.2+ (macOS default)

cmd_ignore() {
    local pattern="${1:-}"
    
    if [[ -z "$pattern" ]]; then
        log_error "Usage: $PROGRAM_NAME ignore <pattern>"
        return 1
    fi
    
    # If pattern is a path, normalize it
    if [[ "$pattern" == /* ]] || [[ "$pattern" == ~* ]] || [[ "$pattern" == ./* ]]; then
        pattern="$(to_config_path "$(normalize_path "$pattern")")"
    fi
    
    # Check if already ignored
    if grep -q "^${pattern}$" "$IGNORED_ITEMS" 2>/dev/null; then
        log_warning "Already ignored: $pattern"
        return 0
    fi
    
    # Add to ignore list
    echo "$pattern" >> "$IGNORED_ITEMS"
    sort -u "$IGNORED_ITEMS" -o "$IGNORED_ITEMS"
    
    log_success "Added to ignore list: $pattern"
    return 0
}