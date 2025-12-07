#!/usr/bin/bash

# Detect EFI System Partition (ESP) on a given disk
# Usage: detect-esp.sh /dev/nvme0n1

set -e

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <disk-path>"
    exit 1
fi

DISK="$1"

# Validate disk
if [[ ! -b "$DISK" ]]; then
    echo "ERROR: $DISK is not a valid block device."
    exit 1
fi

# Find partitions belonging to this disk
# and check which one has the ESP GUID type (c12a7328-f81f-11d2-ba4b-00a0c93ec93b)
ESP=$(lsblk -rno NAME,TYPE,PARTTYPE "$DISK" \
    | awk '$2=="part" && tolower($3)=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b" {print $1}')

if [[ -z "$ESP" ]]; then
    echo "No ESP found on $DISK."
    exit 1
fi

echo "/dev/$ESP"