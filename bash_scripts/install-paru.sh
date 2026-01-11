#!/usr/bin/bash

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

BUILD_DIR="/tmp/$IAUR_HELPER-build"
AUR_REPO="https://aur.archlinux.org/$IAUR_HELPER.git"
BUILD_DEPS=()

case "$IAUR_HELPER" in
    paru)
        BUILD_DEPS=(rust)
        ;;
    yay)
        BUILD_DEPS=(go)
        ;;
    *)
        echo "Unsupported IAUR_HELPER '$IAUR_HELPER' (expected paru or yay)."
        exit 1
        ;;
esac

# Install AUR helper build dependencies into the new system
if ((${#BUILD_DEPS[@]})); then
    retry arch-chroot /mnt pacman -S --noconfirm --needed "${BUILD_DEPS[@]}"
fi

# Run the build process as the super user, not as root
# We use 'sudo -u' for this.
autosudo "$ISUPER_USER" /mnt retry arch-chroot /mnt sudo -u "$1" bash -c "
    cd /tmp
    git clone \"$AUR_REPO\" \"$BUILD_DIR\"
    cd \"$BUILD_DIR\"
    makepkg -si --noconfirm
"

# Clean up the build directory
arch-chroot /mnt rm -rf "$BUILD_DIR"
