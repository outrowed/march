#!/usr/bin/bash
# Yes/no prompt that returns 0 on yes, 1 on no.

set -euo pipefail

main() {
    local message="$1"

    while true; do
        read -p "$message [YyNn]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

main "$@"
