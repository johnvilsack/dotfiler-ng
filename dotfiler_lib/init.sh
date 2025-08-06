#!/usr/bin/env bash
# init.sh - Interactive configuration and initialization
# Compatible with bash 3.2+ (macOS default)

cmd_config() {
    cmd_init "$@"
}

cmd_init() {
    # Ensure we have the necessary variables set
    # Source common.sh to get get_os function if not already available
    if ! type -t get_os >/dev/null 2>&1; then
        source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
    fi
    
    # Set defaults if not already set
    : ${DEFAULT_CONFIG_DIR:="$HOME/.config/dotfiler"}
    : ${DEFAULT_REPO_PATH:="${DOTFILESPATH:-$HOME/github}/dotfiles"}
    : ${CONFIG_DIR:="${DOTFILER_CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"}
    : ${CONFIG_FILE:="$CONFIG_DIR/config"}
    : ${TRACKED_ITEMS:="$CONFIG_DIR/tracked.conf"}
    : ${IGNORED_ITEMS:="$CONFIG_DIR/ignored.conf"}
    : ${DELETED_ITEMS:="$CONFIG_DIR/deleted.conf"}
    : ${OS:="$(get_os)"}
    
    log_info "Dotfiler configuration and initialization"
    echo ""
    
    # Show what environment variables are being used
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "DEBUG: DEFAULT_REPO_PATH: $DEFAULT_REPO_PATH"
        echo "DEBUG: CONFIG_DIR: $CONFIG_DIR" 
        echo "DEBUG: DOTFILESPATH env var: ${DOTFILESPATH:-not set}"
        echo "DEBUG: HOME: $HOME"
        echo "DEBUG: OS: $OS"
        echo "DEBUG: Current working directory: $(pwd)"
    fi
    
    # Check if config files exist in config directory
    if [[ -f "$CONFIG_FILE" && -f "$TRACKED_ITEMS" && -f "$IGNORED_ITEMS" && -f "$DELETED_ITEMS" ]]; then
        log_info "Existing configuration found in: $CONFIG_DIR"
        # Load config before showing it
        source "$CONFIG_FILE"
        REPO_PATH="${REPO_PATH:-$DEFAULT_REPO_PATH}"
        REPO_FILES="$REPO_PATH/$OS/files"
        show_config
        echo ""
        
        if confirm "Reconfigure dotfiler?"; then
            reconfigure_existing
        fi
        return 0
    fi
    
    # Check if config files exist in default repo location (where they would be synced)
    local default_repo_config_dir="${DEFAULT_REPO_PATH}/${OS:-$(get_os)}/files/\$HOME/.config/dotfiler"
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "DEBUG: Checking for existing config in: $default_repo_config_dir"
        echo "DEBUG: Directory exists: $(if [[ -d "$default_repo_config_dir" ]]; then echo "YES"; else echo "NO"; fi)"
    fi
    
    if [[ -d "$default_repo_config_dir" && -f "$default_repo_config_dir/config" ]]; then
        if [[ "${DEBUG:-0}" == "1" ]]; then
            echo "DEBUG: Config file exists: YES"
        fi
        log_info "Found existing configuration in default repository: $default_repo_config_dir"
        
        if confirm "Import configuration from repository?"; then
            import_repo_config "$default_repo_config_dir"
            return 0
        fi
    fi
    
    # No existing config found - interactive setup
    log_info "No existing configuration found. Setting up dotfiler..."
    echo ""
    
    # Ask if new or existing repo
    echo "Are you:"
    echo "  1. Setting up a fresh dotfiles repository (new user)"
    echo "  2. Using an existing dotfiles repository"
    echo ""
    
    local choice
    while true; do
        echo -n "Choose option (1 or 2): "
        read -r choice
        case "$choice" in
            1|"1")
                setup_fresh_install
                break
                ;;
            2|"2")
                setup_existing_repo
                break
                ;;
            *)
                log_error "Please choose 1 or 2"
                ;;
        esac
    done
}

