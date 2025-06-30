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
cp /tmp/dotfiler/dotfiler "$INSTALL_DIR/" && cp -rf /tmp/dotfiler/dotfiler-lib "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/dotfiler"

# Get hash of latest commit and add for future update checks
DOTFILER_HASH_FILE="$HOME/.local/.dotfiler_last_hash"
DOTFILER_CURRENT_HASH=$(curl -s https://api.github.com/repos/johnvilsack/dotfiler/commits/HEAD | grep '"sha"' | head -1 | cut -d'"' -f4)
echo "$DOTFILER_CURRENT_HASH" > "$DOTFILER_HASH_FILE"
echo "Current commit hash: $DOTFILER_CURRENT_HASH"

# Cleanup
rm -rf /tmp/dotfiler

echo "dotfiler installed!"