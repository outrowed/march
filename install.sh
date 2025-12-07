#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/packages.sh"
. "$SCRIPTDIR/config.sh"

echo "Starting Arch Linux installation..."

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

# Remove files recursively in /mnt/boot
./cleanup-boot.sh

# Pacstrap packages to /mnt

MARCH_INSTALL_STATE_DIR="/mnt/var/lib/march-install"

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
    mkdir -p "$MARCH_INSTALL_STATE_DIR"
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
ln -sf /usr/share/zoneinfo/"$ITIMEZONE" /mnt/etc/localtime

# Generate localization from locale list

for locale in "${ILOCALE_GEN_LIST[@]}"; do
    sed -i "s/^#\($locale\)/\1/" /mnt/etc/locale.gen
done

arch-chroot /mnt locale-gen

# Set system locale

printf "%s\n" "${ILOCALE_CONF[@]}" | tee /mnt/etc/locale.conf

echo "KEYMAP=$IKEYMAP" > /mnt/etc/vconsole.conf

## Swap configuration

# resume= and resume_offset= in kernel parameter
RESUME_ARGS=""

configure_zram() {
    echo "Configuring ZRAM..."

    mkdir -p /mnt/etc/systemd/zram-generator.conf.d

    # On zram+swapfile configuration: prefer zram high priority (100), swapfile gets lower priority (10)
    # per https://wiki.gentoo.org/wiki/Zram#Using_systemd_zram-generator (modified)
    cat <<EOF > /mnt/etc/systemd/zram-generator.conf.d/zram0-swap.conf
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
}

configure_swapfile() {
    echo "Configuring swapfile..."
    swapfile=/mnt/swapfile

    # Allocate swapfile as 1.5x physical RAM (in MiB)
    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_mb=$((mem_kb / 1024))
    swap_mb=$((mem_mb + mem_mb / 2))

    if [[ -f "$swapfile" ]]; then
        echo "Existing swapfile found at $swapfile; recreating."
        rm -f "$swapfile"
    fi

    if ! fallocate -l "${swap_mb}M" "$swapfile"; then
        echo "fallocate failed; falling back to dd..."
        dd if=/dev/zero of="$swapfile" bs=1M count="$swap_mb" status=progress
    fi

    chmod 600 "$swapfile"
    arch-chroot /mnt mkswap /swapfile
    arch-chroot /mnt swapon /swapfile

    # On zram+swapfile configuration: prefer zram high priority (100), swapfile gets lower priority (10)
    if ! grep -qE '^/swapfile\s' /mnt/etc/fstab; then
        echo "/swapfile none swap defaults,pri=10 0 0" >> /mnt/etc/fstab
    fi

    # Capture resume= and resume_offset= from /swapfile for hibernation
    if command -v filefrag &>/dev/null; then
        resume_offset=$(arch-chroot /mnt filefrag -v /swapfile | awk '/ 0:/{print $4}' | cut -d. -f1)
        
        if [[ -n "$resume_offset" && "$resume_offset" =~ ^[0-9]+$ && "$resume_offset" -gt 0 ]]; then
            RESUME_ARGS="resume=UUID=$(root-uuid) resume_offset=$resume_offset"
        else
            echo "Warning: unable to determine resume_offset for swapfile."
        fi
    else
        echo "filefrag not available; skipping resume_offset calculation."
    fi
}

case "$ISWAP_TYPE" in
    "")
        echo "ISWAP_TYPE is unset; skipping swap configuration."
        ;;
    zram)
        configure_zram
        ;;
    swapfile)
        configure_swapfile
        ;;
    zram+swapfile)
        configure_zram
        configure_swapfile

        # Update fstab entry for swapfile with lower priority (e.g., 10)
        if grep -qE '^/swapfile\s' /mnt/etc/fstab; then
            sed -i 's|^/swapfile.*|/swapfile none swap defaults,pri=10 0 0|' /mnt/etc/fstab
        else
            echo "/swapfile none swap defaults,pri=10 0 0" >> /mnt/etc/fstab
        fi
        ;;
    *)
        echo "Unknown ISWAP_TYPE '$ISWAP_TYPE'; skipping swap configuration."
        ;;
esac

# Bootloader and initramfs config

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

# mkinitcpio HOOKS

IS_SYSTEMD_HOOKS=false
if [[ -f /mnt/etc/mkinitcpio.conf ]] && grep -Eq '^\s*HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf; then
    IS_SYSTEMD_HOOKS=true
fi

# see https://wiki.archlinux.org/title/Mkinitcpio#Common_hooks
# see https://github.com/archlinux/mkinitcpio/blob/master/meson.build for HOOKS/hooks default values
if [[ $IS_SYSTEMD_HOOKS == "true" || $IINITRAMFS_TYPE == "systemd" ]]; then
    # systemd init hooks
    # "systemd" hooks: udev, usr, resume
    # "sd-vconsole" hooks: keymap, consolefont
    HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)
else
    # busybox init hooks
    HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont)
    if [[ -n "$RESUME_ARGS" ]]; then
        HOOKS+=(resume)
    fi
    HOOKS+=(block usr filesystems fsck)
fi

{
    printf 'HOOKS=('
    printf '%s ' "${HOOKS[@]}"
    printf ')\n'
} > /mnt/etc/mkinitcpio.conf.d/hooks.conf

# Regenerate the initramfs
retry arch-chroot /mnt mkinitcpio -p linux

# Configure a boot loader

CMDLINE="root=UUID=$(root-uuid)"
if [[ -n "$IKERNEL_CMDLINE" ]]; then
    CMDLINE+=" $IKERNEL_CMDLINE"
fi
if [[ "$ISWAP_TYPE" == zram* && -n "$IKERNEL_ZSWAP_CMDLINE" ]]; then
    CMDLINE+=" $IKERNEL_ZSWAP_CMDLINE"
fi
# Only on busybox init
# systemd uses HibernationLocation EFI variable (automatically generated by systemd-hibernate.service) which contains resume and resume_offset information
#   ^ WARNING: may not work on dual boot linux system
if [[ -n "$RESUME_ARGS" && ( $IS_SYSTEMD_HOOKS == "false" || $IINITRAMFS_TYPE == "busybox" || $IEXPLICIT_RESUME_ARGS == "true" ) ]]; then
    CMDLINE+=" $RESUME_ARGS"
fi

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

## Shell global config

# Z shell useradd

sed -i 's|^SHELL=.*|SHELL=/bin/zsh|' /mnt/etc/default/useradd

# Bash global config

BASHRC_FLAG="$MARCH_INSTALL_STATE_DIR/bashrc.done"

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

## User configuration

# Configure sudoers
echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/10-wheel
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
