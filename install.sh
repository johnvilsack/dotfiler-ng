#!/usr/bin/env bash
# install.sh - Install dotfiler

set -euo pipefail
rm -rf /tmp/dotfiler

INSTALL_DIR="${1:-$HOME/.local/bin}"
REPO_URL="https://github.com/johnvilsack/dotfiler"

echo "Installing dotfiler to $INSTALL_DIR..."

# Clone or download
if command -v git >/dev/null 2>&1; then
    echo "Git found, cloning repository..."
    git clone "$REPO_URL" /tmp/dotfiler
    cd /tmp/dotfiler
else
    echo "Git not found. Please install git first."
    exit 1
fi

# Create install 
echo "Creating install directory..."
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying files to $INSTALL_DIR..."
cp /tmp/dotfiler/dotfiler "$INSTALL_DIR/"
echo "Copying dotfiler-lib to $INSTALL_DIR..."
cp -rf /tmp/dotfiler/dotfiler-lib "$INSTALL_DIR/"
echo "Make X to $INSTALL_DIR..."
chmod +x "$INSTALL_DIR/dotfiler"

# Cleanup
echo "Cleaning up..."
rm -rf /tmp/dotfiler

echo "dotfiler installed!"
echo "Make sure $INSTALL_DIR is in your PATH"