#!/usr/bin/env bash
# config.sh - Configuration management
# Compatible with bash 3.2+ (macOS default)

# Configuration defaults
readonly DEFAULT_CONFIG_DIR="$HOME/.config/dotfiler"
readonly DEFAULT_REPO_PATH="${DOTFILESPATH:-$HOME/github/dotfiles}"

# Config file paths
CONFIG_DIR="${DOTFILER_CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
CONFIG_FILE="$CONFIG_DIR/config"
TRACKED_ITEMS="$CONFIG_DIR/tracked.conf"
IGNORED_ITEMS="$CONFIG_DIR/ignored.conf"
DELETED_ITEMS="$CONFIG_DIR/deleted.conf"

# Initialize configuration
init_config() {
    # Create config directory if it doesn't exist
    ensure_dir "$CONFIG_DIR"
    
    # Load or create main config
    if [[ -f "$CONFIG_FILE" ]]; then
        # Don't set a default DOTFILESPATH - let the config's default work
        source "$CONFIG_FILE"
    else
        create_default_config
    fi
    
    # Set derived variables
    OS="${OS:-$(get_os)}"
    REPO_PATH="${REPO_PATH:-$DEFAULT_REPO_PATH}"
    REPO_FILES="$REPO_PATH/$OS/files"
    
    # Ensure repo structure exists
    ensure_dir "$REPO_FILES"
    ensure_dir "$REPO_FILES/HOME"
    
    # Create config files if they don't exist
    [[ -f "$TRACKED_ITEMS" ]] || touch "$TRACKED_ITEMS"
    [[ -f "$IGNORED_ITEMS" ]] || create_default_ignores
    [[ -f "$DELETED_ITEMS" ]] || touch "$DELETED_ITEMS"
    
    # Export for use in other scripts
    export CONFIG_DIR CONFIG_FILE
    export TRACKED_ITEMS IGNORED_ITEMS DELETED_ITEMS
    export REPO_PATH REPO_FILES OS
}

# Create default configuration
create_default_config() {
    log_info "Creating default configuration..."
    
    cat > "$CONFIG_FILE" << EOF
# Dotfiler-NG Configuration
# Generated on $(date)

# Repository path (where dotfiles are stored)
REPO_PATH="\${DOTFILESPATH:-\$HOME/github/dotfiles}"

# Operating system (auto-detected, can override)
OS="$(get_os)"

# Sync behavior
SYNC_DELETIONS=true
AUTO_ADD_NEW=true
PRESERVE_PERMISSIONS=true

# Deletion lifecycle (in days)
DELETE_ACTIVE_DAYS=90
DELETE_PASSIVE_DAYS=120

# Debug mode
DEBUG=${DEBUG:-0}
EOF
    
    log_success "Created configuration at: $CONFIG_FILE"
}

# Create default ignore patterns
create_default_ignores() {
    cat > "$IGNORED_ITEMS" << 'EOF'
# Default ignore patterns
.DS_Store
*.swp
*.swo
*~
.*.swp
.*.swo
Thumbs.db
desktop.ini
*.log
*.cache
*.tmp
.git
.svn
.hg
node_modules
__pycache__
*.pyc
.env
.env.local
EOF
    
    log_info "Created default ignore patterns at: $IGNORED_ITEMS"
}

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-}"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        local value="$(grep "^$key=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)"
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Update existing value or add new one
        if grep -q "^$key=" "$CONFIG_FILE"; then
            # Use different sed syntax for macOS vs Linux
            if [[ "$OS" == "mac" ]]; then
                sed -i '' "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
            else
                sed -i "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
            fi
        else
            echo "$key=$value" >> "$CONFIG_FILE"
        fi
    else
        echo "$key=$value" > "$CONFIG_FILE"
    fi
}

# Validate configuration
validate_config() {
    local valid=true
    
    # Check repo path exists
    if [[ ! -d "$REPO_PATH" ]]; then
        log_error "Repository path does not exist: $REPO_PATH"
        valid=false
    fi
    
    # Check OS is valid
    if [[ "$OS" != "mac" && "$OS" != "linux" ]]; then
        log_error "Unknown operating system: $OS"
        valid=false
    fi
    
    if [[ "$valid" == "false" ]]; then
        return 1
    fi
    
    return 0
}

# Show current configuration
show_config() {
    echo "Dotfiler-NG Configuration:"
    echo "  Config Directory: $CONFIG_DIR"
    echo "  Repository Path: $REPO_PATH"
    echo "  Repository Files: $REPO_FILES"
    echo "  Operating System: $OS"
    echo "  Machine ID: $(get_config MACHINE_ID)"
    echo ""
    echo "Config Files:"
    echo "  Tracked Items: $TRACKED_ITEMS"
    echo "  Ignored Items: $IGNORED_ITEMS"
    echo "  Deleted Items: $DELETED_ITEMS"
}
