#!/usr/bin/env bash

# Creates a new partition after a selected partition
# Usage: adpext4 /dev/nvme0n1p1 30G "label"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <dev-path> <size> <label>"
    exit 1
fi

EXISTING="$1"
SIZE="$2"
LABEL="$3"

if [ ! -b "$EXISTING" ]; then
    echo "ERROR: $EXISTING is not a block device."
    exit 1
fi

DISK=/dev/$(lsblk -no PKNAME "$EXISTING")
PARTNUM=$(lsblk -no PARTNUM "$EXISTING")

END_BYTES=$(lsblk -bno END "$EXISTING")
END_MB=$(( END_BYTES / 1024 / 1024 ))

# Start the new partition just past the end of the existing one to avoid overlap
START_PT="$(( END_MB + 1 ))MiB"
SIZE_PT="$SIZE"

echo "Creating new partition on $DISK at $START_PT size $SIZE_PT with label $LABEL"

# Let parted handle all safety checks
parted -s "$DISK" mkpart primary ext4 "$START_PT" "$SIZE_PT" || {
    echo "ERROR: parted refused to create the partition."
    exit 1
}

# Ensure kernel/udev sees the new partition before proceeding
partprobe "$DISK"
udevadm settle

NEWNUM=$(lsblk -no PARTNUM "${DISK}"* | sort -n | tail -1)
NEWPART="${DISK}p${NEWNUM}"
[ -e "$NEWPART" ] || NEWPART="${DISK}${NEWNUM}"

sgdisk --change-name=${NEWNUM}:"${LABEL}" "$DISK"
mkfs.ext4 -L "$LABEL" "$NEWPART"

echo "Done:"
lsblk -o NAME,PATH,SIZE,TYPE,PARTLABEL,FSTYPE | grep "$NEWPART"
