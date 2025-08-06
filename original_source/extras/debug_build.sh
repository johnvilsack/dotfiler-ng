#!/usr/bin/env bash

# Debug script to understand why build isn't creating symlinks

set -euo pipefail

# Source the functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/dotfiler-lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/ignore.sh"

echo "=== BUILD DEBUG ==="
echo ""

echo "1. Environment:"
echo "   DOTFILESPATH: ${DOTFILESPATH:-NOT SET}"
echo "   OS: ${OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}"
echo ""

if [[ -z "${OS:-}" ]]; then
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

dotfiles_base="$DOTFILESPATH/$OS/files"
echo "2. Repository structure:"
echo "   Base: $dotfiles_base"
if [[ -d "$dotfiles_base" ]]; then
    echo "   Contents:"
    find "$dotfiles_base" -type f | head -10 | while read -r file; do
        echo "     FILE: $file"
    done
else
    echo "   ERROR: Repository base doesn't exist!"
    exit 1
fi
echo ""

echo "3. Checking for foo.csv specifically:"
find "$dotfiles_base" -name "*foo.csv*" -type f | while read -r file; do
    echo "   FOUND: $file"
    
    # Test the path conversion logic
    dir=$(dirname "$file")
    dir_name=$(basename "$(dirname "$file")")
    relative_from_dir="${file#$dir/}"
    
    echo "     dir: $dir"
    echo "     dir_name: $dir_name" 
    echo "     relative_from_dir: $relative_from_dir"
    
    original_path=""
    if [[ "$dir_name" == "HOME" ]]; then
        original_path="$HOME/$relative_from_dir"
    else
        original_path="/$dir_name/$relative_from_dir"
    fi
    
    echo "     original_path: $original_path"
    echo "     file exists at original: $(if [[ -e "$original_path" ]]; then echo "YES"; else echo "NO"; fi)"
    echo "     is symlink: $(if [[ -L "$original_path" ]]; then echo "YES ($(readlink "$original_path"))"; else echo "NO"; fi)"
    
    # Check if ignored
    if should_ignore "$original_path"; then
        echo "     IGNORED: YES"
    else
        echo "     IGNORED: NO"
    fi
    
done

echo ""
echo "4. Current state of $HOME/test/foo.csv:"
if [[ -e "$HOME/test/foo.csv" ]]; then
    if [[ -L "$HOME/test/foo.csv" ]]; then
        echo "   STATUS: Symlink pointing to $(readlink "$HOME/test/foo.csv")"
    else
        echo "   STATUS: Regular file"
    fi
else
    echo "   STATUS: Does not exist"
fi

echo ""
echo "=== END DEBUG ==="