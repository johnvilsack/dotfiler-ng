#!/usr/bin/env bash
# install.sh - Install dotfiler

set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"

echo "Installing dotfiler to $INSTALL_DIR..."

# Copy files
cp dotfiler "$INSTALL_DIR/" && cp -rf dotfiler_lib "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/dotfiler"

echo "✓ dotfiler installed!"
echo ""

# Run interactive configuration
# echo "Starting interactive configuration..."
# echo ""
# if [[ -x "$INSTALL_DIR/dotfiler" ]]; then
#     "$INSTALL_DIR/dotfiler" config
# else
#     echo "⚠ Could not run dotfiler config automatically"
#     echo "Please run 'dotfiler config' to complete setup"
# fi
