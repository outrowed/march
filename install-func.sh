#!/usr/bin/bash

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

install-paru() {
    # 1. Install paru's build dependencies (Rust) into the new system
    arch-chroot /mnt pacman -S --noconfirm --needed rust

    # 2. Run the build process *as the new user*, not as root
    # We use 'sudo -u' for this.
    arch-chroot /mnt sudo -u "$ISUPER_USER" bash -c "
        cd /tmp
        git clone https://aur.archlinux.org/paru.git /tmp/paru-build
        cd /tmp/paru-build
        makepkg -si --noconfirm
    "
    
    # 3. Clean up the build directory
    arch-chroot /mnt rm -rf /tmp/paru-build
}