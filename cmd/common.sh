#!/usr/bin/bash
# Shim so cmd/ scripts can source common helpers from project root.

CMD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CMD_DIR"

. "$CMD_DIR/../common.sh"
