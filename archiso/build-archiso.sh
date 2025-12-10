#!/usr/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE_DIR="$SCRIPT_DIR"
WORK_DIR="${WORK_DIR:-$PROFILE_DIR/work}"
OUT_DIR="${OUT_DIR:-$PROFILE_DIR/out}"
BASE_PACKAGES="$PROFILE_DIR/packages.base.x86_64"
TARGET_PACKAGES="$PROFILE_DIR/packages.x86_64"
SYNC_DEST="$PROFILE_DIR/airootfs/opt/march"
LOCAL_REPO_DIR="$PROFILE_DIR/localrepo"
LOCAL_REPO_DB="$LOCAL_REPO_DIR/march-local.db.tar.gz"
PACMAN_CONF="$PROFILE_DIR/pacman.conf"

prefer_file() {
    local default="$1" alt="$2"
    if [[ -n "${MARCH_PREFER_USER_CONFIG:-}" && -f "$alt" ]]; then
        echo "$alt"
    elif [[ -f "$alt" ]]; then
        echo "$alt"
    else
        echo "$default"
    fi
}

PACKAGES_FILE="${MARCH_PACKAGES_FILE:-$(prefer_file "$ROOT_DIR/packages.sh" "$ROOT_DIR/packages-user.sh")}"
FLATPAK_FILE="${MARCH_FLATPAK_FILE:-$(prefer_file "$ROOT_DIR/flatpak-packages.sh" "$ROOT_DIR/flatpak-packages-user.sh")}"

if [[ ! -f "$PACKAGES_FILE" ]]; then
    echo "Packages file not found: $PACKAGES_FILE"
    exit 1
fi

if [[ ! -f "$BASE_PACKAGES" ]]; then
    echo "Base packages file not found: $BASE_PACKAGES"
    exit 1
fi

if [[ ! -f "$PACMAN_CONF" ]]; then
    echo "pacman.conf not found at $PACMAN_CONF"
    exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "mkarchiso is not installed (pacman -S archiso)"
    exit 1
fi

PACMAN_ORIG="$(cat "$PACMAN_CONF")"
trap 'printf "%s\n" "$PACMAN_ORIG" > "$PACMAN_CONF"' EXIT

update_pacman_conf() {
    local repo_path="${1:-}"
    {
        if [[ -n "$repo_path" ]]; then
            echo "[march-local]"
            echo "SigLevel = Optional TrustAll"
            echo "Server = file://$repo_path"
            echo
        fi
        printf "%s\n" "$PACMAN_ORIG"
    } > "$PACMAN_CONF"
}

update_pacman_conf

PACMAN_CMD=(pacman --config "$PACMAN_CONF")

# shellcheck source=/dev/null
. "$PACKAGES_FILE"

