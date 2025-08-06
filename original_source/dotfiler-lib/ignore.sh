#!/usr/bin/env bash

# Configuration files are now defined in main dotfiler script
# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Migration function: migrate legacy files to new format
migrate_config_files() {
    # Migrate tracked-folders.txt to tracked.conf
    if [[ -f "$TRACKED_ITEMS" ]] && [[ ! -f "$TRACKED_ITEMS" ]]; then
        log_info "Migrating tracked-folders.txt to tracked.conf"
        cp "$TRACKED_ITEMS" "$TRACKED_ITEMS"
    fi
    
    # Migrate ignore-list.txt to ignored.conf  
    if [[ -f "$IGNORED_ITEMS" ]] && [[ ! -f "$IGNORED_ITEMS" ]]; then
        log_info "Migrating ignore-list.txt to ignored.conf"
        cp "$IGNORED_ITEMS" "$IGNORED_ITEMS"
    fi
    
    # Create deleted.conf if it doesn't exist
    if [[ ! -f "$DELETED_ITEMS" ]]; then
        touch "$DELETED_ITEMS"
    fi
}

# Check if ignoring a pattern would affect any tracked files
find_affected_tracked_files() {
    local ignore_pattern="$1"
    local affected_files=()
    
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        return 1
    fi
    
    while IFS= read -r tracked_line; do
        [[ -z "$tracked_line" ]] && continue
        
        # Convert to absolute path for comparison
        local tracked_abs="${tracked_line/#\$HOME/$HOME}"
        local ignore_abs="${ignore_pattern/#\$HOME/$HOME}"
        
        # Check if tracked file would be affected by ignore pattern
        if [[ "$tracked_abs" == "$ignore_abs"/* ]] || [[ "$tracked_abs" == "$ignore_abs" ]]; then
            affected_files+=("$tracked_line")
        fi
        
        # Also check glob patterns
        case "$tracked_line" in
            $ignore_pattern) affected_files+=("$tracked_line") ;;
        esac
        
    done < "$TRACKED_ITEMS"
    
    if [[ ${#affected_files[@]} -gt 0 ]]; then
        log_warning "Ignoring '$ignore_pattern' would affect these tracked files:"
        for file in "${affected_files[@]}"; do
            echo "  - $file"
        done
        return 0
    else
        return 1
    fi
}

# Check if adding a file would conflict with ignore patterns
find_conflicting_ignore_patterns() {
    local add_path="$1"
    local conflicting_patterns=()
    
    if [[ ! -f "$IGNORED_ITEMS" ]]; then
        return 1
    fi
    
    # Convert add path to tracking format
    local add_path_tracked
    if [[ "$add_path" == "$HOME"* ]]; then
        add_path_tracked='$HOME'"${add_path#$HOME}"
    else
        add_path_tracked="$add_path"
    fi
    
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        
        # Check if add path would be ignored by this pattern
        local pattern_abs="${pattern/#\$HOME/$HOME}"
        if [[ "$add_path" == "$pattern_abs"/* ]] || [[ "$add_path" == "$pattern_abs" ]]; then
            conflicting_patterns+=("$pattern")
        fi
        
        # Also check glob patterns
        case "$add_path_tracked" in
            $pattern) conflicting_patterns+=("$pattern") ;;
        esac
        
    done < "$IGNORED_ITEMS"
    
    if [[ ${#conflicting_patterns[@]} -gt 0 ]]; then
        log_warning "Adding '$add_path' conflicts with these ignore patterns:"
        for pattern in "${conflicting_patterns[@]}"; do
            echo "  - $pattern"
        done
        return 0
    else
        return 1
    fi
}

# Prompt user for confirmation
prompt_user() {
    local message="$1"
    echo -n "$message (y/N): "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

cmd_ignore() {
    # Ensure config migration happens
    migrate_config_files
    
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
    
    # Store pattern in same format as tracking system
    local pattern
    if [[ "$target" == "$HOME"* ]]; then
        pattern='$HOME'"${target#$HOME}"
    else
        pattern="$target"
    fi
    
    # Check if already in ignore list
    if [[ -f "$IGNORED_ITEMS" ]] && grep -Fxq "$pattern" "$IGNORED_ITEMS"; then
        log_warning "Pattern '$pattern' is already in ignore list"
        return 0
    fi
    
    # Check for conflicts with tracked files
    if find_affected_tracked_files "$pattern"; then
        echo ""
        if ! prompt_user "This will stop managing these tracked files. Continue?"; then
            log_info "Ignore operation cancelled"
            return 0
        fi
    fi
    
    # Add to ignore list
    echo "$pattern" >> "$IGNORED_ITEMS"
    log_success "Added '$pattern' to ignore list"
    
    # Remove any matching entries from tracking list to prevent conflicts
    remove_matching_from_tracking "$pattern"
    
    # Clean up any existing files in repo that match this pattern
    log_info "Cleaning up existing files matching this pattern..."
    remove_ignored_from_repo "$pattern"
}

# Remove matching entries from tracking list to prevent conflicts
remove_matching_from_tracking() {
    local ignore_pattern="$1"
    
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        return 0
    fi
    
    local temp_file
    temp_file=$(mktemp)
    local removed_count=0
    
    while IFS= read -r tracked_line; do
        [[ -z "$tracked_line" ]] && continue
        
        # Check if this tracked entry matches the ignore pattern
        local should_remove=false
        
        # Direct match with ignore pattern
        if [[ "$tracked_line" == "$ignore_pattern" ]]; then
            should_remove=true
        fi
        
        # Check if tracked path is under ignored directory
        # Convert both to absolute paths for comparison
        local tracked_abs="${tracked_line/#\$HOME/$HOME}"
        local ignore_abs="${ignore_pattern/#\$HOME/$HOME}"
        
        if [[ "$tracked_abs" == "$ignore_abs"/* ]]; then
            should_remove=true
        fi
        
        # Also check glob patterns
        case "$tracked_line" in
            $ignore_pattern) should_remove=true ;;
        esac
        
        if [[ "$should_remove" == true ]]; then
            log_info "Removing from tracking (conflicts with ignore): $tracked_line"
            removed_count=$((removed_count + 1))
        else
            echo "$tracked_line" >> "$temp_file"
        fi
    done < "$TRACKED_ITEMS"
    
    if [[ $removed_count -gt 0 ]]; then
        # Overwrite original file
        cat "$temp_file" > "$TRACKED_ITEMS"
        log_success "Removed $removed_count conflicting entries from tracking list"
        
        # Remove tracking file if empty
        if [[ ! -s "$TRACKED_ITEMS" ]]; then
            rm "$TRACKED_ITEMS"
            log_info "No more tracked files, removed tracking list"
        fi
    fi
    
    rm "$temp_file"
}

# Helper function to check if a path should be ignored
should_ignore() {
    local path="$1"
    
    # Return false (don't ignore) if ignore list doesn't exist
    [[ ! -f "$IGNORED_ITEMS" ]] && return 1
    
    # Convert path to tracking format for comparison
    local path_as_tracked
    if [[ "$path" == "$HOME"* ]]; then
        path_as_tracked='$HOME'"${path#$HOME}"
    else
        path_as_tracked="$path"
    fi
    
    # Check against each pattern in ignore list
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        
        # Direct match
        if [[ "$path_as_tracked" == "$pattern" ]]; then
            return 0  # Should ignore
        fi
        
        # Check if path is under ignored directory
        local pattern_abs="${pattern/#\$HOME/$HOME}"
        if [[ "$path" == "$pattern_abs"/* ]] || [[ "$path" == "$pattern_abs" ]]; then
            return 0  # Should ignore
        fi
        
        # Also check if any parent directory of the path matches the pattern
        local parent_path="$path"
        while [[ "$parent_path" != "/" ]] && [[ "$parent_path" != "$HOME" ]]; do
            parent_path="$(dirname "$parent_path")"
            
            # Convert parent to tracking format
            local parent_as_tracked
            if [[ "$parent_path" == "$HOME"* ]]; then
                parent_as_tracked='$HOME'"${parent_path#$HOME}"
            else
                parent_as_tracked="$parent_path"
            fi
            
            # Check if parent matches pattern
            if [[ "$parent_as_tracked" == "$pattern" ]]; then
                return 0  # Should ignore
            fi
            
            # Check glob patterns on parent
            case "$parent_as_tracked" in
                $pattern) return 0 ;;
            esac
        done
        
        # Check glob patterns against both formats
        case "$path_as_tracked" in
            $pattern) return 0 ;;
        esac
        
        case "$path" in
            $pattern) return 0 ;;
        esac
        
        # Check just filename for patterns like "*.log"
        local filename="${path##*/}"
        case "$filename" in
            $pattern) return 0 ;;
        esac
        
    done < "$IGNORED_ITEMS"
    
    return 1  # Don't ignore
}

