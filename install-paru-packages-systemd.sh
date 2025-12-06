#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"
. "$SCRIPTDIR/packages.sh"

## Deferred / AUR packages installation

echo Installing dekstop and AUR packages...

autosudo "$ISUPER_USER" /mnt \
    retry arch-chroot /mnt sudo -u "$ISUPER_USER" paru -Syu --needed --noconfirm \
        "${IPREPACMAN_PACKAGES[@]}"

autosudo "$ISUPER_USER" /mnt \
    retry arch-chroot /mnt sudo -u "$ISUPER_USER" paru -Syu --needed --noconfirm \
        "${IPACMAN_PACKAGES[@]}" \
        "${IAUR_PACKAGES[@]}"

echo Done

## Configure systemd-timesyncd NTP servers

mkdir -p /mnt/etc/systemd/timesyncd.conf.d

cat <<EOF > /mnt/etc/systemd/timesyncd.conf.d/ntp.conf
[Time]
NTP=$INTP
FallbackNTP=$INTP_FALLBACK
EOF

arch-chroot /mnt systemctl enable systemd-timesyncd.service

## OpenSSH Server

if chkpkgroot /mnt openssh; then
    arch-chroot /mnt systemctl enable sshd.service
fi

## systemd-boot auto update

# per https://wiki.archlinux.org/title/Systemd-boot#systemd_service
if [[ "$IBOOTLOADER" == "systemd-boot" ]]; then
    arch-chroot /mnt systemctl enable systemd-boot-update.service
fi

## Network config

# systemd-resolved

if chkpkgroot /mnt systemd-resolvconf; then
    arch-chroot /mnt systemctl enable systemd-resolved.service

    ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

    mkdir -p /mnt/etc/systemd/resolved.conf.d

    cat <<EOF > /mnt/etc/systemd/resolved.conf.d/10-dns.conf
    [Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
FallbackDNS=9.9.9.9#dns.quad9.net
DNSOverTLS=yes
DNSSEC=no
EOF
fi

# NetworkManager

if chkpkgroot /mnt networkmanager; then
    arch-chroot /mnt systemctl enable NetworkManager.service

    # systemd-resolved integration
    if chkpkgroot /mnt systemd-resolvconf; then
        mkdir -p /mnt/etc/NetworkManager/conf.d

        cat <<EOF > /mnt/etc/NetworkManager/conf.d/10-resolved.conf
[main]
dns=systemd-resolved
EOF
    fi
fi

# Firewall

if chkpkgroot /mnt ufw; then
    arch-chroot /mnt systemctl enable ufw.service
fi

# Bluetooth

if chkpkgroot /mnt bluez; then
    arch-chroot /mnt systemctl enable bluetooth.service
fi

## SDDM config

if chkpkgroot /mnt sddm; then
    arch-chroot /mnt systemctl enable sddm.service
    mkdir -p /mnt/etc/sddm.conf.d
    cat <<EOF > /mnt/etc/sddm.conf.d/kde_settings.conf
[Theme]
Current=breeze
EOF
fi

## Pipewire

if chkpkgroot /mnt pipewire; then
    arch-chroot /mnt systemctl --global enable pipewire.socket
fi

if chkpkgroot /mnt pipewire-pulse; then
    arch-chroot /mnt systemctl --global enable pipewire-pulse.socket
fi

if chkpkgroot /mnt wireplumber; then
    arch-chroot /mnt systemctl --global enable wireplumber.service
fi

## Misc.

# System out-of-memory service

arch-chroot /mnt systemctl enable systemd-oomd.service

# Firmware update

if chkpkgroot /mnt fwupd; then
    arch-chroot /mnt systemctl enable fwupd-refresh.timer
fi

# Auto rotation for 2-in-1 devices

if chkpkgroot /mnt iio-sensor-proxy; then
    arch-chroot /mnt systemctl enable iio-sensor-proxy.service
fi

# Thunderbolt manager

if chkpkgroot /mnt bolt; then
    arch-chroot /mnt systemctl enable bolt.service
fi

# SSD trimming timer

arch-chroot /mnt systemctl enable fstrim.timer

# man database

if chkpkgroot /mnt man-db; then
    arch-chroot /mnt systemctl enable man-db.timer
fi

# plocate database

if chkpkgroot /mnt plocate; then
    arch-chroot /mnt systemctl enable plocate-updatedb.timer
fi

# Pacman mirror

if chkpkgroot /mnt reflector; then
    arch-chroot /mnt systemctl enable reflector.timer
fi

# Pacman cache clean up timer

if chkpkgroot /mnt pacman-contrib; then
    arch-chroot /mnt systemctl enable paccache.timer
fi
