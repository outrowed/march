#!/usr/bin/bash

# Interactive configurator for config.sh
# Uses wizard-common helpers for array handling and escaping.

. "$(dirname ${BASH_SOURCE[0]})"/wizard-common.sh

set -euo pipefail
IFS=$'\n\t'

DEFAULT_CONFIG_FILE="$SCRIPTDIR/config.sh"
DEFAULT_CONFIG_GENERATED="$SCRIPTDIR/config-generated.sh"

choose_defaults() {
    choose_defaults_common "$DEFAULT_CONFIG_FILE" "$DEFAULT_CONFIG_GENERATED" \
        "Config file to load" "Config file to save" \
        "CONFIG_IN" "CONFIG_OUT"
    if [[ -f "$CONFIG_IN" ]]; then
        # shellcheck disable=SC1090
        . "$CONFIG_IN"
    else
        echo "Config file '$CONFIG_IN' not found; starting with current defaults."
    fi
}

ITEMS=(
    "ISUPER_USER|string|Superuser username"
    "IHOSTNAME|string|Hostname"
    "ITIMEZONE|string|Timezone (Region/City)"
    "ILOCALE_GEN_LIST|array|Locales to generate (locale.gen)"
    "ILOCALE_CONF|array|Locale.conf entries"
    "IKEYMAP|string|Console keymap"
    "INTP|string|Primary NTP servers (space-separated)"
    "INTP_FALLBACK|string|Fallback NTP servers (space-separated)"
    "IROOT_PARTITION_LABEL|string|Root partition label"
    "IHOME_PARTITION_LABEL|string|Home partition label"
    "IROOT_PARTITION_FSTYPE|string|Root filesystem type"
    "IHOME_PARTITION_FSTYPE|string|Home filesystem type"
    "IREFLECTOR_COUNTRY|string|Reflector countries (comma-separated)"
    "IREFLECTOR_LATEST|string|Reflector 'latest' mirror count"
    "IEFI_PARTITION|string|EFI partition path"
    "IEFI_LINUX_DIRNAME|string|EFI Linux directory name"
    "IBOOTLOADER|string|Bootloader (systemd-boot/uki)"
    "ISYSTEMD_BOOT_ARCH_LABEL|string|systemd-boot Arch entry label"
    "ISYSTEMD_BOOT_EFI_LABEL|string|systemd-boot EFI label"
    "IUKI_LABEL|string|UKI label"
    "IUKI_EXEC|string|UKI executable filename"
    "IVISUDO_EDITOR|string|visudo editor path"
    "IPYLOLCAT|bool|Install pylolcat"
)

ask_value() {
    local prompt="$1" default="$2" out_var="$3"
    read -rp "$prompt [$default]: " input
    if [[ -z "$input" ]]; then
        printf -v "$out_var" '%s' "$default"
    else
        printf -v "$out_var" '%s' "$input"
    fi
}

ask_bool() {
    local prompt="$1" default="$2" out_var="$3"
    local def_hint="[Y/n]"
    [[ "${default,,}" == "false" ]] && def_hint="[y/N]"
    while true; do
        read -rp "$prompt $def_hint: " ans
        ans=${ans:-$default}
        case "${ans,,}" in
            y|yes|true)
                printf -v "$out_var" 'true'
                return
                ;;
            n|no|false)
                printf -v "$out_var" 'false'
                return
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

edit_item() {
    local entry="$1"
    local name type label
    IFS='|' read -r name type label <<<"$entry"

    if [[ "$type" == "array" ]]; then
        edit_array "$name" "$label"
        return
    fi

    local current=""
    if [[ -v "$name" ]]; then
        current="${!name}"
    fi

    case "$type" in
        string)
            ask_value "$label" "$current" "$name"
            ;;
        bool)
            ask_bool "$label" "$current" "$name"
            ;;
        *)
            echo "Unknown type '$type' for $name"
            ;;
    esac
}

