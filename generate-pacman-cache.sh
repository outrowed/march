#!/usr/bin/bash

# Download Arch repo packages into a local cache for the installer.
# Usage: sudo ./generate-pacman-cache.sh [cache_dir]
# Default cache_dir: ./cache/pacman

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPTDIR/packages.sh"

CACHE_DIR="${1:-$SCRIPTDIR/cache/pacman}"
mkdir -p "$CACHE_DIR"

# Collect only repo packages; AUR packages are skipped intentionally.
all_pkgs=(
    "${IPACSTRAP_PACKAGES[@]}"
    "${IPREPACMAN_PACKAGES[@]}"
    "${IPACMAN_PACKAGES[@]}"
    "${ILATE_PACKAGES[@]}"
)

declare -A seen
pkgs=()
for pkg in "${all_pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue
    if [[ -z "${seen[$pkg]:-}" ]]; then
        pkgs+=("$pkg")
        seen["$pkg"]=1
    fi
done

echo "Using cache dir: $CACHE_DIR"
echo "Packages to fetch: ${#pkgs[@]}"

pacman -Sy --noconfirm
pacman -Sw --noconfirm --needed --cachedir "$CACHE_DIR" "${pkgs[@]}"

echo "Done. Cache is ready in $CACHE_DIR"
