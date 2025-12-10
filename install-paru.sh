#!/usr/bin/bash

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
ROOT="${MARCH_ROOT:-/mnt}"

run_in_root() {
    if [[ "$ROOT" == "/" ]]; then
        "$@"
    else
        arch-chroot "$ROOT" "$@"
    fi
}

# Install paru's build dependencies (Rust) into the new system
retry run_in_root pacman -S --noconfirm --needed rust

# Run the build process as the super user, not as root
# We use 'sudo -u' for this.
autosudo "$ISUPER_USER" "$ROOT" retry run_in_root sudo -u "$1" bash -c "
    cd /tmp
    git clone https://aur.archlinux.org/paru.git /tmp/paru-build
    cd /tmp/paru-build
    makepkg -si --noconfirm
"

# Clean up the build directory
run_in_root rm -rf /tmp/paru-build
