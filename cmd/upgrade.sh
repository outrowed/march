#!/usr/bin/bash
set -euo pipefail

MARCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$MARCH_ROOT/common.sh"

TARGET_ROOT="${1:-/mnt}"

if [[ ! -d "$TARGET_ROOT" ]]; then
    echo "Target root '$TARGET_ROOT' does not exist."
    exit 1
fi

echo "Upgrading system in $TARGET_ROOT..."
retry arch-chroot "$TARGET_ROOT" pacman -Syu
