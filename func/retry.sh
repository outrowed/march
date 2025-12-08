#!/usr/bin/bash
# Generic retry loop with interactive control.

set -euo pipefail

main() {
    local fn="$1"
    shift || true

    while true; do
        if "$fn" "$@"; then
            return 0
        fi

        local status=$?
        echo "'$fn' failed with exit code $status."

        while true; do
            read -p "Retry $fn? [r]etry/[s]kip/[e]xit: " choice

            case "$choice" in
                [Rr]* )
                    echo "Retrying $fn..."
                    break
                    ;;
                [Ss]* )
                    echo "Skipping $fn."
                    return 0
                    ;;
                [Ee]* )
                    echo "Exiting install."
                    exit "$status"
                    ;;
                * )
                    echo "Please enter r to retry, s to skip, or e to exit."
                    ;;
            esac
        done
    done
}

main "$@"
