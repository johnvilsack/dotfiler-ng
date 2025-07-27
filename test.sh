#!/usr/bin/env bash

# test.sh - Test script for dotfiler using local repository
# This script installs dotfiler from the current repository for testing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "install.sh" ]] || [[ ! -f "dotfiler" ]]; then
    log_error "Please run this script from the dotfiler repository root"
    exit 1
fi

# Get the current directory (repo root)
REPO_DIR="$(pwd)"

# Installation directories
BIN_DIR="$HOME/.local/bin"
LIB_DIR="$BIN_DIR/dotfiler-lib"

log_info "Installing dotfiler from local repository for testing..."

# Create directories
mkdir -p "$BIN_DIR"
mkdir -p "$LIB_DIR"

# Copy main executables
log_info "Installing main executables..."
cp "$REPO_DIR/dotfiler" "$BIN_DIR/dotfiler"
cp "$REPO_DIR/clog" "$BIN_DIR/clog"
cp "$REPO_DIR/clog.ps1" "$BIN_DIR/clog.ps1" 
cp "$REPO_DIR/pclog" "$BIN_DIR/pclog"
chmod +x "$BIN_DIR/dotfiler"
chmod +x "$BIN_DIR/clog"
chmod +x "$BIN_DIR/pclog"

# Copy library files
log_info "Installing library files..."
cp -r "$REPO_DIR/dotfiler-lib/"* "$LIB_DIR/"

# Make all shell scripts executable
find "$LIB_DIR" -name "*.sh" -exec chmod +x {} \;

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    log_warning "~/.local/bin is not in your PATH"
    log_info "Add the following to your shell profile:"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    log_info "Or run: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    log_info "       echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
fi

# Set up environment variables if not already set
DOTFILESPATH_SET=false
if [[ -z "${DOTFILESPATH:-}" ]]; then
    log_warning "DOTFILESPATH not set, using default: \$HOME/.dotfiles"
    echo 'export DOTFILESPATH="$HOME/.dotfiles"' >> ~/.bashrc 2>/dev/null || true
    echo 'export DOTFILESPATH="$HOME/.dotfiles"' >> ~/.zshrc 2>/dev/null || true
    export DOTFILESPATH="$HOME/.dotfiles"
    DOTFILESPATH_SET=true
fi

# Create dotfiles directory if it doesn't exist
mkdir -p "$DOTFILESPATH"

log_success "Dotfiler installed successfully!"
log_info "Installation location: $BIN_DIR/dotfiler"
log_info "Library location: $LIB_DIR"

# Refresh PATH to make clog available immediately
export PATH="$BIN_DIR:$PATH"

# Test if clog is now available and report
if command -v clog >/dev/null 2>&1; then
    log_success "✓ clog command is available"
    # Demonstrate clog is working
    clog SUCCESS "Enhanced logging now active!"
else
    log_warning "clog command not found in PATH"
fi

# Test PowerShell clog if PowerShell is available
if command -v pwsh >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
    if command -v pclog >/dev/null 2>&1; then
        log_success "✓ pclog (PowerShell version) is available"
        # Demonstrate PowerShell clog is working
        pclog SUCCESS "PowerShell logging active!"
    else
        log_warning "pclog command not found in PATH"
    fi
else
    log_info "PowerShell not detected - pclog not tested"
fi

if [[ "$DOTFILESPATH_SET" == true ]]; then
    log_warning "Please restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
fi

log_info "Test the installation:"
echo "    dotfiler --help"
echo "    dotfiler version"

# Quick test
if command -v dotfiler >/dev/null 2>&1; then
    log_success "✓ dotfiler command is available"
    dotfiler version
else
    log_warning "dotfiler command not found in PATH. You may need to restart your shell."
fi

log_info "Ready for testing!"