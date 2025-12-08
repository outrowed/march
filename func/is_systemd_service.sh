#!/usr/bin/bash
# Detect if running inside a systemd service unit.

set -euo pipefail

main() {
    if [[ -n "${INVOCATION_ID-}" || -n "${SYSTEMD_EXEC_PID-}" || -n "${JOURNAL_STREAM-}" ]]; then
        return 0
    fi
    return 1
}

main "$@"
