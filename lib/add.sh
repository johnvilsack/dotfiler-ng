#!/usr/bin/env bash
# add.sh - Add files to dotfiler

cmd_add() {
    if [[ $# -eq 0 ]]; then
        log_error "No file specified"
        echo "Usage: dotfiler add <file_or_directory>"
        exit 1
    fi
    
    local input="$1"
    local source_path=""
    
    # Try to resolve the path
    if [[ -e "$input" ]]; then
        source_path=$(get_realpath "$input")
    elif [[ -e "$HOME/$input" ]]; then
        source_path=$(get_realpath "$HOME/$input")
    elif command -v "$input" >/dev/null 2>&1; then
        source_path=$(which "$input")
    else
        log_error "Cannot find: $input"
        exit 1
    fi
    
    log_info "Found: $source_path"
    
    # Determine destination based on whether it's in HOME or not
    if [[ "$source_path" == "$HOME"* ]]; then
        if [[ "$source_path" == "$HOME" ]]; then
            log_error "Cannot add the entire HOME directory"
            exit 1
        fi
        relative_path="${source_path#$HOME/}"
        dest_path="$DOTFILESPATH/mac/files/HOME/$relative_path"
    else
        relative_path="${source_path#/}"
        dest_path="$DOTFILESPATH/mac/files/$relative_path"
    fi
    
    # Create destination directory
    dest_dir="$(dirname "$dest_path")"
    mkdir -p "$dest_dir"
    
    # Remove existing destination
    if [[ -e "$dest_path" ]]; then
        log_warning "Removing existing: $dest_path"
        rm -rf "$dest_path"
    fi
    
    # Copy the file or directory
    cp -r "$source_path" "$dest_path"
    
    if [[ -d "$source_path" ]]; then
        log_success "Added directory: $source_path"
    else
        log_success "Added file: $source_path"
    fi
    
    log_info "Destination: $dest_path"
}