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

# Use lsblk to extract disk and partition number
DISK=$(lsblk -no PKNAME "$PART")
PARTNUM=$(lsblk -no PARTNUM "$PART")

if [ -z "$DISK" ] || [ -z "$PARTNUM" ]; then
    echo "Error: Could not determine disk or partition number from lsblk."
    exit 1
fi

DISK="/dev/$DISK"

echo "Detected disk: $DISK"
echo "Partition index: $PARTNUM"
echo "Applying GPT PARTLABEL \"$NEWLABEL\" to $PART"
sudo sgdisk --change-name=${PARTNUM}:"${NEWLABEL}" "$DISK"

echo "Done."
lsblk -o NAME,PATH,PARTLABEL,PARTUUID "$PART"
