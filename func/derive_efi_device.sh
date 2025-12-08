#!/usr/bin/bash
# Derive EFI device and partition index from a partition path.

set -euo pipefail

main() {
    local partition="$1"
    local device_var="$2"
    local part_var="$3"

    if [[ -z "$partition" ]]; then
        echo "ERROR: undefined EFI device variable \$partition: '$partition'"
        exit 1
    fi

    local parent part_index

    parent="$(lsblk -no PKNAME "$partition" 2>/dev/null | head -n1)"
    part_index="$(lsblk -no PARTN "$partition" 2>/dev/null | head -n1)"

    if [[ -z "$partition" || -z "$parent" || -z "$part_index" ]]; then
        echo "Unable to derive EFI device from '$partition'. Expected e.g. /dev/nvme0n1p1 or /dev/sda1."
        exit 1
    fi

    printf -v "$device_var" '/dev/%s' "$parent"
    printf -v "$part_var" '%s' "$part_index"
}

main "$@"
