#!/usr/bin/env bash
# install.sh - Install dotfiler-ng

set -euo pipefail
rm -rf /tmp/dotfiler-ng

INSTALL_DIR="${1:-$HOME/.local/bin}"
REPO_URL="https://github.com/johnvilsack/dotfiler-ng"

echo "Installing dotfiler-ng to $INSTALL_DIR..."
echo ""

# Clone or download
if command -v git >/dev/null 2>&1; then
    git clone "$REPO_URL" /tmp/dotfiler-ng
    cd /tmp/dotfiler-ng
else
    echo "Git not found. Please install git first."
    exit 1
fi

# Check requirements
echo "Checking requirements..."

# Check for rsync
if ! command -v rsync >/dev/null 2>&1; then
    echo "ERROR: rsync is required but not found."
    echo "Please install rsync first:"
    echo "  macOS: rsync is pre-installed"
    echo "  Linux: sudo apt install rsync (or equivalent)"
    exit 1
fi

echo "✓ rsync found: $(rsync --version | head -1)"

# Check bash version
if [[ ${BASH_VERSION%%.*} -lt 3 ]]; then
    echo "ERROR: bash 3.2+ required, found: $BASH_VERSION"
    exit 1
fi

echo "✓ bash version: $BASH_VERSION"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Installing files..."
cp /tmp/dotfiler-ng/dotfiler "$INSTALL_DIR/"
cp -rf /tmp/dotfiler-ng/dotfiler_lib "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/dotfiler"
chmod +x "$INSTALL_DIR/dotfiler_lib"/*.sh

echo "✓ Installed dotfiler executable to: $INSTALL_DIR/dotfiler"
echo "✓ Installed dotfiler_lib to: $INSTALL_DIR/dotfiler_lib/"

# Get hash of latest commit for update tracking
DOTFILER_HASH_FILE="$HOME/.local/.dotfiler_ng_last_hash"
if command -v curl >/dev/null 2>&1; then
    DOTFILER_CURRENT_HASH=$(curl -s https://api.github.com/repos/johnvilsack/dotfiler-ng/commits/HEAD | grep '"sha"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "unknown")
    echo "$DOTFILER_CURRENT_HASH" > "$DOTFILER_HASH_FILE"
    echo "✓ Current commit hash: $DOTFILER_CURRENT_HASH"
else
    echo "⚠ curl not found - update tracking disabled"
fi

# Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠ WARNING: $INSTALL_DIR is not in your PATH"
    echo "Add this to your shell profile (e.g., ~/.bashrc, ~/.zshrc):"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi

# Cleanup
rm -rf /tmp/dotfiler-ng

echo ""
echo "✓ dotfiler-ng installed successfully!"
echo ""

# Run interactive configuration
echo "Starting interactive configuration..."
echo ""
if [[ -x "$INSTALL_DIR/dotfiler" ]]; then
    # Make sure we have the PATH set for this session
    export PATH="$INSTALL_DIR:$PATH"
    "$INSTALL_DIR/dotfiler" config
else
    echo "⚠ Could not run dotfiler config automatically"
    echo "Please run 'dotfiler config' to complete setup"
fi

echo ""
echo "Key features:"
echo "  • Automatic deletion detection"
echo "  • Rsync-based sync engine"  
echo "  • Symlink migration"
echo "  • Cross-machine coordination"
echo ""
echo "Quick start:"
echo "  dotfiler config           # Interactive setup (run again anytime)"
echo "  dotfiler help             # Show all commands"
echo "  dotfiler add ~/.zshrc     # Track a file"
echo "  dotfiler sync             # Sync dotfiles"