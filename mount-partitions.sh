#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

echo "Mounting partitions..."

# Mount partitions

# Mount with noatime to disable "last access" writes (Recommended for SSDs)
mount --mkdir -o noatime /dev/disk/by-partlabel/"$IROOT_PARTITION_LABEL" /mnt
mount --mkdir -o noatime,nofail /dev/disk/by-partlabel/"$IHOME_PARTITION_LABEL" /mnt/home

# EFI partitions don't support POSIX atime, but defaults are fine.

mount --mkdir "$IEFI_DEVICE_FULL" /mnt/efi

mkdir -p /mnt/efi/EFI/"$IEFI_LINUX_DIRNAME"

mount --mkdir --bind /mnt/efi/EFI/"$IEFI_LINUX_DIRNAME" /mnt/boot
