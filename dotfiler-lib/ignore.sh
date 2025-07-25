#!/usr/bin/env bash

# Initialize ignore list file if it doesn't exist
IGNORELIST="$HOME/.config/dotfiler/ignore-list.txt"

# Ensure config directory exists
mkdir -p "$(dirname "$IGNORELIST")"

cmd_ignore() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: dotfiler ignore <file_or_directory>"
        exit 1
    fi
    
    # Convert to absolute path
    if [[ "$target" == "~"* ]]; then
        target="${target/#\~/$HOME}"
    elif [[ "$target" != "/"* ]]; then
        target="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
    fi
    
    # Convert absolute path to pattern relative to HOME for consistency
    if [[ "$target" == "$HOME"* ]]; then
        pattern="${target#$HOME/}"
    else
        pattern="$target"
    fi
    
    # Check if already in ignore list
    if [[ -f "$IGNORELIST" ]] && grep -Fxq "$pattern" "$IGNORELIST"; then
        log_warning "Pattern '$pattern' is already in ignore list"
        return 0
    fi
    
    # Add to ignore list
    echo "$pattern" >> "$IGNORELIST"
    log_success "Added '$pattern' to ignore list"
}

# Helper function to check if a path should be ignored
should_ignore() {
    local path="$1"
    
    # Return false (don't ignore) if ignore list doesn't exist
    [[ ! -f "$IGNORELIST" ]] && return 1
    
    # Convert path to relative format for matching
    local check_path
    if [[ "$path" == "$HOME"* ]]; then
        check_path="${path#$HOME/}"
    else
        check_path="$path"
    fi
    
    # Check against each pattern in ignore list
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        
        # Simple glob matching - bash's case statement supports basic patterns
        case "$check_path" in
            $pattern)
                return 0  # Should ignore
                ;;
        esac
        
        # Also check the full path for absolute patterns
        case "$path" in
            $pattern)
                return 0  # Should ignore
                ;;
        esac
        
    done < "$IGNORELIST"
    
    return 1  # Don't ignore
}