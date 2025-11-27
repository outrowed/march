#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

echo "Mounting partitions..."

## Mount partitions

# Mount with noatime to disable "last access" writes (Recommended for SSDs)

if ! mountpoint -q /mnt 2>/dev/null; then
    mount --mkdir -o noatime /dev/disk/by-partlabel/"$IROOT_PARTITION_LABEL" /mnt
else
    echo "/mnt already mounted; skipping root mount."
fi

if ! mountpoint -q /mnt/home 2>/dev/null; then
    mount --mkdir -o noatime,nofail /dev/disk/by-partlabel/"$IHOME_PARTITION_LABEL" /mnt/home
else
    echo "/mnt/home already mounted; skipping home mount."
fi

# EFI partitions don't support POSIX atime, but defaults are fine.

if ! mountpoint -q /mnt/efi 2>/dev/null; then
    mount --mkdir "$IEFI_PARTITION" /mnt/efi
else
    echo "/mnt/efi already mounted; skipping EFI mount."
fi

mkdir -p /mnt/efi/EFI/"$IEFI_LINUX_DIRNAME"

if ! mountpoint -q /mnt/boot 2>/dev/null; then
    mount --mkdir --bind /mnt/efi/EFI/"$IEFI_LINUX_DIRNAME" /mnt/boot
else
    echo "/mnt/boot already mounted; skipping boot bind mount."
fi
