#!/usr/bin/bash
# Copy a file to *.bak (or *.RANDOM.bak if it already exists).

set -euo pipefail

main() {
    local target="$1"

    if [[ -f "$target" ]]; then
        if [[ -f "$target".bak ]]; then
            cp "$target" "$target".$RANDOM.bak
        else
            cp "$target" "$target".bak
        fi
    fi
}

main "$@"
