#!/usr/bin/bash
# Unattend Arch by Outrowed

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR/march-common.sh"
. "$SCRIPT_DIR/march-config.sh"

echo "Starting post-installation configuration..."

hwclock --systohc

## Configure UFW

if chkpkg ufw; then
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
fi

## kdenetwork-filesharing setup

if chkpkg samba; then
    mkdir -p /etc/samba

    # Default samba configuration
    cat <<EOF > /etc/samba/smb.conf
[global]
workgroup = $IHOSTNAME
server string = $ISUPER_USER's Samba Server
server role = standalone server

logging = systemd
EOF

    # Add user to sambashare
    groupadd -r sambashare
    gpasswd -a "$ISUPER_USER" sambashare

    # UFW
    if chkpkg ufw; then
        ufw allow CIFS
    fi

    # Enable samba services
    systemctl enable smb nmb
fi

## Sunshine setup

if chkpkg sunshine; then
    if chkpkg ufw; then
        # Allow sunshine through firewall
        ufw allow 47984/udp
        ufw allow 47989/tcp
    fi

    # KMS capture
    setcap cap_sys_admin+p "$(readlink -f "$(command -v sunshine)")"

    # Enable sunshine service
    systemctl enable --global sunshine
fi

echo "Post-installation configuration completed."

exit 0
