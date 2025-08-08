#!/usr/bin/env bash
# common.sh - Core functions for dotfiler-ng
# Compatible with bash 3.2+ (macOS default)
# Simple, robust, minimal

# Get OS type
get_os() {
    case "$(uname -s)" in
        Darwin*) echo "mac" ;;
        Linux*)  echo "linux" ;;
        *)       echo "$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
    esac
}

# Normalize path (expand ~, resolve .., make absolute)
normalize_path() {
    local path="$1"
    
    # Replace ~ with $HOME for expansion
    if [[ "$path" == "~"* ]]; then
        path="${HOME}${path#\~}"
    fi
    
    # Expand environment variables (safely)
    if [[ "$path" == *'$'* ]]; then
        # Only use eval if path contains variables, and escape safely
        path="$(eval "echo \"$path\"")"
    fi
    
    # Make absolute if relative
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi
    
    # Use realpath if available, otherwise use pwd -P
    if command -v realpath >/dev/null 2>&1; then
        realpath "$path" 2>/dev/null || echo "$path"
    else
        echo "$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)/$(basename "$path")"
    fi
}

# Convert filesystem path to config format (with $HOME for HOME paths)
to_config_path() {
    local path="$1"
    local normalized="$(normalize_path "$path")"
    
    # If path starts with HOME, replace with $HOME
    if [[ "$normalized" == "$HOME"* ]]; then
        echo "\$HOME${normalized#$HOME}"
    else
        echo "$normalized"
    fi
}

# Convert config path to repo storage path
to_repo_path() {
    local path="$1"
    
    # Handle $HOME paths
    if [[ "$path" == "\$HOME"* ]]; then
        echo "HOME${path#\$HOME}"
    elif [[ "$path" == "~"* ]]; then
        # Legacy support for ~ paths
        echo "HOME${path#\~}"
    else
        # Absolute paths stored as-is (minus leading /)
        echo "${path#/}"
    fi
}

# Convert config path to filesystem path
to_filesystem_path() {
    local path="$1"
    
    # Replace $HOME with actual HOME
    if [[ "$path" == "\$HOME"* ]]; then
        echo "${HOME}${path#\$HOME}"
    elif [[ "$path" == "~"* ]]; then
        # Legacy support for ~ paths
        echo "${HOME}${path#\~}"
    else
        echo "$path"
    fi
}

# Logging functions
log_info() {
    echo "[INFO] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*" >&2
}

log_warning() {
    echo "[WARNING] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Check if path is ignored
is_ignored() {
    local path="$1"
    
    [[ ! -f "$IGNORED_ITEMS" ]] && return 1
    
    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
        [[ -z "$pattern" || "$pattern" == \#* ]] && continue
        
        # Convert pattern to filesystem path for comparison
        local fs_pattern="$(to_filesystem_path "$pattern")"
        
        # Check exact match or prefix match for directories
        if [[ "$path" == "$fs_pattern" ]] || [[ "$path" == "$fs_pattern"/* ]]; then
            return 0
        fi
        
        # Check glob patterns
        if [[ "$path" == $fs_pattern ]]; then
            return 0
        fi
    done < "$IGNORED_ITEMS"
    
    return 1
}

# Check if path is tracked
is_tracked() {
    local path="$1"
    local config_path="$(to_config_path "$path")"
    
    [[ ! -f "$TRACKED_ITEMS" ]] && return 1
    
    while IFS= read -r tracked || [[ -n "$tracked" ]]; do
        [[ -z "$tracked" || "$tracked" == \#* ]] && continue
        
        # Check exact match
        if [[ "$config_path" == "$tracked" ]]; then
            return 0
        fi
        
        # Check if path is under a tracked directory
        if [[ "$config_path" == "$tracked"/* ]]; then
            return 0
        fi
    done < "$TRACKED_ITEMS"
    
    return 1
}

# Add path to tracking
add_to_tracking() {
    local path="$1"
    local config_path="$(to_config_path "$path")"
    
    # Check if already tracked
    if is_tracked "$path"; then
        log_info "Already tracked: $config_path"
        return 0
    fi
    
    # Add to tracked.conf
    echo "$config_path" >> "$TRACKED_ITEMS"
    
    # Sort and dedupe
    sort -u "$TRACKED_ITEMS" -o "$TRACKED_ITEMS"
    
    log_success "Added to tracking: $config_path"
}

# Remove path from tracking
remove_from_tracking() {
    local path="$1"
    local config_path="$(to_config_path "$path")"
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        # Only log if item was actually in the file
        if grep -q "^${config_path}$" "$TRACKED_ITEMS"; then
            grep -v "^${config_path}$" "$TRACKED_ITEMS" > "$TRACKED_ITEMS.tmp" || true
            mv "$TRACKED_ITEMS.tmp" "$TRACKED_ITEMS"
            log_info "Removed from tracking: $config_path"
        fi
    fi
}