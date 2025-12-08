#!/usr/bin/bash
# Unattend Arch by Outrowed

set -euo pipefail

## Cleanup /mnt/boot

if [[ ! -d /mnt/boot ]]; then
    echo "/mnt/boot does not exist; nothing to clean."
    exit 0
fi

if ! mountpoint -q /mnt/boot 2>/dev/null; then
    echo "/mnt/boot is not a mountpoint; refusing to remove files."
    exit 1
fi

echo "Deleting all files in /mnt/boot..."

rm -rf /mnt/boot/*

echo "Completed cleaning /mnt/boot."
