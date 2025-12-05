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

if chkpkgroot /mnt openssh; then
    arch-chroot /mnt systemctl enable sshd.service
fi

if [[ "$IBOOTLOADER" == "systemd-boot" ]]; then
    arch-chroot /mnt systemctl enable systemd-boot-update.service
fi

if chkpkgroot /mnt sddm; then
    arch-chroot /mnt systemctl enable sddm.service
fi

if chkpkgroot /mnt networkmanager; then
    arch-chroot /mnt systemctl enable NetworkManager.service
fi

if chkpkgroot /mnt ufw; then
    arch-chroot /mnt systemctl enable ufw.service
fi

if chkpkgroot /mnt bluez; then
    arch-chroot /mnt systemctl enable bluetooth.service
fi

arch-chroot /mnt systemctl enable systemd-oomd.service

if chkpkgroot /mnt fwupd; then
    arch-chroot /mnt systemctl enable fwupd-refresh.timer
fi

# Enable PipeWire

if chkpkgroot /mnt pipewire; then
    arch-chroot /mnt systemctl --global enable pipewire.socket
fi

if chkpkgroot /mnt pipewire-pulse; then
    arch-chroot /mnt systemctl --global enable pipewire-pulse.socket
fi

if chkpkgroot /mnt wireplumber; then
    arch-chroot /mnt systemctl --global enable wireplumber.service
fi

# Auto rotation for 2-in-1 devices
if chkpkgroot /mnt iio-sensor-proxy; then
    arch-chroot /mnt systemctl enable iio-sensor-proxy.service
fi

# Thunderbolt manager
if chkpkgroot /mnt bolt; then
    arch-chroot /mnt systemctl enable bolt.service
fi

if chkpkgroot /mnt reflector; then
    arch-chroot /mnt systemctl enable reflector.timer
fi

arch-chroot /mnt systemctl enable fstrim.timer

if chkpkgroot /mnt man-db; then
    arch-chroot /mnt systemctl enable man-db.timer
fi

if chkpkgroot /mnt plocate; then
    arch-chroot /mnt systemctl enable plocate-updatedb.timer
fi

if chkpkgroot /mnt pacman-contrib; then
    arch-chroot /mnt systemctl enable paccache.timer
fi
