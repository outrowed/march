#!/usr/bin/bash
set -euo pipefail

MARCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$MARCH_ROOT/common.sh"

TARGET_ROOT="${1:-/}"

if [[ ! -d "$TARGET_ROOT" ]]; then
    echo "Target root '$TARGET_ROOT' does not exist."
    exit 1
fi

POST_INSTALL_SCRIPTS=(
    march-post-install-config.sh
    march-post-install-packages.sh
)

ran_any=0

for script in "${POST_INSTALL_SCRIPTS[@]}"; do
    script_path="$TARGET_ROOT/usr/local/sbin/$script"

    if [[ -x "$script_path" ]]; then
        echo "Running $script inside $TARGET_ROOT..."
        arch-chroot "$TARGET_ROOT" "/usr/local/sbin/$script"
        ran_any=1
    else
        echo "Skipping $script; not found in $TARGET_ROOT."
    fi
done

if [[ "$ran_any" -eq 0 ]]; then
    echo "No post-install scripts were executed."
    exit 1
fi
