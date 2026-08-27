#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output_dir="$script_dir/generated"

rm -rf "$output_dir"
mkdir -p "$output_dir"

python3 -m intersystems_pyprod._parser \
    --manual \
    -o "$output_dir" \
    "$script_dir/production.py"

for file in "$output_dir"/*.cls; do
    temporary_file="$file.tmp"
    {
        printf 'Include %%occStatus\n\n'
        cat "$file"
    } > "$temporary_file"
    mv "$temporary_file" "$file"
done