#!/usr/bin/bash
# Temporary passwordless sudo helper.

set -euo pipefail

main() {
    local user="$1"
    local root="$2"
    shift 2

    local sudoers_file="$root/etc/sudoers.d/100-nopasswd-$user"

    echo "Temporarily enabling passwordless sudo for user: $user (in $root)"

    echo "$user ALL=(ALL:ALL) NOPASSWD: ALL" > "$sudoers_file"
    chmod 440 "$sudoers_file"

    # Ensure cleanup runs even if the command fails
    trap "rm -f \"$sudoers_file\"" EXIT INT TERM

    # Execute whatever commands were passed
    "$@"

    echo "Restoring sudo requirement..."
    rm -f "$sudoers_file"
    
    trap - EXIT INT TERM
}

main "$@"
