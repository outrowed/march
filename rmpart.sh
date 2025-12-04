#!/usr/bin/env bash

# Usage: rmpart /dev/nvme0n1p2

if [ $# -ne 1 ]; then
    echo "Usage: $0 <dev-path>"
    exit 1
fi

PART="$1"

if [ ! -b "$PART" ]; then
    echo "ERROR: $PART is not a valid block device."
    exit 1
fi

# Extract disk and index
DISK=/dev/$(lsblk -no PKNAME "$PART")
PARTNUM=$(lsblk -no PARTNUM "$PART")

if [ -z "$PARTNUM" ]; then
    echo "ERROR: Cannot determine partition number."
    exit 1
fi

# Get partition details
PARTLABEL=$(lsblk -no PARTLABEL "$PART")
FSTYPE=$(lsblk -no FSTYPE "$PART")

echo "Target partition: $PART"
echo "Partition number: $PARTNUM"
echo "Disk:             $DISK"
echo "Label:            ${PARTLABEL:-none}"
echo "Filesystem:       ${FSTYPE:-none}"

# ❗ SAFEGUARD AGAINST REMOVING EFI SYSTEM PARTITION
if [[ "$FSTYPE" == "vfat" || "$FSTYPE" == "fat32" ]] && \
   [[ "$PARTLABEL" =~ ^(EFI|ESP|EFI_SYSTEM|EFI-SYSTEM|EFI-BOOT|BOOT|EFI)$ ]]; then
    echo ""
    echo "   SAFETY WARNING: This looks like the EFI System Partition."
    echo "   Partition will NOT be removed to prevent boot failure."
    echo "   Refusing operation."
    exit 1
fi

# Optional check for boot flag in lsblk flags
FLAGS=$(lsblk -no PARTFLAGS "$PART")
if [[ "$FLAGS" == *boot* ]]; then
    echo ""
    echo "   SAFETY WARNING: This partition has boot flags."
    echo "   Partition will NOT be removed."
    echo "   Refusing operation."
    exit 1
fi

echo ""
read -p "Are you sure you want to remove this partition? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo "Removing partition #$PARTNUM from $DISK ..."

umount -R "$PART" || {
    echo "Unable to unmount partition $PART"
    echo "Aborting."
    exit 1
}

sgdisk --delete="$PARTNUM" "$DISK"

echo "DONE."
lsblk -o NAME,PATH,SIZE,TYPE,PARTLABEL,FSTYPE
