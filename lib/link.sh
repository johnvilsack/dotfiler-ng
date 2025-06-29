#!/usr/bin/env bash
# link.sh - Link dotfiles to their destinations

cmd_link() {
    log_info "Linking config files"
    
    local dotfiles_base="$DOTFILESPATH/mac/files"
    
    if [[ ! -d "$dotfiles_base" ]]; then
        log_error "Dotfiles directory not found: $dotfiles_base"
        exit 1
    fi
    
    # Find all subdirectories in the files directory
    find "$dotfiles_base" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        dir_name=$(basename "$dir")
        
        # Determine target base directory and if we need sudo
        local needs_sudo=false
        if [[ "$dir_name" == "HOME" ]]; then
            target_base="$HOME"
        else
            target_base="/$dir_name"
            needs_sudo=true
        fi
        
        # Find all files in this directory recursively
        find "$dir" -type f -not -name ".DS_Store" | while read -r file; do
            relative_path="${file#$dir/}"
            target="$target_base/$relative_path"
            
            # Create parent directory if it doesn't exist
            target_dir="$(dirname "$target")"
            if [[ ! -d "$target_dir" ]]; then
                if [[ "$needs_sudo" == true ]]; then
                    log_info "Creating directory with sudo: $target_dir"
                    sudo mkdir -p "$target_dir"
                else
                    log_info "Creating directory: $target_dir"
                    mkdir -p "$target_dir"
                fi
            fi
            
            # Handle symlink creation
            if [[ -L "$target" ]]; then
                current_link=$(readlink "$target")
                if [[ "$current_link" == "$file" ]]; then
                    continue
                else
                    log_info "Updating: $target"
                    if [[ "$needs_sudo" == true ]]; then
                        sudo ln -sf "$file" "$target"
                    else
                        ln -sf "$file" "$target"
                    fi
                fi
            elif [[ -e "$target" ]]; then
                log_warning "Overwriting: $target"
                if [[ "$needs_sudo" == true ]]; then
                    sudo ln -sf "$file" "$target"
                else
                    ln -sf "$file" "$target"
                fi
            else
                log_info "Linking: $target"
                if [[ "$needs_sudo" == true ]]; then
                    sudo ln -sf "$file" "$target"
                else
                    ln -sf "$file" "$target"
                fi
            fi
        done
    done
    
    log_success "Dotfiles linking complete!"
}

cmd_status() {
    log_info "Checking dotfiles status"
    
    local dotfiles_base="$DOTFILESPATH/mac/files"
    local total_files=0
    local linked_files=0
    local broken_links=0
    
    find "$dotfiles_base" -type f -not -name ".DS_Store" | while read -r file; do
        ((total_files++))
        
        # Determine what the target should be
        if [[ "$file" == *"/HOME/"* ]]; then
            relative_path="${file#$dotfiles_base/HOME/}"
            target="$HOME/$relative_path"
        else
            relative_path="${file#$dotfiles_base/}"
            target="/$relative_path"
        fi
        
        if [[ -L "$target" ]]; then
            current_link=$(readlink "$target")
            if [[ "$current_link" == "$file" ]]; then
                ((linked_files++))
                echo "✅ $target"
            else
                ((broken_links++))
                echo "❌ $target (points to $current_link)"
            fi
        else
            echo "⚠️  $target (not linked)"
        fi
    done
    
    echo ""
    log_info "Status: $linked_files/$total_files files linked"
    if [[ $broken_links -gt 0 ]]; then
        log_warning "$broken_links broken links found"
    fi
}