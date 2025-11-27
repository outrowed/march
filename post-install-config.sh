#!/usr/bin/bash
# Unattend Arch by Outrowed

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR/march-config.sh"

echo "Starting post-installation configuration..."

hwclock --systohc

## Configure systemd-resolved

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf || true

systemctl enable systemd-resolved.service

## Configure UFW

# Set default rules
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow ssh

# Allow KDE Connect
ufw allow 1714:1764/udp
ufw allow 1714:1764/tcp

# Turn on the firewall 
ufw --force enable

## kdenetwork-filesharing setup

# Add user to sambashare
groupadd -r sambashare
gpasswd -a "$ISUPER_USER" sambashare

# Enable samba services
systemctl enable smb nmb

## Sunshine setup

# Allow sunshine through firewall
ufw allow 47984/udp
ufw allow 47989/tcp

# KMS capture
setcap cap_sys_admin+p $(readlink -f $(which sunshine))

# Enable sunshine service
systemctl enable --global sunshine

echo "Post-installation configuration completed."

exit 0
