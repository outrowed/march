#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

## Setup march-post-install.sh to run on first boot

echo "Setting up march post install script to run on first boot..."

install -Dm644 "$SCRIPTDIR/config.sh" /mnt/usr/local/sbin/march-config.sh
install -Dm644 "$SCRIPTDIR/flatpak-packages.sh" /mnt/usr/local/sbin/march-flatpak-packages.sh
install -Dm644 "$SCRIPTDIR/packages.sh" /mnt/usr/local/sbin/march-packages.sh

# Post install configuration service

install -Dm755 "$SCRIPTDIR/march-post-install-config.sh" /mnt/usr/local/sbin/march-post-install-config.sh

cat <<EOF > /mnt/etc/systemd/system/march-post-install-config.service
[Unit]
Description=Run one-time march post install configuration on first boot

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/march-post-install-config.sh
ExecStartPost=/usr/bin/systemctl disable --now march-post-install-config.service

[Install]
WantedBy=multi-user.target
EOF

arch-chroot /mnt systemctl enable march-post-install-config.service

# Flatpak and late AUR / Pacman packages installation service

install -Dm755 "$SCRIPTDIR/march-post-install-packages.sh" /mnt/usr/local/sbin/march-post-install-packages.sh

cat <<EOF > /mnt/etc/systemd/system/march-post-install-packages.service
[Unit]
Description=Run flatpak packages installation on first boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/march-post-install-packages.sh
ExecStartPost=/usr/bin/systemctl disable --now march-post-install-packages.service

[Install]
WantedBy=multi-user.target
EOF

arch-chroot /mnt systemctl enable march-post-install-packages.service