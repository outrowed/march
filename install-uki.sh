#!/usr/bin/bash

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

PRESET_FILE=/mnt/etc/mkinitcpio.d/linux.preset

mkdir -p /mnt/etc/kernel

if [[ ! -f "$PRESET_FILE" ]]; then
    echo "mkinitcpio preset not found at $PRESET_FILE"
    exit 1
fi

bakup "$PRESET_FILE"

DEFAULT_IMAGE="/efi/EFI/$IEFI_LINUX_DIRNAME/initramfs-linux.img"
FALLBACK_IMAGE="/efi/EFI/$IEFI_LINUX_DIRNAME/initramfs-linux-fallback.img"

uki_ext="${IUKI_EXEC##*.}"
if [[ "$uki_ext" == "$IUKI_EXEC" ]]; then
    fallback_exec="${IUKI_EXEC}-fallback"
else
    fallback_exec="${IUKI_EXEC%.$uki_ext}-fallback.$uki_ext"
fi

DEFAULT_UKI="/efi/EFI/$IEFI_LINUX_DIRNAME/$IUKI_EXEC"
FALLBACK_UKI="/efi/EFI/$IEFI_LINUX_DIRNAME/$fallback_exec"

sed -i "s|^#\?default_image=.*|default_image=\"$DEFAULT_IMAGE\"|" "$PRESET_FILE"
sed -i "s|^#\?default_uki=.*|default_uki=\"$DEFAULT_UKI\"|" "$PRESET_FILE"
sed -i "s|^#\?fallback_image=.*|fallback_image=\"$FALLBACK_IMAGE\"|" "$PRESET_FILE"
sed -i "s|^#\?fallback_uki=.*|fallback_uki=\"$FALLBACK_UKI\"|" "$PRESET_FILE"

KERNEL_CMDLINE="$1"
echo "$KERNEL_CMDLINE" > /mnt/etc/kernel/cmdline

derive_efi_device "$IEFI_PARTITION" IEFI_DEVICE IEFI_PARTITION_INDEX

EFI_LOADER="\\EFI\\$IEFI_LINUX_DIRNAME\\$IUKI_EXEC"
if ! efibootmgr | grep -q "${IUKI_LABEL}$"; then
    efibootmgr --create --disk "$IEFI_DEVICE" --part "$IEFI_PARTITION_INDEX" --label "$IUKI_LABEL" --loader "$EFI_LOADER"
fi

if prompt "Install pacman hook to keep $IUKI_LABEL EFI entry present?"; then
    mkdir -p /mnt/etc/pacman.d/hooks
    cat <<EOF > /mnt/etc/pacman.d/hooks/90-uki-efibootmgr.hook
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = linux

[Action]
Description = Ensure UEFI entry for Arch UKI exists
When = PostTransaction
Exec = /usr/bin/bash -c 'efibootmgr -v | grep -q "$IUKI_LABEL" || efibootmgr --create --disk $IEFI_DEVICE --part $IEFI_PARTITION_INDEX --label "$IUKI_LABEL" --loader "\\EFI\\$IEFI_LINUX_DIRNAME\\$IUKI_EXEC"'
EOF
fi

arch-chroot /mnt mkinitcpio -P
