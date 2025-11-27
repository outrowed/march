#!/usr/bin/bash

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

## Configure systemd-boot bootloader

derive_efi_device "$IEFI_PARTITION" IEFI_DEVICE IEFI_PARTITION_INDEX

# Install systemd-boot to the ESP mount point
arch-chroot /mnt bootctl --esp-path=/efi install

# Create EFI boot entry
if ! efibootmgr | grep -q "${ISYSTEMD_BOOT_EFI_LABEL}$"; then
    efibootmgr --create --disk $IEFI_DEVICE --part $IEFI_PARTITION_INDEX --label "$ISYSTEMD_BOOT_EFI_LABEL" --loader /EFI/systemd/systemd-bootx64.efi
fi

# Create the main loader config
cat <<EOF > /mnt/efi/loader/loader.conf
default  arch.conf
timeout  5
console-mode max
editor no
EOF

# Create the Arch Linux boot entry

# Get the UUID for the root partition (/) from your fstab
ROOT_UUID="$(root-uuid)"

# Write the boot entry file

mkdir -p /mnt/efi/loader/entries

cat <<EOF > /mnt/efi/loader/entries/arch.conf
title   $ISYSTEMD_BOOT_ARCH_LABEL
linux   /EFI/$IEFI_LINUX_DIRNAME/vmlinuz-linux
initrd  /EFI/$IEFI_LINUX_DIRNAME/intel-ucode.img
initrd  /EFI/$IEFI_LINUX_DIRNAME/amd-ucode.img
initrd  /EFI/$IEFI_LINUX_DIRNAME/initramfs-linux.img
options $1
EOF

# Update systemd-boot
arch-chroot /mnt bootctl --esp-path=/efi update
