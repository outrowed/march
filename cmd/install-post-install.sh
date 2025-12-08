#!/usr/bin/bash
set -euo pipefail

MARCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET_ROOT="${1:-/mnt}"

if [[ "$TARGET_ROOT" != "/mnt" ]]; then
    echo "Warning: install-post-install currently targets /mnt; ignoring '$TARGET_ROOT'."
fi

exec "$MARCH_ROOT/cmd/install-post-install-setup.sh" "$@"
