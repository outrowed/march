#!/usr/bin/bash

# todo: modify linux.preset to uncomment *_uki and *_image with IUKI_EXEC (as .efi exec) and IEFI_LINUX_DIRNAME (as directory name)

# todo: write /etc/kernel/cmdline

# todo: efibootmgr with IUKI_LABEL as the EFI name

# todo: optional pacman hook for auto-generating EFI entry as pacman hook: 90-uki-efibootmgr.hook

: <<EFIBOOTMGR_HOOK
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = linux

[Action]
Description = Ensure UEFI entry for Arch UKI exists
When = PostTransaction
Exec = /usr/bin/bash -c 'efibootmgr -v | grep -q "arch-linux.efi" || efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Arch Linux (UKI)" --loader "\EFI\Linux\arch-linux.efi"'
EFIBOOTMGR_HOOK

mkinitcpio -P