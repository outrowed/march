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

set +a