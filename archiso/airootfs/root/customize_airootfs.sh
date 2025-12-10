#!/usr/bin/bash
# This script runs inside the archiso chroot while building the image.

set -euo pipefail

LIVEUSER="${LIVEUSER:-liveuser}"

# Ensure the live session targets a graphical login.
systemctl set-default graphical.target

# Enable services needed for the live desktop and installer.
if systemctl list-unit-files | grep -q '^NetworkManager.service'; then
    systemctl enable NetworkManager.service
fi

if systemctl list-unit-files | grep -q '^sddm.service'; then
    systemctl enable sddm.service
fi

# Create or refresh the live user.
if id -u "$LIVEUSER" >/dev/null 2>&1; then
    usermod -aG wheel,video,audio,storage,network,power "$LIVEUSER"
else
    useradd -m -s /bin/bash -G wheel,video,audio,storage,network,power "$LIVEUSER"
fi

passwd -d "$LIVEUSER"
echo "$LIVEUSER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/00-liveuser
chmod 0440 /etc/sudoers.d/00-liveuser

# Autologin straight into the Plasma session.
install -d -m 0755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/20-autologin.conf <<EOF
[Autologin]
User=$LIVEUSER
Session=plasma.desktop
EOF

# Ensure skeleton files (Calamares autostart) are owned by the live user.
if [[ -d "/home/${LIVEUSER}" ]]; then
    chown -R "$LIVEUSER:$LIVEUSER" "/home/${LIVEUSER}"
fi
