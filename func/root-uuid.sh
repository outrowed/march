#!/usr/bin/bash
# Determine the root filesystem UUID from the installed system fstab or label.

set -euo pipefail

main() {
    local root_uuid

    root_uuid=$(grep -E '\s/\s' /mnt/etc/fstab | awk '{print $1}' | sed 's/^UUID=//' | head -n1 || true)

    if [[ -z "$root_uuid" ]]; then
        root_uuid=$(blkid -s UUID -o value "/dev/disk/by-partlabel/$IROOT_PARTITION_LABEL" || true)
    fi

    if [[ -z "$root_uuid" ]]; then
        echo "Unable to determine root UUID for kernel cmdline."
        exit 1
    fi

    echo "$root_uuid"
}

main "$@"