if [[ -f "$FLATPAK_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$FLATPAK_FILE"
fi

mapfile -t base_pkgs < <(grep -Ev '^\s*#|^\s*$' "$BASE_PACKAGES")

declare -A pkgset=()
missing_packages=()

add_pkg() {
    local pkg
    for pkg in "$@"; do
        pkgset["$pkg"]=1
    done
}

add_if_available() {
    local pkg
    for pkg in "$@"; do
        if "${PACMAN_CMD[@]}" -Sp --print-format '%n' "$pkg" >/dev/null 2>&1; then
            pkgset["$pkg"]=1
        else
            missing_packages+=("$pkg")
        fi
    done
}

refresh_local_repo() {
    local repo_abs="$1"
    local db_path="$2"

    mapfile -t repo_pkgs < <(find "$repo_abs" -maxdepth 1 -type f -name '*.pkg.tar.*' | sort -V)
    if ((${#repo_pkgs[@]})); then
        rm -f "$db_path" "${db_path%.db.tar.gz}.files" "${db_path%.db.tar.gz}.files.tar.gz"
        repo-add "$db_path" "${repo_pkgs[@]}"
    fi
}

build_calamares_aur() {
    local build_root="${AUR_BUILD_DIR:-$PROFILE_DIR/.aur-build}"

    mkdir -p "$build_root"

    if ! command -v git >/dev/null 2>&1; then
        echo "git is required to build Calamares from AUR." >&2
        exit 1
    fi

    if [[ ! -d "$build_root/calamares" ]]; then
        git clone https://aur.archlinux.org/calamares.git "$build_root/calamares"
    else
        git -C "$build_root/calamares" pull --ff-only
    fi

    pushd "$build_root/calamares" >/dev/null
    makepkg -sf --noconfirm --syncdeps
    local pkg
    pkg=$(ls calamares-*.pkg.tar.* | sort -V | tail -n1)
    cp "$pkg" "$LOCAL_REPO_DIR/"
    popd >/dev/null
}

ensure_calamares_available() {
    if "${PACMAN_CMD[@]}" -Sp --print-format '%n' calamares >/dev/null 2>&1; then
        add_pkg calamares
        return
    fi

    mkdir -p "$LOCAL_REPO_DIR"
    local repo_abs
    repo_abs="$(realpath "$LOCAL_REPO_DIR")"
    local cal_pkg=""
    cal_pkg=$(ls "$LOCAL_REPO_DIR"/calamares-*.pkg.tar.* 2>/dev/null | sort -V | tail -n1 || true)

    if [[ -n "$cal_pkg" ]]; then
        refresh_local_repo "$repo_abs" "$LOCAL_REPO_DB"
        update_pacman_conf "$repo_abs"
        add_pkg calamares
        return
    fi

    if [[ "${MARCH_BUILD_CALAMARES_AUR:-0}" == "1" ]]; then
        build_calamares_aur
        repo_abs="$(realpath "$LOCAL_REPO_DIR")"
        refresh_local_repo "$repo_abs" "$LOCAL_REPO_DB"
        update_pacman_conf "$repo_abs"
        add_pkg calamares
        return
    fi

    echo "Calamares is not available in the official repositories." >&2
    echo "Provide a built calamares package in $LOCAL_REPO_DIR or set MARCH_BUILD_CALAMARES_AUR=1 to build from AUR." >&2
    exit 1
}

# Base profile packages from releng
add_pkg "${base_pkgs[@]}"

ensure_calamares_available

# GUI + Calamares live session requirements
CALAMARES_LIVE_PKGS=(
    plasma-desktop
    sddm
    konsole
    xorg-server
    xorg-xinit
    xorg-xwayland
    xorg-xhost
    networkmanager
    plasma-nm
)
add_if_available "${CALAMARES_LIVE_PKGS[@]}"

# Installer package payloads (Pacstrap + Pacman stages)
add_if_available "${IPACSTRAP_PACKAGES[@]}"
add_if_available "${IPREPACMAN_PACKAGES[@]}"
add_if_available "${IPACMAN_PACKAGES[@]}"

printf "%s\n" "${!pkgset[@]}" | sort -u > "$TARGET_PACKAGES"

echo "Wrote $(wc -l < "$TARGET_PACKAGES") packages to $TARGET_PACKAGES"
if ((${#missing_packages[@]})); then
    echo "Skipped packages not in repositories (likely AUR): ${missing_packages[*]}"
fi

echo "Syncing march repo into the ISO at $SYNC_DEST..."
rm -rf "$SYNC_DEST"
mkdir -p "$SYNC_DEST"
rsync -a --delete \
    --exclude '.git' \
    --exclude 'archiso/out' \
    --exclude 'archiso/work' \
    --exclude 'archiso/localrepo' \
    --exclude 'archiso/.aur-build' \
    --exclude 'archiso/airootfs/opt/march' \
    "$ROOT_DIR/" "$SYNC_DEST/"

if [[ "${SKIP_MKARCHISO:-0}" == "1" ]]; then
    echo "SKIP_MKARCHISO=1 set; mkarchiso build step skipped."
    exit 0
fi

echo "Building ISO with mkarchiso (work: $WORK_DIR, out: $OUT_DIR)..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo "ISO build complete. Artifacts are in $OUT_DIR"
