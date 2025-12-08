#!/usr/bin/bash
# Unattend Arch by Outrowed

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR/march-common.sh"
. "$SCRIPT_DIR/march-config.sh"
. "$SCRIPT_DIR/march-flatpak-packages.sh"
. "$SCRIPT_DIR/march-packages.sh"

echo "Starting post-installation configuration..."

## Wait for network online to archlinux.org

echo "Waiting for DNS..."

until ping -c1 archlinux.org &>/dev/null; do
    sleep 1
done

echo "DNS OK."

## Late AUR / Pacman packages installation

echo "Installing late AUR / Pacman packages..."

autosudo "$ISUPER_USER" / paru -Syu --needed --noconfirm \
    "${ILATE_PACKAGES[@]}" &

## Flatpak setup

if chkpkg flatpak; then
    echo "Installing Flatpak packages..."

    flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo

    if ((${#IFLATPAK_SYSTEM_PACKAGES[@]})); then
        # Install them (non-interactively)
        autosudo "$ISUPER_USER" / flatpak install --system flathub "${IFLATPAK_SYSTEM_PACKAGES[@]}" -y &
    else
        echo "No system-wide Flatpak packages defined."
    fi

    if ((${#IFLATPAK_USER_PACKAGES[@]})); then
        sudo -u "$ISUPER_USER" flatpak install --user flathub "${IFLATPAK_USER_PACKAGES[@]}" -y &
    else
        echo "No per-user Flatpak packages defined."
    fi
else
    echo "Flatpak is not installed. Skipping Flatpak packages."
fi

if [[ -n "$(jobs -p)" ]]; then
    wait
fi

echo "Post-installation packages completed."

exit 0
