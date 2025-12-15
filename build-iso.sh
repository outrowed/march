#!/usr/bin/bash

# Build a custom Arch ISO (releng profile) with git and this march repo preinstalled.
# Usage: sudo ./build-iso.sh
# Optional env vars:
#   WORKDIR=...   # staging area (default: ./.mkarchiso-work)
#   OUTDIR=...    # output ISO dir (default: ./out)
#   ISO_LABEL=... # iso label (default: MARCH_$(date +%Y%m%d))

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo WORKDIR="${WORKDIR:-}" OUTDIR="${OUTDIR:-}" ISO_LABEL="${ISO_LABEL:-}" "$0" "$@"
fi

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${WORKDIR:-$SCRIPTDIR/.mkarchiso-work}"
OUTDIR="${OUTDIR:-$SCRIPTDIR/out}"
PROFILE_DIR="$WORKDIR/profile"
ISO_LABEL="${ISO_LABEL:-MARCH_$(date +%Y%m%d)}"

command -v mkarchiso >/dev/null 2>&1 || { echo "mkarchiso not found. Install archiso."; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync required."; exit 1; }

echo "Working dir: $WORKDIR"
echo "Output dir:  $OUTDIR"
echo "ISO label:   $ISO_LABEL"

rm -rf "$PROFILE_DIR"
mkdir -p "$WORKDIR" "$OUTDIR"

echo "Copying releng profile..."
cp -r /usr/share/archiso/configs/releng "$PROFILE_DIR"

echo "Adding git to packages..."
echo "git" >> "$PROFILE_DIR/packages.x86_64"

echo "Copying march repo into ISO (/root/march)..."
mkdir -p "$PROFILE_DIR/airootfs/root/march"
rsync -a \
    --exclude '.git' \
    --exclude '.mkarchiso-work' \
    --exclude 'out' \
    --exclude 'cache' \
    "$SCRIPTDIR"/ "$PROFILE_DIR/airootfs/root/march"/

echo "Building ISO with mkarchiso..."
mkarchiso -v \
    -L "$ISO_LABEL" \
    -w "$WORKDIR/work" \
    -o "$OUTDIR" \
    "$PROFILE_DIR"

echo "ISO build complete. Check $OUTDIR for the resulting image."
