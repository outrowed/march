#!/usr/bin/bash

# Sets a new partition label
# Usage: set-partlabel /dev/nvme0n1p1 "a-new-label"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <dev-path> <new-label>"
    exit 1
fi

PART="$1"
NEWLABEL="$2"

# Validate block device
if [ ! -b "$PART" ]; then
    echo "ERROR: $PART is not a valid block device."
    exit 1
fi

# Extract base name (e.g., nvme0n1p1)
BASENAME=$(basename "$PART")

# Determine the parent disk
DISK=$(lsblk -no PKNAME "$PART")
DISK="/dev/$DISK"

# Get partition number reliably via sysfs
SYS_PART="/sys/class/block/$BASENAME/partition"

if [[ ! -f "$SYS_PART" ]]; then
    echo "Error: Could not determine partition index."
    exit 1
fi

PARTNUM=$(cat "$SYS_PART")

echo "Detected disk: $DISK"
echo "Partition index: $PARTNUM"
echo "Applying GPT PARTLABEL \"$NEWLABEL\" to $PART"

sudo sgdisk --change-name=${PARTNUM}:"${NEWLABEL}" "$DISK"

echo "Done."
lsblk -o NAME,PATH,PARTLABEL,PARTUUID "$PART"