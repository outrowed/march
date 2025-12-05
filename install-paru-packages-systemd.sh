#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"
. "$SCRIPTDIR/packages.sh"

## Deferred / AUR packages installation

echo Installing dekstop and AUR packages...

autosudo "$ISUPER_USER" /mnt \
    retry arch-chroot /mnt sudo -u "$ISUPER_USER" paru -Syu --needed --noconfirm \
        "${IPACMAN_PACKAGES[@]}" \
        "${IAUR_PACKAGES[@]}"

echo Done

## Systemd services

# Configure systemd-timesyncd NTP servers

mkdir -p /mnt/etc/systemd/timesyncd.conf.d

cat <<EOF > /mnt/etc/systemd/timesyncd.conf.d/ntp.conf
[Time]
NTP=$INTP
FallbackNTP=$INTP_FALLBACK
EOF

arch-chroot /mnt systemctl enable systemd-timesyncd.service

# Enable other services

arch-chroot /mnt systemctl enable sshd.service

if [[ "$IBOOTLOADER" == "systemd-boot" ]]; then
    arch-chroot /mnt systemctl enable systemd-boot-update.service
fi

arch-chroot /mnt systemctl enable sddm.service

arch-chroot /mnt systemctl enable NetworkManager.service

arch-chroot /mnt systemctl enable ufw.service

arch-chroot /mnt systemctl enable bluetooth.service

arch-chroot /mnt systemctl enable systemd-oomd.service

arch-chroot /mnt systemctl enable fwupd-refresh.timer

# Enable PipeWire

arch-chroot /mnt systemctl --global enable pipewire.socket
arch-chroot /mnt systemctl --global enable pipewire-pulse.socket
arch-chroot /mnt systemctl --global enable wireplumber.service

# Auto rotation for 2-in-1 devices
arch-chroot /mnt systemctl enable iio-sensor-proxy.service

# Thunderbolt manager
arch-chroot /mnt systemctl enable bolt.service

arch-chroot /mnt systemctl enable reflector.timer

arch-chroot /mnt systemctl enable fstrim.timer

arch-chroot /mnt systemctl enable man-db.timer

arch-chroot /mnt systemctl enable plocate-updatedb.timer

arch-chroot /mnt systemctl enable paccache.timer
