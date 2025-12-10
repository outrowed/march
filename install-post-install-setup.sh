#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

## Setup march/post-install-*.sh to run on first boot

ROOT="${MARCH_ROOT:-/mnt}"

echo "Setting up march post install script to run on first boot at $ROOT..."

install -Dm644 "$SCRIPTDIR/common.sh" "$ROOT/usr/local/sbin/march-common.sh"
install -Dm644 "$SCRIPTDIR/config.sh" "$ROOT/usr/local/sbin/march-config.sh"
install -Dm644 "$SCRIPTDIR/flatpak-packages.sh" "$ROOT/usr/local/sbin/march-flatpak-packages.sh"
install -Dm644 "$SCRIPTDIR/packages.sh" "$ROOT/usr/local/sbin/march-packages.sh"

# Post install configuration service

install -Dm755 "$SCRIPTDIR/post-install-config.sh" "$ROOT/usr/local/sbin/march-post-install-config.sh"

cat <<EOF > "$ROOT/etc/systemd/system/march-post-install-config.service"
[Unit]
Description=Run one-time march post install configuration on first boot
After=basic.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '/usr/local/sbin/march-post-install-config.sh && /usr/bin/systemctl disable --now march-post-install-config.service'

[Install]
WantedBy=multi-user.target
EOF

if [[ "$ROOT" == "/" ]]; then
    systemctl enable march-post-install-config.service
else
    arch-chroot "$ROOT" systemctl enable march-post-install-config.service
fi

# Flatpak and late AUR / Pacman packages installation service

install -Dm755 "$SCRIPTDIR/post-install-packages.sh" "$ROOT/usr/local/sbin/march-post-install-packages.sh"

cat <<EOF > "$ROOT/etc/systemd/system/march-post-install-packages.service"
[Unit]
Description=Run flatpak packages installation on first boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '/usr/local/sbin/march-post-install-packages.sh && /usr/bin/systemctl disable --now march-post-install-packages.service'

[Install]
WantedBy=multi-user.target
EOF

if [[ "$ROOT" == "/" ]]; then
    systemctl enable march-post-install-packages.service
else
    arch-chroot "$ROOT" systemctl enable march-post-install-packages.service
fi
