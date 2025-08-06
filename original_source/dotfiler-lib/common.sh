# Legacy color definitions (fallback when clog not available)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if clog is available
CLOG_AVAILABLE=false
if command -v clog >/dev/null 2>&1; then
    CLOG_AVAILABLE=true
fi

# Smart logging functions that use clog when available, fallback to legacy
log_info() {
    if [[ "$CLOG_AVAILABLE" == true ]]; then
        clog INFO "$1"
    else
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [[ "$CLOG_AVAILABLE" == true ]]; then
        clog SUCCESS "$1"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if [[ "$CLOG_AVAILABLE" == true ]]; then
        clog WARNING "$1"
    else
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    if [[ "$CLOG_AVAILABLE" == true ]]; then
        clog ERROR "$1"
    else
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

# Global environment setup - ensure required variables are set
if [[ -z "${OS:-}" ]]; then
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    export OS
fi

if [[ -z "${DOTFILESPATH:-}" ]]; then
    log_error "DOTFILESPATH environment variable is not set"
    log_error "Please set DOTFILESPATH to your dotfiles repository path"
    log_error "Example: export DOTFILESPATH=\"\$HOME/.dotfiles\""
    exit 1
fi

# Security validation functions
validate_path() {
    local path="$1"
    local description="${2:-path}"
    
    # Check for dangerous characters
    if [[ "$path" =~ $'\n'|$'\0'|$'\t' ]]; then
        log_error "Invalid characters in $description: $path"
        return 1
    fi
    
    # Check for suspicious patterns
    if [[ "$path" == *".."* ]] || [[ "$path" == *"/./"* ]]; then
        log_warning "Potentially unsafe $description: $path"
    fi
    
    return 0
}

validate_filename() {
    local name="$1"
    
    if [[ "$name" =~ $'\n'|$'\0'|$'\t'|$'\r' ]]; then
        log_error "Filename contains invalid characters: $name"
        return 1
    fi
    
    return 0
}