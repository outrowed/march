#!/usr/bin/bash

set -a
set -euo pipefail
IFS=$'\n\t'

SCRIPTDIR="$(dirname ${BASH_SOURCE[1]})"

. "$SCRIPTDIR/config.sh"

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

set +a