#!/usr/bin/env bash
# install.sh - Install dotfiler

set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
REPO_URL="https://github.com/johnvilsack/dotfiler"

echo "Installing dotfiler to $INSTALL_DIR..."

# Copy files
cp dotfiler "$INSTALL_DIR/" && cp -rf dotfiler-lib "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/dotfiler"

echo "dotfiler installed!"