write_config() {
    local outfile="$CONFIG_OUT"
    {
        echo "#!/usr/bin/bash"
        echo
        printf 'export ISUPER_USER=\"%s\"\n' "$(escape_val "$ISUPER_USER")"
        printf 'export IHOSTNAME=\"%s\"\n' "$(escape_val "$IHOSTNAME")"
        echo
        printf 'export ITIMEZONE=\"%s\"\n' "$(escape_val "$ITIMEZONE")"
        write_array "ILOCALE_GEN_LIST"
        write_array "ILOCALE_CONF"
        printf 'export IKEYMAP=\"%s\"\n' "$(escape_val "$IKEYMAP")"
        echo
        printf 'export INTP=\"%s\"\n' "$(escape_val "$INTP")"
        printf 'export INTP_FALLBACK=\"%s\"\n' "$(escape_val "$INTP_FALLBACK")"
        echo
        printf 'export IROOT_PARTITION_LABEL=\"%s\"\n' "$(escape_val "$IROOT_PARTITION_LABEL")"
        printf 'export IHOME_PARTITION_LABEL=\"%s\"\n' "$(escape_val "$IHOME_PARTITION_LABEL")"
        printf 'export IROOT_PARTITION_FSTYPE=\"%s\"\n' "$(escape_val "$IROOT_PARTITION_FSTYPE")"
        printf 'export IHOME_PARTITION_FSTYPE=\"%s\"\n' "$(escape_val "$IHOME_PARTITION_FSTYPE")"
        echo
        printf 'export IREFLECTOR_COUNTRY=\"%s\"\n' "$(escape_val "$IREFLECTOR_COUNTRY")"
        printf 'export IREFLECTOR_LATEST=\"%s\"\n' "$(escape_val "$IREFLECTOR_LATEST")"
        echo
        printf 'export IEFI_PARTITION=\"%s\"\n' "$(escape_val "$IEFI_PARTITION")"
        printf 'export IEFI_LINUX_DIRNAME=\"%s\"\n' "$(escape_val "$IEFI_LINUX_DIRNAME")"
        echo
        printf 'export IBOOTLOADER=\"%s\"\n' "$(escape_val "$IBOOTLOADER")"
        printf 'export ISYSTEMD_BOOT_ARCH_LABEL=\"%s\"\n' "$(escape_val "$ISYSTEMD_BOOT_ARCH_LABEL")"
        printf 'export ISYSTEMD_BOOT_EFI_LABEL=\"%s\"\n' "$(escape_val "$ISYSTEMD_BOOT_EFI_LABEL")"
        echo
        printf 'export IUKI_LABEL=\"%s\"\n' "$(escape_val "$IUKI_LABEL")"
        printf 'export IUKI_EXEC=\"%s\"\n' "$(escape_val "$IUKI_EXEC")"
        echo
        printf 'export IVISUDO_EDITOR=\"%s\"\n' "$(escape_val "$IVISUDO_EDITOR")"
        printf 'export IPYLOLCAT=\"%s\"\n' "$(escape_val "$IPYLOLCAT")"
    } > "$outfile"
    echo "Saved configuration to $outfile"
}

show_menu() {
    echo
    echo "Configuration menu:"
    echo "  Load: $CONFIG_IN"
    echo "  Save: $CONFIG_OUT"
    local idx=1
    for item in "${ITEMS[@]}"; do
        local name type label
        IFS='|' read -r name type label <<<"$item"
        local value="(unset)"
        if [[ "$type" == "array" ]]; then
            ensure_array "$name"
            local -n arr_ref="$name"
            value="${#arr_ref[@]} entries"
        elif [[ -v "$name" ]]; then
            value="${!name}"
        fi
        printf "  %2d) %-25s %s\n" "$idx" "$name" "$value"
        ((idx++))
    done
    echo "  p) Packages wizard"
    echo "  f) Change load/save files"
    echo "  s) Save and exit"
    echo "  q) Quit without saving"
}

main() {
    choose_defaults
    while true; do
        show_menu
        read -rp "Select item to edit: " choice
        case "${choice,,}" in
            p)
                bash "$SCRIPTDIR/packages-wizard.sh"
                ;;
            f)
                choose_defaults
                ;;
            s)
                write_config
                exit 0
                ;;
            q)
                echo "No changes saved."
                exit 0
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#ITEMS[@]})); then
                    edit_item "${ITEMS[choice-1]}"
                else
                    echo "Invalid selection."
                fi
                ;;
        esac
    done
}

main "$@"
