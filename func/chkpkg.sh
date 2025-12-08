#!/usr/bin/bash
# Package presence checks on the host.

set -euo pipefail

main() {
    local checker=()

    if command -v paru &>/dev/null; then
        checker=(paru -Q)
    else
        checker=(pacman -Q)
    fi

    local pkg
    for pkg in "$@"; do
        "${checker[@]}" "$pkg" &>/dev/null || return 1
    done

    return 0
}

main "$@"
