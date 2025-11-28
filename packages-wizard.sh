#!/usr/bin/bash

# Interactive wizard to edit package lists (pacstrap, pacman, AUR, late, flatpak).
# Shared helper functions live in wizard-common.sh.

. "$(dirname ${BASH_SOURCE[0]})"/wizard-common.sh
. "$SCRIPTDIR/packages.sh"
. "$SCRIPTDIR/flatpak-packages.sh"

set -euo pipefail
IFS=$'\n\t'

DEFAULT_PKGS_FILE="$SCRIPTDIR/packages.sh"
DEFAULT_PKGS_GENERATED="$SCRIPTDIR/packages-generated.sh"
DEFAULT_FLATPAK_FILE="$SCRIPTDIR/flatpak-packages.sh"
DEFAULT_FLATPAK_GENERATED="$SCRIPTDIR/flatpak-packages-generated.sh"

choose_defaults() {
    choose_defaults_common "$DEFAULT_PKGS_FILE" "$DEFAULT_PKGS_GENERATED" \
        "Packages file to load" "Packages file to save" \
        "PACKAGES_IN" "PACKAGES_OUT"
    if [[ -f "$PACKAGES_IN" ]]; then
        # shellcheck disable=SC1090
        . "$PACKAGES_IN"
    else
        echo "Packages file '$PACKAGES_IN' not found; keeping defaults."
    fi

    choose_defaults_common "$DEFAULT_FLATPAK_FILE" "$DEFAULT_FLATPAK_GENERATED" \
        "Flatpak file to load" "Flatpak file to save" \
        "FLATPAK_IN" "FLATPAK_OUT"
    if [[ -f "$FLATPAK_IN" ]]; then
        # shellcheck disable=SC1090
        . "$FLATPAK_IN"
    else
        echo "Flatpak file '$FLATPAK_IN' not found; keeping defaults."
    fi
}

write_packages() {
    {
        echo "#!/usr/bin/bash"
        echo
        write_array "IPACSTRAP_PACKAGES"
        write_array "IPACMAN_PACKAGES"
        write_array "IAUR_PACKAGES"
        write_array "ILATE_PACKAGES"
    } > "$PACKAGES_OUT"
    echo "Saved package lists to $PACKAGES_OUT"
}

write_flatpaks() {
    {
        echo "#!/usr/bin/bash"
        echo
        write_array "IFLATPAK_PACKAGES"
    } > "$FLATPAK_OUT"
    echo "Saved flatpak list to $FLATPAK_OUT"
}

show_menu() {
    echo
    echo "Package lists:"
    echo "  Load packages: $PACKAGES_IN"
    echo "  Load flatpaks: $FLATPAK_IN"
    echo "  Save packages: $PACKAGES_OUT"
    echo "  Save flatpaks: $FLATPAK_OUT"
    echo "  1) IPACSTRAP_PACKAGES    (${#IPACSTRAP_PACKAGES[@]} entries)"
    echo "  2) IPACMAN_PACKAGES      (${#IPACMAN_PACKAGES[@]} entries)"
    echo "  3) IAUR_PACKAGES         (${#IAUR_PACKAGES[@]} entries)"
    echo "  4) ILATE_PACKAGES        (${#ILATE_PACKAGES[@]} entries)"
    echo "  5) IFLATPAK_PACKAGES     (${#IFLATPAK_PACKAGES[@]} entries)"
    echo "  f) Change load/save files"
    echo "  s) Save and exit"
    echo "  q) Quit without saving"
}

main() {
    choose_defaults
    while true; do
        show_menu
        read -rp "Select list to edit: " choice
        case "${choice,,}" in
            1) edit_array "IPACSTRAP_PACKAGES" "Pacstrap packages (base install)";;
            2) edit_array "IPACMAN_PACKAGES" "Pacman packages (post install)";;
            3) edit_array "IAUR_PACKAGES" "AUR packages";;
            4) edit_array "ILATE_PACKAGES" "Late AUR/Pacman packages";;
            5) edit_array "IFLATPAK_PACKAGES" "Flatpak packages";;
            f)
                choose_defaults
                ;;
            s)
                write_packages
                write_flatpaks
                exit 0
                ;;
            q)
                echo "No changes saved."
                exit 0
                ;;
            *)
                echo "Invalid selection."
                ;;
        esac
    done
}

main "$@"
