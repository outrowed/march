#!/usr/bin/bash
# Unattend Arch by Outrowed

SCRIPTDIR="$(dirname ${BASH_SOURCE[0]})"
. "$SCRIPTDIR/config.sh"
ROOT="${MARCH_ROOT:-/mnt}"

## Configure Pacman Hooks

echo "Configuring system maintenance hooks at $ROOT..."

# Create the hooks directory
mkdir -p "$ROOT/etc/pacman.d/hooks"

# Systemd-boot Update Hook

if [[ "$IBOOTLOADER" == "systemd-boot" ]]; then
    # Automatically updates the bootloader binary (BOOTX64.EFI) when systemd is updated
    # https://wiki.archlinux.org/title/Systemd-boot#pacman_hook
    cat <<EOF > "$ROOT/etc/pacman.d/hooks/95-systemd-boot.hook"
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Gracefully upgrading systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
EOF
fi

# NVIDIA Initramfs Hook

# This hook ensures initramfs is rebuilt if ONLY the nvidia driver updates (without a kernel update)
cat <<EOF > "$ROOT/etc/pacman.d/hooks/90-nvidia.hook"
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = nvidia
Target = nvidia-open

[Action]
Description = Updating NVIDIA module in initcpio...
Depends = mkinitcpio
When = PostTransaction
NeedsTargets
Exec = /bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

# Arch Audit Hook

# Automatically runs arch-audit after package upgrades to check for vulnerabilities
cat <<EOF > "$ROOT/etc/pacman.d/hooks/90-arch_audit.hook"
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]

Depends = curl
Depends = openssl
Depends = arch-audit
When = PostTransaction
Exec = /usr/bin/arch-audit
EOF
