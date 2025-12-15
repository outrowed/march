#!/usr/bin/bash

. "$(dirname ${BASH_SOURCE[0]})"/common.sh

# Install yay's build dependencies (requires Go)
retry arch-chroot /mnt pacman -S --noconfirm --needed go

# Run the build process as the super user, not as root
# We use 'sudo -u' for this.
autosudo "$ISUPER_USER" /mnt retry arch-chroot /mnt sudo -u "$1" bash -c "
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-build
    cd /tmp/yay-build
    makepkg -si --noconfirm
"

# Clean up the build directory
arch-chroot /mnt rm -rf /tmp/yay-build

# Provide compatibility alias: use yay but keep 'paru' command working
arch-chroot /mnt ln -sf /usr/bin/yay /usr/bin/paru