# Remove ignored files from the dotfiles repository and handle symlinks
remove_ignored_from_repo() {
    local pattern="${1:-}"  # Optional: specific pattern to clean, or empty for all
    
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
    
    # Also check for currently tracked files that should be ignored
    if [[ -f "$TRACKED_ITEMS" ]]; then
        while IFS= read -r tracked_line; do
            [[ -z "$tracked_line" ]] && continue
            
            # Expand $HOME in tracked path to get actual path
            local actual_path="${tracked_line/#\$HOME/$HOME}"
            
            # Check if this tracked file should be ignored
            local should_remove=false
            
            if [[ -n "$pattern" ]]; then
                # Check specific pattern
                if should_ignore "$actual_path"; then
                    case "$actual_path" in
                        *$pattern*) should_remove=true ;;
                    esac
                    case "${actual_path#$HOME/}" in
                        $pattern) should_remove=true ;;
                    esac
                fi
            else
                # Check all ignore patterns
                if should_ignore "$actual_path"; then
                    should_remove=true
                fi
            fi
            
            if [[ "$should_remove" == true ]]; then
                log_info "Found ignored tracked file: $actual_path"
                
                # If it's currently symlinked, restore the original file
                if [[ -L "$actual_path" ]]; then
                    local link_target=$(readlink "$actual_path")
                    
                    # Determine expected repo path
                    local expected_repo_path
                    if [[ "$tracked_line" == '$HOME'* ]]; then
                        local rel_path="${tracked_line#\$HOME/}"
                        expected_repo_path="$repo_files_dir/HOME/$rel_path"
                    else
                        local rel_path="${tracked_line#/}"
                        expected_repo_path="$repo_files_dir/$rel_path"
                    fi
                    
                    # If symlinked to our repo, restore original
                    if [[ "$link_target" == "$expected_repo_path" ]]; then
                        log_info "Restoring original file and removing from tracking: $actual_path"
                        
                        # Determine if we need sudo
                        local needs_sudo=false
                        if [[ "$actual_path" != "$HOME"* ]] && [[ "$actual_path" == "/"* ]]; then
                            needs_sudo=true
                        fi
                        
                        # Remove symlink and restore original
                        if [[ "$needs_sudo" == true ]]; then
                            sudo rm "$actual_path"
                            sudo cp -r "$expected_repo_path" "$actual_path"
                        else
                            rm "$actual_path"
                            cp -r "$expected_repo_path" "$actual_path"
                        fi
                        
                        log_success "Restored original file: $actual_path"
                    fi
                fi
                
                # Remove from repo if it exists
                local repo_path
                if [[ "$tracked_line" == '$HOME'* ]]; then
                    local rel_path="${tracked_line#\$HOME/}"
                    repo_path="$repo_files_dir/HOME/$rel_path"
                else
                    local rel_path="${tracked_line#/}"
                    repo_path="$repo_files_dir/$rel_path"
                fi
                
                if [[ -e "$repo_path" ]]; then
                    log_info "Removing from repository: $repo_path"
                    rm -rf "$repo_path"
                    
                    # Clean up empty parent directories
                    local parent_dir="$(dirname "$repo_path")"
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
                
                # Remove from tracking list
                remove_from_tracking "$tracked_line"
            fi
            
        done < "$TRACKED_ITEMS"
    fi
}

