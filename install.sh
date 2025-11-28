#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/packages.sh"
. "$SCRIPTDIR/config.sh"

echo "Starting Arch Linux installation..."

MARCH_INSTALL_STATE_DIR="/mnt/var/lib/march-install"

mkdir -p "$MARCH_INSTALL_STATE_DIR"

if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "ERROR: No internet connection."
    exit 1
fi

## Configure reflector

echo Configuring reflector...

retry reflector --country "$IREFLECTOR_COUNTRY" --latest "$IREFLECTOR_LATEST" --protocol https --sort rate --age 12 --save /etc/pacman.d/mirrorlist

## Partitioning

# Reformat partitions
if prompt "This script will reformat $IROOT_PARTITION_LABEL and $IHOME_PARTITION_LABEL."; then
    ./reformat-partitions.sh
else
    echo "Skipping partition reformat; existing data will be preserved."
fi

# Mount partitions
./mount-partitions.sh

# Cleanup /mnt/boot
./cleanup-boot.sh

# Pacstrap packages to /mnt

PACSTRAP_FLAG="$MARCH_INSTALL_STATE_DIR/pacstrap.done"
RUN_PACSTRAP=1

if [[ -f "$PACSTRAP_FLAG" ]]; then
    if prompt "Pacstrap already completed (found $PACSTRAP_FLAG). Run pacstrap again?"; then
        RUN_PACSTRAP=1
    else
        RUN_PACSTRAP=0
        echo "Skipping pacstrap; continuing with existing /mnt contents."
    fi
fi

if [[ "$RUN_PACSTRAP" -eq 0 && ! -d /mnt/etc ]]; then
    echo "pacstrap has not been run yet (missing /mnt/etc). Please allow pacstrap to run."
    exit 1
fi

if [[ "$RUN_PACSTRAP" -eq 1 ]]; then
    echo Running pacstrap on /mnt...
    rm -f "$PACSTRAP_FLAG"
    retry pacstrap -K /mnt "${IPACSTRAP_PACKAGES[@]}"
    date -Iseconds > "$PACSTRAP_FLAG"
fi

# Generate fstab to Arch Linux

# Intentionally clears the fstab file
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
echo 'MODULES+=(i915 vmd)' \
    > /mnt/etc/mkinitcpio.conf.d/intel.conf

# AMD modules
echo 'MODULES+=(amdgpu)' \
    > /mnt/etc/mkinitcpio.conf.d/amd.conf

# Plymouth hook
# Use sed to find 'udev' and replace it with 'udev plymouth'
# This creates the order: base udev plymouth autodetect ...
arch-chroot /mnt sed -i 's/udev/udev plymouth/g' /etc/mkinitcpio.conf

# Regenerate the initramfs
retry arch-chroot /mnt mkinitcpio -p linux

# Configure a boot loader

CMDLINE="root=UUID=$(root-uuid) rw nvidia_drm.modeset=1 i915.enable_guc=2 quiet splash rd.systemd.show_status=auto systemd.gpt_auto=0"

if [[ "$IBOOTLOADER" == "systemd-boot" ]]; then
    echo Setting up systemd-boot...

    ./install-systemd-boot.sh "$CMDLINE"
elif [[ "$IBOOTLOADER" == "uki" ]]; then
    echo Setting up UKI...

    ./install-uki.sh "$CMDLINE"
else
    echo "Unsupported bootloader: $IBOOTLOADER"
    exit 1
fi

## User configuration

# Configure sudoers
echo "%wheel ALL=(ALL:ALL) ALL" | tee /mnt/etc/sudoers.d/10-wheel
chmod 440 /mnt/etc/sudoers.d/10-wheel

# Check if the passwords directory exists and is not empty
if [[ ! -d passwords || -z "$(ls -A passwords 2>/dev/null)" ]]; then
    echo "'passwords/' directory is missing or empty. Prompting multi-user creation..."
    ./users-wizard.sh "$ISUPER_USER"
fi

# Setup users from passwords/ directory
./install-users.sh

if ! arch-chroot /mnt id "$ISUPER_USER" &>/dev/null; then
    echo "CRITICAL ERROR: Main user '$ISUPER_USER' was not created!"
    exit 1
fi

arch-chroot /mnt usermod -aG wheel "$ISUPER_USER"

## Shell global config

BASHRC_FLAG="$MARCH_INSTALL_STATE_DIR/bashrc.done"

# Bash global config
if [[ -f "$BASHRC_FLAG" ]]; then
    echo "Global bash config already added; skipping /mnt/etc/bash.bashrc append."
else
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
    date -Iseconds > "$BASHRC_FLAG"
fi

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
retry arch-chroot /mnt reflector --country "$IREFLECTOR_COUNTRY" --latest "$IREFLECTOR_LATEST" --protocol https --sort rate --age 12 --save /etc/pacman.d/mirrorlist

# This ensures that when the weekly timer runs, it uses your preferred countries.
mkdir -p /mnt/etc/xdg/reflector

cat <<EOF > /mnt/etc/xdg/reflector/reflector.conf
# Reflector configuration generated by march/install
--save /etc/pacman.d/mirrorlist
--country $IREFLECTOR_COUNTRY
--latest $IREFLECTOR_LATEST
--protocol https
--age 12
--sort rate
EOF

echo Done

# Install paru AUR helper (which requires a user to build)

echo Installing paru AUR helper...

./install-paru.sh "$ISUPER_USER"

echo Done

## Pacman hooks config

./install-pacman-hooks.sh

## Deferred packages installation & Systemd services setup

./install-paru-packages-systemd.sh

## Post-install setup on first boot

./install-post-install-setup.sh

echo "Arch Linux installation completed."
