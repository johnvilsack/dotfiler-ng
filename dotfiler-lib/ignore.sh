#!/usr/bin/env bash

# Initialize ignore list file if it doesn't exist
IGNORELIST="$HOME/.config/dotfiler/ignore-list.txt"

# Ensure config directory exists
mkdir -p "$(dirname "$IGNORELIST")"

cmd_ignore() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: dotfiler ignore <file_or_directory>"
        exit 1
    fi
    
    # Convert to absolute path
    if [[ "$target" == "~"* ]]; then
        target="${target/#\~/$HOME}"
    elif [[ "$target" != "/"* ]]; then
        target="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
    fi
    
    # Convert absolute path to pattern relative to HOME for consistency
    if [[ "$target" == "$HOME"* ]]; then
        pattern="${target#$HOME/}"
    else
        pattern="$target"
    fi
    
    # Check if already in ignore list
    if [[ -f "$IGNORELIST" ]] && grep -Fxq "$pattern" "$IGNORELIST"; then
        log_warning "Pattern '$pattern' is already in ignore list"
        return 0
    fi
    
    # Add to ignore list
    echo "$pattern" >> "$IGNORELIST"
    log_success "Added '$pattern' to ignore list"
    
    # Clean up any existing files in repo that match this pattern
    log_info "Cleaning up existing files matching this pattern..."
    remove_ignored_from_repo "$pattern"
}

# Helper function to check if a path should be ignored
should_ignore() {
    local path="$1"
    
    # Return false (don't ignore) if ignore list doesn't exist
    [[ ! -f "$IGNORELIST" ]] && return 1
    
    # Convert path to relative format for matching
    local check_path
    if [[ "$path" == "$HOME"* ]]; then
        check_path="${path#$HOME/}"
    else
        check_path="$path"
    fi
    
    # Check against each pattern in ignore list
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        
        # Simple glob matching - bash's case statement supports basic patterns
        case "$check_path" in
            $pattern)
                return 0  # Should ignore
                ;;
        esac
        
        # Also check the full path for absolute patterns
        case "$path" in
            $pattern)
                return 0  # Should ignore
                ;;
        esac
        
    done < "$IGNORELIST"
    
    return 1  # Don't ignore
}

# Remove ignored files from the dotfiles repository
remove_ignored_from_repo() {
    local pattern="$1"  # Optional: specific pattern to clean, or empty for all
    
    if [[ -z "$DOTFILESPATH" ]]; then
        log_error "DOTFILESPATH environment variable is not set"
        return 1
    fi
    
    if [[ -z "$OS" ]]; then
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    
    local repo_files_dir="$DOTFILESPATH/$OS/files"
    
    if [[ ! -d "$repo_files_dir" ]]; then
        log_info "No files directory found in repo: $repo_files_dir"
        return 0
    fi
    
    log_info "Scanning repository for ignored files..."
    
    # Find all files in the repo
    find "$repo_files_dir" -type f | while read -r repo_file; do
        # Convert repo path back to original path for ignore checking
        local relative_path="${repo_file#$repo_files_dir/}"
        local original_path
        
        if [[ "$relative_path" == HOME/* ]]; then
            # It's a HOME file
            original_path="$HOME/${relative_path#HOME/}"
        else
            # It's a system file
            original_path="/$relative_path"
        fi
        
        # Check if this file should be ignored
        local should_remove=false
        
        if [[ -n "$pattern" ]]; then
            # Check specific pattern
            case "$original_path" in
                *$pattern*) should_remove=true ;;
            esac
            case "${original_path#$HOME/}" in
                $pattern) should_remove=true ;;
            esac
        else
            # Check all ignore patterns
            if should_ignore "$original_path"; then
                should_remove=true
            fi
        fi
        
        if [[ "$should_remove" == true ]]; then
            log_info "Removing ignored file from repo: $repo_file"
            rm -f "$repo_file"
            
            # Clean up empty parent directories
            local parent_dir="$(dirname "$repo_file")"
            while [[ "$parent_dir" != "$repo_files_dir" ]] && [[ "$parent_dir" != "/" ]]; do
                if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
                    rmdir "$parent_dir" 2>/dev/null
                    log_info "Removed empty directory: $parent_dir"
                    parent_dir="$(dirname "$parent_dir")"
                else
                    break
                fi
            done
        fi
    done
}

# Command to clean up all ignored files from the repository
cmd_cleanup() {
    if [[ ! -f "$IGNORELIST" ]]; then
        log_info "No ignore list found - nothing to clean up"
        return 0
    fi
    
    log_info "Cleaning up all ignored files from repository..."
    remove_ignored_from_repo
    log_success "Cleanup completed"
}