#!/bin/bash
set -euo pipefail

output_file="OUTPUT.sh"
input_files=("common.sh" "add.sh" "remove.sh" "build.sh" "list.sh" "newsync.sh" "sync.sh" "../dotfiler")
# Clear output file
> "$output_file"

# Concatenate input files
for file in "${input_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: $file not found" >&2
        exit 1
    fi
    cat "$file" >> "$output_file"
    echo "# ***** $file *****" >> "$output_file"  # Add blank line between files
done

chmod +x "$output_file"
echo "Created $output_file from ${input_files[*]}"