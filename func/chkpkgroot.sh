#!/usr/bin/bash
# Package presence checks within a given root.

set -euo pipefail

main() {
    local root="$1"
    shift || true

    if [[ -z "$root" ]]; then
        echo "chkpkgroot: root path is required"
        return 1
    fi

    local checker=()

    # Prefer paru inside the target root for AUR awareness; fall back to pacman.
    if [[ -x "$root/usr/bin/paru" || -x "$root/bin/paru" ]]; then
        checker=(arch-chroot "$root" paru -Q)
    else
        checker=(pacman --root "$root" -Q)
    fi

    local pkg
    for pkg in "$@"; do
        "${checker[@]}" "$pkg" &>/dev/null || return 1
    done

    return 0
}

main "$@"
