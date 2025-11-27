#!/usr/bin/bash
# Unattend Arch by Outrowed

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR/march-config.sh"
. "$SCRIPT_DIR/march-flatpak-packages.sh"
. "$SCRIPT_DIR/march-packages.sh"

echo "Starting post-installation configuration..."

## Late AUR / Pacman packages installation

echo "Installing late AUR / Pacman packages..."

echo "$ISUPER_USER ALL=(ALL:ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/00-paru-nopasswd

sudo -u "$ISUPER_USER" paru -Syu --needed --noconfirm \
    "${ILATE_PACKAGES[@]}"

echo "Restoring sudo password requirement..."

rm /etc/sudoers.d/00-paru-nopasswd

## Flatpak setup

echo "Installing Flatpaks..."

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install them (non-interactively)
flatpak install flathub "${IFLATPAK_PACKAGES[@]}" -y

echo "Post-installation configuration completed."

exit 0
