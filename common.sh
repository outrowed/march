#!/usr/bin/bash

set -a
set -euo pipefail

shopt -s dotglob nullglob

IFS=$'\n\t'

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

if [[ "$PWD" != "$SCRIPTDIR" ]]; then
    echo "Please run the installer from its directory: $SCRIPT_SRC_DIR (current: $PWD)"
    exit 1
fi

derive_efi_device() {
    local partition="$1"
    local device_var="$2"
    local part_var="$3"

    if [[ -z "$partition" ]]; then
        echo "ERROR: undefined EFI device variable \$partition: '$partition'"
        exit 1
    fi

    local parent part_index

    parent="$(lsblk -no PKNAME "$partition" 2>/dev/null | head -n1)"
    part_index="$(lsblk -no PARTN "$partition" 2>/dev/null | head -n1)"

    if [[ -z "$partition" || -z "$parent" || -z "$part_index" ]]; then
        echo "Unable to derive EFI device from '$partition'. Expected e.g. /dev/nvme0n1p1 or /dev/sda1."
        exit 1
    fi

    printf -v "$device_var" '/dev/%s' "$parent"
    printf -v "$part_var" '%s' "$part_index"
}

bakup() {
    if [[ -f "$1" ]]; then
        if [[ -f "$1".bak ]]; then
            cp "$1" "$1".$RANDOM.bak
        else
            cp "$1" "$1".bak
        fi
    fi
}

prompt() {
    while true; do
        read -p "$1 [YyNn]: " yn
        case $yn in
            [Yy]* ) return 0; break;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

retry() {
    local fn="$1"
    shift || true

    while true; do
        if "$fn" "$@"; then
            return 0
        fi

        local status=$?
        echo "'$fn' failed with exit code $status."

        if prompt "Retry $fn?"; then
            echo "Retrying $fn..."
        else
            echo "Exiting install."
            exit "$status"
        fi
    done
}

root-uuid() {
    ROOT_UUID=$(grep -E '\s/\s' /mnt/etc/fstab | awk '{print $1}' | sed 's/^UUID=//' | head -n1)

    if [[ -z "$ROOT_UUID" ]]; then
        ROOT_UUID=$(blkid -s UUID -o value "/dev/disk/by-partlabel/$IROOT_PARTITION_LABEL" || true)
    fi

    if [[ -z "$ROOT_UUID" ]]; then
        echo "Unable to determine root UUID for kernel cmdline."
        exit 1
    fi

    echo $ROOT_UUID
}

# check if packages exist
chkpkg() {
    # prefer paru if installed (AUR support)
    if command -v paru &>/dev/null; then
        checker="paru -Q"
    else
        checker="pacman -Q"
    fi

    # check all packages
    for pkg in "$@"; do
        $checker "$pkg" &>/dev/null || return 1
    done

    return 0
}

set +a
