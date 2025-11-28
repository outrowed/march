#!/usr/bin/bash

# Shared helpers for interactive wizards (arrays, escaping).

. "$(dirname ${BASH_SOURCE[0]})"/common.sh

escape_val() {
    local val="$1"
    val=${val//\\/\\\\}
    val=${val//\"/\\\"}
    printf '%s' "$val"
}

ensure_array() {
    local name="$1"
    if ! declare -p "$name" &>/dev/null; then
        eval "$name=()"
    fi
}

edit_array() {
    local name="$1" label="${2:-List}"
    ensure_array "$name"
    local -n arr="$name"
    while true; do
        echo
        echo "$label:"
        if ((${#arr[@]} == 0)); then
            echo "  (empty)"
        else
            local idx=1
            for item in "${arr[@]}"; do
                printf "  %2d) %s\n" "$idx" "$item"
                ((idx++))
            done
        fi
        echo "Options: [a]dd  [r]emove  [d]one"
        read -rp "Choose: " choice
        case "${choice,,}" in
            a)
                read -rp "Enter value to add: " new_item
                [[ -z "$new_item" ]] && echo "Nothing added." && continue
                arr+=("$new_item")
                ;;
            r)
                read -rp "Enter number to remove: " num
                if [[ "$num" =~ ^[0-9]+$ ]] && ((num>=1 && num<=${#arr[@]})); then
                    arr=("${arr[@]:0:num-1}" "${arr[@]:num}")
                else
                    echo "Invalid selection."
                fi
                ;;
            d)
                break
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    done
}

write_array() {
    local name="$1"
    ensure_array "$name"
    local -n arr="$name"
    printf '%s=(\n' "$name"
    for item in "${arr[@]}"; do
        local escaped
        escaped=$(escape_val "$item")
        printf '    \"%s\"\n' "$escaped"
    done
    printf ')\n\n'
}

prompt_file() {
    local prompt="$1" default_path="$2" out_var="$3"
    local default_name
    default_name="$(basename "$default_path")"
    read -rp "$prompt (default: $default_name): " path
    if [[ -z "$path" ]]; then
        path="$default_path"
    fi
    [[ "$path" = /* ]] || path="$PWD/$path"
    printf -v "$out_var" '%s' "$path"
}

choose_defaults_common() {
    local canonical="$1"
    local generated="$2"
    local prompt_load="$3"
    local prompt_save="$4"
    local out_load="$5"
    local out_save="$6"

    local load_default="$canonical"
    local save_default="$generated"

    if [[ -f "$generated" ]]; then
        load_default="$generated"
    fi
    if [[ ! -f "$generated" ]]; then
        save_default="$canonical"
    fi

    prompt_file "$prompt_load" "$load_default" "$out_load"
    prompt_file "$prompt_save" "$save_default" "$out_save"
}
