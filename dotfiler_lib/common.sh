#!/usr/bin/env bash
# common.sh - Common utilities and functions
# Compatible with bash 3.2+ (macOS default)

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $*" >&2
    fi
}

# Prompt for confirmation
confirm() {
    local prompt="${1:-Continue?}"
    local response
    
    echo -n "$prompt (y/N): "
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Expand path with environment variables
expand_path() {
    local path="$1"
    # Expand ~ and environment variables
    eval echo "$path"
}

# Normalize path (remove trailing slash, expand variables)
normalize_path() {
    local path="$1"
    path="$(expand_path "$path")"
    # Remove trailing slash unless it's root
    if [[ "$path" != "/" ]]; then
        path="${path%/}"
    fi
    echo "$path"
}

# Get relative path for repo storage
get_repo_path() {
    local path="$1"
    local normalized="$(normalize_path "$path")"
    
    # If path starts with $HOME, store relative to HOME (literal string, not variable)
    if [[ "$normalized" == "$HOME"* ]]; then
        echo "HOME${normalized#$HOME}"
    else
        # Store absolute paths as-is
        echo "$normalized"
    fi
}

# Convert repo path back to filesystem path
get_filesystem_path() {
    local repo_path="$1"
    # Handle $HOME expansion in tracked.conf entries
    if [[ "$repo_path" == "\$HOME"* ]]; then
        echo "$HOME${repo_path#\$HOME}"
    elif [[ "$repo_path" == "HOME"* ]]; then
        echo "$HOME${repo_path#HOME}"
    else
        echo "$repo_path"
    fi
}

# Check if path is ignored
is_ignored() {
    local path="$1"
    local pattern
    
    # Check ignored.conf
    if [[ -f "$IGNORED_ITEMS" ]]; then
        while IFS= read -r pattern || [[ -n "$pattern" ]]; do
            [[ -z "$pattern" || "$pattern" == \#* ]] && continue
            
            # Check if path matches pattern
            if [[ "$path" == $pattern ]]; then
                return 0
            fi
        done < "$IGNORED_ITEMS"
    fi
    
    # Check .gitignore files in path hierarchy
    local check_path="$path"
    while [[ "$check_path" != "/" && "$check_path" != "." ]]; do
        local gitignore="$(dirname "$check_path")/.gitignore"
        if [[ -f "$gitignore" ]]; then
            local basename="$(basename "$path")"
            if grep -q "^$basename$" "$gitignore" 2>/dev/null; then
                return 0
            fi
        fi
        check_path="$(dirname "$check_path")"
    done
    
    return 1
}

# Check if path is tracked
is_tracked() {
    local path="$1"
    local normalized="$(get_repo_path "$path")"
    
    if [[ -f "$TRACKED_ITEMS" ]]; then
        grep -q "^${normalized}$" "$TRACKED_ITEMS" 2>/dev/null
    else
        return 1
    fi
}

# Check if path exists (handles both files and symlinks)
path_exists() {
    local path="$1"
    [[ -e "$path" ]] || [[ -L "$path" ]]
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Safe copy with backup
safe_copy() {
    local source="$1"
    local dest="$2"
    
    if [[ -e "$dest" ]]; then
        # Create backup
        local backup="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
        log_debug "Backing up existing file: $dest → $backup"
        cp -a "$dest" "$backup"
    fi
    
    cp -a "$source" "$dest"
}

# Get OS type
get_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "mac"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}
