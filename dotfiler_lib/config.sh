#!/usr/bin/env bash
# config.sh - Simple configuration management
# Compatible with bash 3.2+ (macOS default)

# Default configuration values
DEFAULT_CONFIG_DIR="$HOME/.config/dotfiler"
DEFAULT_REPO_PATH="${DOTFILESPATH:-$HOME/github/dotfiles}"

# Set configuration paths
CONFIG_DIR="${DOTFILER_CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
CONFIG_FILE="$CONFIG_DIR/config"
TRACKED_ITEMS="$CONFIG_DIR/tracked.conf"
IGNORED_ITEMS="$CONFIG_DIR/ignored.conf"
DELETED_ITEMS="$CONFIG_DIR/deleted.conf"

# Initialize configuration
init_config() {
    # Ensure config directory exists
    ensure_dir "$CONFIG_DIR"
    
    # Load config file if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    # Set defaults
    OS="${OS:-$(get_os)}"
    REPO_PATH="${REPO_PATH:-$DEFAULT_REPO_PATH}"
    REPO_FILES="$REPO_PATH/$OS/files"
    
    # Ensure repo structure exists
    ensure_dir "$REPO_FILES/HOME"
    
    # Create config files if they don't exist
    [[ -f "$TRACKED_ITEMS" ]] || touch "$TRACKED_ITEMS"
    [[ -f "$IGNORED_ITEMS" ]] || touch "$IGNORED_ITEMS"
    [[ -f "$DELETED_ITEMS" ]] || touch "$DELETED_ITEMS"
    
    # Debug output
    log_debug "CONFIG_DIR: $CONFIG_DIR"
    log_debug "REPO_PATH: $REPO_PATH"
    log_debug "REPO_FILES: $REPO_FILES"
    log_debug "OS: $OS"
}

# Validate configuration
validate_config() {
    # Check if repo path exists
    if [[ ! -d "$REPO_PATH" ]]; then
        log_error "Repository path does not exist: $REPO_PATH"
        return 1
    fi
    
    # Check if config files exist
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        log_error "Tracked items file not found: $TRACKED_ITEMS"
        return 1
    fi
    
    return 0
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# Dotfiler Configuration
# Generated on $(date)

# Repository path
REPO_PATH="$REPO_PATH"

# Operating system
OS="$OS"

# Debug mode
DEBUG="${DEBUG:-0}"
EOF
    
    log_success "Configuration saved to: $CONFIG_FILE"
}