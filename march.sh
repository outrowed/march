#!/usr/bin/bash
# march bootstrap: sets common paths, loads env drop-ins, and auto-registers func/ helpers.

set -euo pipefail

shopt -s dotglob nullglob

IFS=$'\n\t'

MARCH_ROOT="${MARCH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
MARCH_FUNC_DIR="${MARCH_FUNC_DIR:-$MARCH_ROOT/func}"
MARCH_ENV_DIR="${MARCH_ENV_DIR:-$MARCH_ROOT/env}"

SCRIPTDIR="$MARCH_ROOT"

march_load_env() {
    shopt -s nullglob
    # Auto-export variables defined in env drop-ins to preserve prior behavior.
    set -a
    local env_file
    for env_file in "$MARCH_ENV_DIR"/*.sh; do
        [[ -f "$env_file" ]] || continue
        . "$env_file"
    done
    set +a
    shopt -u nullglob
}

march_register_funcs() {
    shopt -s nullglob
    local script_file script_name
    for script_file in "$MARCH_FUNC_DIR"/*.sh; do
        [[ -f "$script_file" ]] || continue
        script_name="$(basename "$script_file" .sh)"
        eval "$script_name() { \"$script_file\" \"\$@\"; }"
    done
    shopt -u nullglob
}

march_bootstrap() {
    march_load_env
    march_register_funcs
}

march_bootstrap

export MARCH_ROOT MARCH_FUNC_DIR MARCH_ENV_DIR SCRIPTDIR
