#!/usr/bin/bash

. "$(dirname ${BASH_SOURCE[0]})"/common.sh

# Install paru's build dependencies (Rust) into the new system
retry arch-chroot /mnt pacman -S --noconfirm --needed rust

# Run the build process as the super user, not as root
# We use 'sudo -u' for this.
retry arch-chroot /mnt sudo -u "$1" bash -c "
    cd /tmp
    git clone https://aur.archlinux.org/paru.git /tmp/paru-build
    cd /tmp/paru-build
    makepkg -si --noconfirm
"

# Clean up the build directory
arch-chroot /mnt rm -rf /tmp/paru-build
