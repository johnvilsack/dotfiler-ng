#!/usr/bin/env bash
# common.sh - Shared utility functions

# Configuration
DOTFILESPATH="${DOTFILESPATH:-$HOME/.dotfiles}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
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

# Check if required tools are available
check_requirements() {
    local missing_tools=()
    
    for tool in find ln mkdir cp rm realpath; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check if DOTFILESPATH exists
    if [[ ! -d "$DOTFILESPATH" ]]; then
        log_error "Dotfiles directory not found: $DOTFILESPATH"
        echo "Initialize it with: mkdir -p $DOTFILESPATH"
        exit 1
    fi
}

# Get portable realpath
get_realpath() {
    if command -v realpath >/dev/null 2>&1; then
        realpath "$1"
    elif command -v greadlink >/dev/null 2>&1; then
        greadlink -f "$1"
    else
        # Fallback for older systems
        (cd "$(dirname "$1")" && pwd -P)/$(basename "$1")
    fi
}