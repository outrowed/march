#!/usr/bin/bash

# Format EFI System Partition (ESP)
# Usage: format-esp.sh /dev/nvme0n1p1

set -e

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <esp-partition>"
    exit 1
fi

ESP="$1"

# Validate block device
if [[ ! -b "$ESP" ]]; then
    echo "ERROR: $ESP is not a valid block device."
    exit 1
fi

# Verify the partition really is an ESP (type GUID)
PTYPE=$(lsblk -nro PARTTYPE "$ESP" | tr 'A-Z' 'a-z')

if [[ "$PTYPE" != "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]]; then
    echo "WARNING: $ESP does not have the EFI System Partition GUID."
    echo "Proceed anyway? (y/N)"
    read -r ans
    [[ "$ans" != "y" ]] && exit 1
fi

echo "Formatting $ESP as FAT32 (ESP)..."
sudo mkfs.fat -F 32 -n ESP "$ESP"

echo "Done."
lsblk -o NAME,PATH,FSTYPE,LABEL,PARTTYPE "$ESP"