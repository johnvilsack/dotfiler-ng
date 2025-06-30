#!/usr/bin/env bash
# install.sh - Install dotfiler

set -euo pipefail
rm -rf /tmp/dotfiler

INSTALL_DIR="${1:-$HOME/.local/bin}"
REPO_URL="https://github.com/johnvilsack/dotfiler"

echo "Installing dotfiler to $INSTALL_DIR..."

# Clone or download
if command -v git >/dev/null 2>&1; then
    git clone "$REPO_URL" /tmp/dotfiler
    cd /tmp/dotfiler
else
    echo "Git not found. Please install git first."
    exit 1
fi

# Create install 
mkdir -p "$INSTALL_DIR"

# Copy files
cp dotfiler/dotfiler "$INSTALL_DIR/" && cp -rf dotfiler/dotfiler-lib "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/dotfiler"

# Cleanup
rm -rf /tmp/dotfiler

echo "dotfiler installed!"