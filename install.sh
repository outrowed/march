#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/packages.sh"
. "$SCRIPTDIR/config.sh"

echo "Starting Arch Linux installation..."

prompt "This script will reformat $IROOT_PARTITION_LABEL and $IHOME_PARTITION_LABEL."

if [[ $? = 1 ]]; then
    exit
fi

if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "Error: No internet connection."
    exit 1
fi

echo Configuring reflector...

reflector --country "$IREFLECTOR_COUNTRIES" --age 12 --save /etc/pacman.d/mirrorlist

## Partitioning

# Reformat partitions
./reformat-patitions.sh

# Mount partitions
./mount-partitions.sh

# Pacstrap packages to /mnt

echo Running pacstrap on /mnt...

pacstrap -K /mnt "${IPACSTRAP_PACKAGES[@]}"

# Generate fstab to Arch Linux

echo "# <file system> <dir> <type> <options> <dump> <pass>" > /mnt/etc/fstab

genfstab -U /mnt >> /mnt/etc/fstab

# Set hostname
echo "$IHOSTNAME" > /mnt/etc/hostname

## Timezone and localization config

# Select timezone from config
ln -sf /mnt/usr/share/zoneinfo/"$ITIMEZONE" /mnt/etc/localtime

# Generate localization from locale list

for locale in "${ILOCALE_GEN_LIST[@]}"; do
    sed -i "s/^#\($locale\)/\1/" /mnt/etc/locale.gen
done

arch-chroot /mnt locale-gen

# Set system locale

printf "%s\n" "${ILOCALE_CONF[@]}" | tee /mnt/etc/locale.conf

echo "KEYMAP=$IKEYMAP" > /mnt/etc/vconsole.conf

## Bootloader and initramfs config

# Adding essential modules and hooks to mkinitcpio config

mkdir -p /mnt/etc/mkinitcpio.conf.d

# USB modules
echo 'MODULES+=(usbhid xhci_pci)' \
    > /mnt/etc/mkinitcpio.conf.d/usb.conf

# NVIDIA modules
echo 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' \
    > /mnt/etc/mkinitcpio.conf.d/nvidia.conf

# Intel modules
echo 'MODULES+=(i915 vmd crc32c-intel)' \
    > /mnt/etc/mkinitcpio.conf.d/intel.conf

# AMD modules
echo 'MODULES+=(amdgpu)' \
    > /mnt/etc/mkinitcpio.conf.d/amd.conf

# Plymouth hook
# Use sed to find 'udev' and replace it with 'udev plymouth'
# This creates the order: base udev plymouth autodetect ...
arch-chroot /mnt sed -i 's/udev/udev plymouth/g' /etc/mkinitcpio.conf

# Regenerate the initramfs
arch-chroot /mnt mkinitcpio -p linux || true

# Configure systemd-boot bootloader

# Install systemd-boot to the ESP mount point
arch-chroot /mnt bootctl --esp-path=/efi install

# Create EFI boot entry
if ! efibootmgr | grep -q "${ISYSTEMD_BOOT_EFI_LABEL}$"; then
    efibootmgr --create --disk $IEFI_DEVICE --part $IEFI_PARTITION_INDEX --label "$ISYSTEMD_BOOT_EFI_LABEL" --loader /EFI/systemd/systemd-bootx64.efi
fi

# Create the main loader config
cat <<EOF > /mnt/efi/loader/loader.conf
default  arch.conf
timeout  5
console-mode max
editor no
EOF

# Create the Arch Linux boot entry

# Get the UUID for the root partition (/) from your fstab
ROOT_UUID=$(grep -E '\s/\s' /mnt/etc/fstab | awk '{print $1}' | sed 's/^UUID=//' | head -n1)

# Write the boot entry file

mkdir -p /mnt/efi/loader/entries

cat <<EOF > /mnt/efi/loader/entries/arch.conf
title   $ISYSTEMD_BOOT_ARCH_LABEL
linux   /EFI/$IEFI_LINUX_DIRNAME/vmlinuz-linux
initrd  /EFI/$IEFI_LINUX_DIRNAME/intel-ucode.img
initrd  /EFI/$IEFI_LINUX_DIRNAME/amd-ucode.img
initrd  /EFI/$IEFI_LINUX_DIRNAME/initramfs-linux.img
options root=UUID=$ROOT_UUID rw nvidia_drm.modeset=1 i915.enable_guc=2 quiet splash rd.systemd.show_status=auto
EOF

# Update systemd-boot
arch-chroot /mnt bootctl --esp-path=/efi update

## User configuration

# Configure sudoers
echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/10-wheel
chmod 440 /mnt/etc/sudoers.d/10-wheel

# Check if the passwords directory exists and is not empty
if [ ! -d "passwords" ] || [ -z "$(ls -A passwords)" ]; then
    echo "ERROR: 'passwords/' directory is missing or empty."
    echo "Please run users-gen.sh to generate user passwords."
    exit 1
fi

# Setup users from passwords/ directory
./install-users.sh

if ! arch-chroot /mnt id "$ISUPER_USER" &>/dev/null; then
    echo "CRITICAL ERROR: Main user '$ISUPER_USER' was not created!"
    exit 1
fi

arch-chroot /mnt usermod -aG wheel "$ISUPER_USER"

## Shell global config

# Bash global config
cat <<EOF >> /mnt/etc/bash.bashrc

# -- Added by march/install.sh --

# Enable colors for common commands
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -c'

# Set a colorful prompt (Green User @ Host : Blue CWD $)
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF

## ZRAM configuration

echo "Configuring ZRAM..."
cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF

## Pacman config

# Backup pacman config
bakup /mnt/etc/pacman.conf

# Enable pacman parallel downloads
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /mnt/etc/pacman.conf
# Enable pacman color
sed -i 's/^#Color/Color/' /mnt/etc/pacman.conf

# Configure reflector

echo Configuring reflector...

# Initial reflector run to set the mirrorlist
arch-chroot /mnt reflector --country "$IREFLECTOR_COUNTRIES" --age 12 --save /etc/pacman.d/mirrorlist

# This ensures that when the weekly timer runs, it uses your preferred countries.
mkdir -p /mnt/etc/xdg/reflector

cat <<EOF > /mnt/etc/xdg/reflector/reflector.conf
# Reflector configuration generated by march/install
--save /etc/pacman.d/mirrorlist
--country $IREFLECTOR_COUNTRIES
--protocol https
--age 12
--sort rate
EOF

echo Done

# Install paru AUR helper (which requires a user to build)

echo Installing paru AUR helper...

./install-paru "$ISUPER_USER"

echo Done

## Pacman hooks config

./install-pacman-hooks.sh

## Deferred packages installation & Systemd services setup

./install-paru-packages-systemd.sh

## Post-install setup on first boot

./install-post-install-setup.sh

echo "Arch Linux installation completed."
