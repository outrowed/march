#!/usr/bin/bash
# Unattend Arch by Outrowed

## Configure Pacman Hooks

echo "Configuring system maintenance hooks..."

# Create the hooks directory
mkdir -p /mnt/etc/pacman.d/hooks

# Systemd-boot Update Hook

# Automatically updates the bootloader binary (BOOTX64.EFI) when systemd is updated
cat <<EOF > /mnt/etc/pacman.d/hooks/95-systemd-boot.hook
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Gracefully upgrading systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
EOF

# NVIDIA Initramfs Hook

# This hook ensures initramfs is rebuilt if ONLY the nvidia driver updates (without a kernel update)
cat <<EOF > /mnt/etc/pacman.d/hooks/nvidia.hook
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
cat <<EOF > /mnt/etc/pacman.d/hooks/arch_audit.hook
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