# Helper function to remove a line from tracking list
remove_from_tracking() {
    local line_to_remove="$1"
    
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        return 0
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    # Copy all lines except the one to remove
    while IFS= read -r line; do
        if [[ "$line" != "$line_to_remove" ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$TRACKED_ITEMS"
    
    # Overwrite original file
    cat "$temp_file" > "$TRACKED_ITEMS"
    rm "$temp_file"
    
    log_info "Removed from tracking: $line_to_remove"
    
    # Remove tracking file if empty
    if [[ ! -s "$TRACKED_ITEMS" ]]; then
        rm "$TRACKED_ITEMS"
        log_info "No more tracked files, removed tracking list"
    fi
}

# Command to clean up all ignored files from the repository
cmd_cleanup() {
    if [[ ! -f "$IGNORED_ITEMS" ]]; then
        log_info "No ignore list found - nothing to clean up"
        return 0
    fi
    
    log_info "Cleaning up all ignored files from repository..."
    remove_ignored_from_repo
    log_success "Cleanup completed"
}

# Command to unmanage specific files (like ignore cleanup but for exact matches only)
cmd_unmanage() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log_error "Usage: dotfiler unmanage <file_or_directory>"
        return 1
    fi
    
    # Convert to absolute path
    if [[ "$target" == "~"* ]]; then
        target="${target/#\~/$HOME}"
    elif [[ "$target" != "/"* ]]; then
        target="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
    fi
    
    # Convert to tracking format
    local target_tracked
    if [[ "$target" == "$HOME"* ]]; then
        target_tracked='$HOME'"${target#$HOME}"
    else
        target_tracked="$target"
    fi
    
    # Check if this exact path is being tracked
    if [[ ! -f "$TRACKED_ITEMS" ]]; then
        log_error "No tracked files found"
        return 1
    fi
    
    local is_tracked=false
    while IFS= read -r tracked_line; do
        [[ -z "$tracked_line" ]] && continue
        if [[ "$tracked_line" == "$target_tracked" ]]; then
            is_tracked=true
            break
        fi
    done < "$TRACKED_ITEMS"
    
    if [[ "$is_tracked" != true ]]; then
        log_error "Path '$target' is not being tracked (exact match required)"
        log_info "Currently tracked paths:"
        while IFS= read -r tracked_line; do
            [[ -z "$tracked_line" ]] && continue
            echo "  - $tracked_line"
        done < "$TRACKED_ITEMS"
        return 1
    fi
    
    # Confirm the action
    echo ""
    log_warning "This will stop managing '$target' and restore it as a regular file/directory."
    if ! prompt_user "Continue with unmanaging '$target'?"; then
        log_info "Unmanage operation cancelled"
        return 0
    fi
    
    # Use existing remove logic but simpler since we know exact path
    if [[ -z "$DOTFILESPATH" ]]; then
        log_error "DOTFILESPATH environment variable is not set"
        return 1
    fi
    
    if [[ -z "$OS" ]]; then
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    
    local repo_files_dir="$DOTFILESPATH/$OS/files"
    
    # Determine repo path
    local repo_path
    if [[ "$target_tracked" == '$HOME'* ]]; then
        local rel_path="${target_tracked#\$HOME/}"
        repo_path="$repo_files_dir/HOME/$rel_path"
    else
        local rel_path="${target_tracked#/}"
        repo_path="$repo_files_dir/$rel_path"
    fi
    
    log_info "Unmanaging: $target"
    
    # First, find and restore any symlinked files within this path
    if [[ -d "$target" ]]; then
        log_info "Scanning for symlinked files within directory: $target"
        find "$target" -type l | while read -r symlink; do
            local link_target=$(readlink "$symlink")
            
            # Check if this symlink points to our repo
            if [[ "$link_target" == "$repo_path"* ]]; then
                log_info "Restoring symlinked file: $symlink"
                
                # Determine if we need sudo
                local needs_sudo=false
                if [[ "$symlink" != "$HOME"* ]] && [[ "$symlink" == "/"* ]]; then
                    needs_sudo=true
                fi
                
                # Check if repo file actually exists before trying to restore
                if [[ -e "$link_target" ]]; then
                    # Replace symlink with repo content
                    if [[ "$needs_sudo" == true ]]; then
                        sudo rm "$symlink"
                        sudo cp -r "$link_target" "$symlink"
                    else
                        rm "$symlink"
                        cp -r "$link_target" "$symlink"
                    fi
                    
                    log_success "Restored: $symlink"
                else
                    log_warning "Cannot restore $symlink - repo file missing: $link_target"
                    log_info "Removing broken symlink: $symlink"
                    if [[ "$needs_sudo" == true ]]; then
                        sudo rm "$symlink"
                    else
                        rm "$symlink"
                    fi
                fi
            fi
        done
    fi
    
    # Then handle the main path if it's a symlink
    if [[ -L "$target" ]]; then
        local link_target=$(readlink "$target")
        if [[ "$link_target" == "$repo_path" ]]; then
            log_info "Restoring symlink to hard file/directory: $target"
            
            # Determine if we need sudo
            local needs_sudo=false
            if [[ "$target" != "$HOME"* ]] && [[ "$target" == "/"* ]]; then
                needs_sudo=true
            fi
            
            # Check if repo path exists before trying to restore
            if [[ -e "$repo_path" ]]; then
                # Replace symlink with repo content
                if [[ "$needs_sudo" == true ]]; then
                    sudo rm "$target"
                    sudo cp -r "$repo_path" "$target"
                else
                    rm "$target"
                    cp -r "$repo_path" "$target"
                fi
                
                log_success "Restored: $target"
            else
                log_warning "Cannot restore $target - repo path missing: $repo_path"
                log_info "Removing broken symlink: $target"
                if [[ "$needs_sudo" == true ]]; then
                    sudo rm "$target"
                else
                    rm "$target"
                fi
            fi
        fi
    fi
    
    # Remove from repo
    if [[ -e "$repo_path" ]]; then
        log_info "Removing from repository: $repo_path"
        rm -rf "$repo_path"
        
        # Clean up empty parent directories
        local parent_dir="$(dirname "$repo_path")"
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
    
    # Remove from tracking list
    local temp_file
    temp_file=$(mktemp)
    
    while IFS= read -r line; do
        if [[ "$line" != "$target_tracked" ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$TRACKED_ITEMS"
    
    cat "$temp_file" > "$TRACKED_ITEMS"
    rm "$temp_file"
    
    log_success "Unmanaged: $target_tracked"
    
    # Remove tracking file if empty
    if [[ ! -s "$TRACKED_ITEMS" ]]; then
        rm "$TRACKED_ITEMS"
        log_info "No more tracked files, removed tracking list"
    fi
}

# Remove matching patterns from ignore list when adding files
remove_from_ignore_list() {
    local add_path="$1"
    
    # Don't do anything if ignore list doesn't exist
    if [[ ! -f "$IGNORED_ITEMS" ]]; then
        return 0
    fi
    
    # Convert add path to tracking format for comparison
    local add_path_tracked
    if [[ "$add_path" == "$HOME"* ]]; then
        add_path_tracked='$HOME'"${add_path#$HOME}"
    else
        add_path_tracked="$add_path"
    fi
    
    local temp_file
    temp_file=$(mktemp)
    local removed_count=0
    
    while IFS= read -r ignore_pattern; do
        [[ -z "$ignore_pattern" ]] && continue
        
        local should_remove=false
        
        # Check if the add path matches or contains this ignore pattern
        
        # Direct match
        if [[ "$add_path_tracked" == "$ignore_pattern" ]]; then
            should_remove=true
        fi
        
        # Check if we're adding a parent directory that contains ignored items
        local ignore_abs="${ignore_pattern/#\$HOME/$HOME}"
        if [[ "$ignore_abs" == "$add_path"/* ]]; then
            should_remove=true
        fi
        
        # Check glob patterns
        case "$add_path_tracked" in
            $ignore_pattern) should_remove=true ;;
        esac
        
        case "$add_path" in
            $ignore_pattern) should_remove=true ;;
        esac
        
        if [[ "$should_remove" == true ]]; then
            log_info "Removing conflicting ignore pattern: $ignore_pattern"
            removed_count=$((removed_count + 1))
        else
            echo "$ignore_pattern" >> "$temp_file"
        fi
    done < "$IGNORED_ITEMS"
    
    if [[ $removed_count -gt 0 ]]; then
        # Overwrite original ignore list
        cat "$temp_file" > "$IGNORED_ITEMS"
        log_success "Removed $removed_count conflicting patterns from ignore list"
        
        # Remove ignore file if empty
        if [[ ! -s "$IGNORED_ITEMS" ]]; then
            rm "$IGNORED_ITEMS"
            log_info "No more ignore patterns, removed ignore list"
        fi
    fi
    
    rm "$temp_file"
}

# Cleanup ignored files that are currently managed (symlinked or in repo)
# This implements Option A: complete un-management
cleanup_ignored_files() {
    if [[ ! -f "$IGNORED_ITEMS" ]] || [[ ! -f "$TRACKED_ITEMS" ]]; then
        return 0
    fi
    
    if [[ -z "$DOTFILESPATH" ]]; then
        log_error "DOTFILESPATH environment variable is not set"
        return 1
    fi
    
    if [[ -z "$OS" ]]; then
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    
    local repo_files_dir="$DOTFILESPATH/$OS/files"
    
    # Track patterns and paths to remove from tracking
    local temp_tracking_file
    temp_tracking_file=$(mktemp)
    
    log_info "Cleaning up ignored files from management..."
    
    # First, scan all files and directories in the repository and remove ignored ones
    if [[ -d "$repo_files_dir" ]]; then
        # Process files and directories, but handle directories after files
        find "$repo_files_dir" -depth \( -type f -o -type d \) | while read -r repo_item; do
            # Skip the root files directory itself
            [[ "$repo_item" == "$repo_files_dir" ]] && continue
            # Convert repo path back to original path
            local relative_path="${repo_item#$repo_files_dir/}"
            local original_path
            
            if [[ "$relative_path" == HOME/* ]]; then
                # It's a HOME file/directory
                original_path="$HOME/${relative_path#HOME/}"
            else
                # It's a system file/directory
                original_path="/$relative_path"
            fi
            
            # Check if this item should be ignored
            if should_ignore "$original_path"; then
                if [[ -f "$repo_item" ]]; then
                    log_info "Found ignored file in repo: $repo_item (original: $original_path)"
                    
                    # If the original file is symlinked to our repo, restore it
                    if [[ -L "$original_path" ]]; then
                        local link_target=$(readlink "$original_path")
                        if [[ "$link_target" == "$repo_item" ]]; then
                            log_info "Restoring symlink to hard file: $original_path"
                            
                            # Determine if we need sudo
                            local needs_sudo=false
                            if [[ "$original_path" != "$HOME"* ]] && [[ "$original_path" == "/"* ]]; then
                                needs_sudo=true
                            fi
                            
                            # Replace symlink with repo content
                            if [[ "$needs_sudo" == true ]]; then
                                sudo rm "$original_path"
                                sudo cp -r "$repo_item" "$original_path"
                            else
                                rm "$original_path"
                                cp -r "$repo_item" "$original_path"
                            fi
                            
                            log_success "Restored: $original_path"
                        fi
                    fi
                    
                    # Remove file from repo
                    log_info "Removing ignored file from repository: $repo_item"
                    rm -f "$repo_item"
                    
                elif [[ -d "$repo_item" ]]; then
                    log_info "Found ignored directory in repo: $repo_item (original: $original_path)"
                    
                    # If the original directory is symlinked to our repo, restore it
                    if [[ -L "$original_path" ]]; then
                        local link_target=$(readlink "$original_path")
                        if [[ "$link_target" == "$repo_item" ]]; then
                            log_info "Restoring symlinked directory to hard directory: $original_path"
                            
                            # Determine if we need sudo
                            local needs_sudo=false
                            if [[ "$original_path" != "$HOME"* ]] && [[ "$original_path" == "/"* ]]; then
                                needs_sudo=true
                            fi
                            
                            # Replace symlink with repo content
                            if [[ "$needs_sudo" == true ]]; then
                                sudo rm "$original_path"
                                sudo cp -r "$repo_item" "$original_path"
                            else
                                rm "$original_path"
                                cp -r "$repo_item" "$original_path"
                            fi
                            
                            log_success "Restored directory: $original_path"
                        fi
                    fi
                    
                    # Remove directory from repo (find -depth ensures children are processed first)
                    if [[ -z "$(ls -A "$repo_item" 2>/dev/null)" ]]; then
                        log_info "Removing ignored empty directory from repository: $repo_item"
                        rmdir "$repo_item" 2>/dev/null
                    fi
                fi
            fi
        done
        
        # Clean up empty directories after all file removals
        log_info "Cleaning up empty directories..."
        find "$repo_files_dir" -type d -empty | sort -r | while read -r empty_dir; do
            if [[ "$empty_dir" != "$repo_files_dir" ]]; then
                rmdir "$empty_dir" 2>/dev/null && log_info "Removed empty directory: $empty_dir"
            fi
        done
    fi
    
    # Then, clean up tracking list of any patterns that would be completely ignored
    while IFS= read -r tracked_line; do
        [[ -z "$tracked_line" ]] && continue
        
        # Expand $HOME in tracked path to get actual path
        local actual_path="${tracked_line/#\$HOME/$HOME}"
        
        # Check if this tracked item itself should be ignored (not just files within it)
        if should_ignore "$actual_path"; then
            log_info "Removing completely ignored tracked item from tracking: $tracked_line"
        else
            # Keep this in tracking list
            echo "$tracked_line" >> "$temp_tracking_file"
        fi
        
    done < "$TRACKED_ITEMS"
    
    # Update tracking list
    cat "$temp_tracking_file" > "$TRACKED_ITEMS"
    rm "$temp_tracking_file"
    
    # Remove tracking file if empty
    if [[ ! -s "$TRACKED_ITEMS" ]]; then
        rm "$TRACKED_ITEMS"
        log_info "No more tracked files, removed tracking list"
    fi
}