# Setup fresh installation
setup_fresh_install() {
    log_info "Setting up fresh dotfiles repository..."
    echo ""
    
    # Get repository path
    local repo_path
    echo -n "Repository path [${DEFAULT_REPO_PATH}]: "
    read -r repo_path
    repo_path="${repo_path:-$DEFAULT_REPO_PATH}"
    
    # Expand environment variables
    repo_path="$(expand_path "$repo_path")"
    
    # Check if path exists
    if [[ ! -d "$repo_path" ]]; then
        log_info "Repository path does not exist: $repo_path"
        
        if confirm "Create new git repository at this location?"; then
            # Create directory structure
            ensure_dir "$repo_path"
            ensure_dir "$repo_path/$OS/files"
            ensure_dir "$repo_path/$OS/files/\$HOME"
            
            # Initialize git repository
            cd "$repo_path"
            git init
            
            # Create initial README
            cat > README.md << EOF
# My Dotfiles

Managed with [dotfiler-ng](https://github.com/johnvilsack/dotfiler-ng)

## Structure
- \`$OS/files/\` - Contains actual dotfiles
- \`.config/dotfiler/\` - Dotfiler configuration

## Usage
\`\`\`bash
dotfiler add ~/.zshrc
dotfiler sync
\`\`\`
EOF
            
            git add README.md
            git commit -m "Initial commit - dotfiler repository"
            
            log_success "Created git repository at: $repo_path"
        else
            log_error "Repository setup cancelled"
            return 1
        fi
    fi
    
    # Create configuration
    create_fresh_config "$repo_path"
    
    # Offer initial sync
    if confirm "Perform initial sync now?"; then
        log_info "Running initial sync..."
        cmd_sync
    fi
}

# Setup existing repository
setup_existing_repo() {
    log_info "Using existing dotfiles repository..."
    echo ""
    
    local repo_path
    while true; do
        echo -n "Path to existing repository: "
        read -r repo_path
        
        if [[ -z "$repo_path" ]]; then
            log_error "Repository path cannot be empty"
            continue
        fi
        
        # Expand environment variables
        repo_path="$(expand_path "$repo_path")"
        
        if [[ ! -d "$repo_path" ]]; then
            log_error "Repository path does not exist: $repo_path"
            
            if confirm "Try a different path?"; then
                continue
            else
                return 1
            fi
        fi
        
        break
    done
    
    # Look for existing config files in repo (where they would be synced)
    local repo_config_dir="$repo_path/${OS:-$(get_os)}/files/\$HOME/.config/dotfiler"
    
    if [[ -d "$repo_config_dir" && -f "$repo_config_dir/config" ]]; then
        log_info "Found existing configuration in repository"
        
        if confirm "Import configuration from repository?"; then
            import_repo_config "$repo_config_dir"
            
            # Offer repo-first sync
            if confirm "Perform repo-first sync to migrate existing setup?"; then
                log_info "Running repo-first sync..."
                cmd_sync --repo-first
            fi
            
            return 0
        fi
    fi
    
    # No config in repo - offer to create fresh config
    log_warning "No dotfiler configuration found in repository"
    echo ""
    echo "Options:"
    echo "  1. Create fresh configuration files"
    echo "  2. Choose a different repository path"
    echo ""
    
    local choice
    while true; do
        echo -n "Choose option (1 or 2): "
        read -r choice
        case "$choice" in
            1|"1")
                create_fresh_config "$repo_path"
                
                # Offer repo-first sync
                if confirm "Perform repo-first sync?"; then
                    log_info "Running repo-first sync..."
                    cmd_sync --repo-first
                fi
                break
                ;;
            2|"2")
                setup_existing_repo  # Recursive call
                break
                ;;
            *)
                log_error "Please choose 1 or 2"
                ;;
        esac
    done
}

# Import configuration from repository
import_repo_config() {
    local repo_config_dir="$1"
    
    log_info "Importing configuration from: $repo_config_dir"
    
    # Ensure local config directory exists
    ensure_dir "$CONFIG_DIR"
    
    # Copy config files
    if [[ -f "$repo_config_dir/config" ]]; then
        cp "$repo_config_dir/config" "$CONFIG_FILE"
        log_success "Imported config"
    fi
    
    if [[ -f "$repo_config_dir/tracked.conf" ]]; then
        cp "$repo_config_dir/tracked.conf" "$TRACKED_ITEMS"
        log_success "Imported tracked items"
    fi
    
    if [[ -f "$repo_config_dir/ignored.conf" ]]; then
        cp "$repo_config_dir/ignored.conf" "$IGNORED_ITEMS"
        log_success "Imported ignore patterns"
    fi
    
    if [[ -f "$repo_config_dir/deleted.conf" ]]; then
        cp "$repo_config_dir/deleted.conf" "$DELETED_ITEMS"
        log_success "Imported deletion history"
    fi
    
    # Reinitialize with imported config
    source "$CONFIG_FILE"
    init_config
    
    log_success "Configuration imported successfully"
    show_config
}

# Create fresh configuration
create_fresh_config() {
    local repo_path="$1"
    
    log_info "Creating fresh configuration..."
    
    # Ensure config directory exists
    ensure_dir "$CONFIG_DIR"
    
    # Determine if we should use environment variable or absolute path
    # If repo_path matches the expanded DEFAULT_REPO_PATH, use the variable form
    local repo_path_config
    if [[ "$repo_path" == "$(expand_path "$DEFAULT_REPO_PATH")" ]]; then
        # Use the environment variable form
        repo_path_config='${DOTFILESPATH:-$HOME/github/dotfiles}'
    else
        # Use the provided path
        repo_path_config="$repo_path"
    fi
    
    # Create main config file
    cat > "$CONFIG_FILE" << EOF
# Dotfiler Configuration
# Generated on $(date)

# Repository path (where dotfiles are stored)
# Can use environment variables like \$DOTFILESPATH
REPO_PATH="$repo_path_config"

# Operating system (auto-detected, can override)
OS="$OS"

# Machine-specific identifier (for future use)
MACHINE_ID="$(hostname -s)"

# Sync behavior
SYNC_DELETIONS=true
AUTO_ADD_NEW=true
PRESERVE_PERMISSIONS=true

# Deletion lifecycle (in days)
DELETE_ACTIVE_DAYS=90
DELETE_PASSIVE_DAYS=120

# Debug mode
DEBUG=0
EOF
    
    # Create other config files
    touch "$TRACKED_ITEMS"
    create_default_ignores
    touch "$DELETED_ITEMS"
    
    # Also save config to repository for portability (in the correct sync location)
    local repo_config_dir="$repo_path/${OS:-$(get_os)}/files/\$HOME/.config/dotfiler"
    ensure_dir "$repo_config_dir"
    cp "$CONFIG_FILE" "$repo_config_dir/"
    cp "$IGNORED_ITEMS" "$repo_config_dir/"
    cp "$TRACKED_ITEMS" "$repo_config_dir/"
    cp "$DELETED_ITEMS" "$repo_config_dir/"
    
    log_success "Created configuration at: $CONFIG_DIR"
    log_success "Saved portable config to: $repo_config_dir"
    
    # Reinitialize with new config
    source "$CONFIG_FILE"
    init_config
    
    show_config
}

# Reconfigure existing setup
reconfigure_existing() {
    echo ""
    echo "Reconfiguration options:"
    echo "  1. Change repository path"
    echo "  2. Reset to defaults"
    echo "  3. Import from repository"
    echo "  4. Cancel"
    echo ""
    
    local choice
    while true; do
        echo -n "Choose option (1-4): "
        read -r choice
        case "$choice" in
            1|"1")
                change_repo_path
                break
                ;;
            2|"2")
                if confirm "Reset all configuration to defaults?"; then
                    rm -f "$CONFIG_FILE" "$TRACKED_ITEMS" "$IGNORED_ITEMS" "$DELETED_ITEMS"
                    cmd_init
                fi
                break
                ;;
            3|"3")
                import_from_repository
                break
                ;;
            4|"4")
                log_info "Reconfiguration cancelled"
                break
                ;;
            *)
                log_error "Please choose 1-4"
                ;;
        esac
    done
}

# Change repository path
change_repo_path() {
    local current_path="$(get_config REPO_PATH)"
    echo ""
    echo -n "New repository path [$current_path]: "
    read -r new_path
    
    if [[ -n "$new_path" ]]; then
        new_path="$(expand_path "$new_path")"
        set_config "REPO_PATH" "$new_path"
        
        # Reinitialize
        source "$CONFIG_FILE"
        init_config
        
        log_success "Repository path updated to: $new_path"
        show_config
    else
        log_info "Repository path unchanged"
    fi
}

# Import from repository
import_from_repository() {
    local repo_path="$(get_config REPO_PATH)"
    local repo_config_dir="$repo_path/${OS:-$(get_os)}/files/\$HOME/.config/dotfiler"
    
    if [[ -d "$repo_config_dir" ]]; then
        import_repo_config "$repo_config_dir"
    else
        log_error "No configuration found in repository: $repo_config_dir"
    fi
}