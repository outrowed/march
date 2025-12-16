#!/usr/bin/bash
# Unattend Arch by Outrowed

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
. "$SCRIPT_DIR/march-common.sh"
. "$SCRIPT_DIR/march-config.sh"

echo "Starting post-installation configuration..."

hwclock --systohc

## Configure UFW

if chkpkg ufw; then
    # Set default rules
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH
    ufw allow ssh

    # Allow KDE Connect
    ufw allow 1714:1764/udp
    ufw allow 1714:1764/tcp

    # Turn on the firewall
    ufw --force enable
fi

## kdenetwork-filesharing setup

if chkpkg samba; then
    mkdir -p /etc/samba

    # Default samba configuration
    cat <<EOF > /etc/samba/smb.conf
[global]
workgroup = $IHOSTNAME
server string = $ISUPER_USER's Samba Server
server role = standalone server

logging = systemd
EOF

    # Add user to sambashare
    groupadd -r sambashare 2>/dev/null || true
    gpasswd -a "$ISUPER_USER" sambashare

    # UFW
    if chkpkg ufw; then
        ufw allow CIFS
    fi

    # Enable samba services
    systemctl enable smb nmb
fi

## Sunshine setup

if chkpkg sunshine; then
    if chkpkg ufw; then
        # Allow sunshine through firewall
        ufw allow 47984/udp
        ufw allow 47989/tcp
    fi

    # KMS capture
    setcap cap_sys_admin+p "$(readlink -f "$(command -v sunshine)")"

    # Enable sunshine service
    systemctl enable --global sunshine
fi

## Branding (Topo OS)

apply_branding() {
    local assets_dir="/usr/local/share/topoos-assets"
    local brand_name="${IBRAND_NAME:-Topo OS}"
    local brand_id="${IBRAND_ID:-topo}"
    local brand_pretty="${IBRAND_PRETTY:-Topo OS}"
    local ply_bg="${IBRAND_PLYMOUTH_BG:-#111111}"
    local ply_fg="${IBRAND_PLYMOUTH_FG:-#f2f2f2}"

    if [[ ! -d "$assets_dir" ]]; then
        echo "Branding assets not found at $assets_dir; skipping branding."
        return
    fi

    echo "Applying branding for ${brand_pretty}..."

    # os-release
    for osrel in /etc/os-release /usr/lib/os-release; do
        [[ -f "$osrel" ]] || continue
        cp "$osrel" "$osrel.bak" || true
        sed -i \
            -e "s/^NAME=.*/NAME=\"${brand_name}\"/" \
            -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${brand_pretty}\"/" \
            "$osrel"
        if grep -q "^ID_LIKE=" "$osrel"; then
            sed -i "s/^ID_LIKE=.*/ID_LIKE=\"${IBRAND_ID_LIKE:-arch topo}\"/" "$osrel"
        else
            echo "ID_LIKE=\"${IBRAND_ID_LIKE:-arch topo}\"" >> "$osrel"
        fi
        # Leave ID untouched (defaults to 'arch') for repository compatibility.
    done

    # systemd-boot entry title (if present)
    if [[ -d /efi/loader/entries ]]; then
        for entry in /efi/loader/entries/*.conf; do
            [[ -f "$entry" ]] || continue
            sed -i "s/^title.*/title   ${brand_pretty}/" "$entry"
        done
    fi

    # Plymouth theme
    if chkpkg plymouth; then
        local ply_theme_dir="/usr/share/plymouth/themes/topoos"
        mkdir -p "$ply_theme_dir"
        local logo_src=""
        if [[ -f "$assets_dir/icon.png" ]]; then
            logo_src="$assets_dir/icon.png"
        elif [[ -f "$assets_dir/icon-wordmark.png" ]]; then
            logo_src="$assets_dir/icon-wordmark.png"
        fi
        if [[ -n "$logo_src" ]]; then
            cp "$logo_src" "$ply_theme_dir/logo.png"
        fi
        cat <<EOF > "$ply_theme_dir/topoos.plymouth"
[Plymouth Theme]
Name=Topo OS
Description=Topo OS Splash
ModuleName=script

[script]
ImageDir=$ply_theme_dir
ScriptFile=$ply_theme_dir/topoos.script
EOF
        cat <<'EOF' > "$ply_theme_dir/topoos.script"
if (FileExists(ImageDir + "/logo.png")) {
    wallpaper_image = Image("logo.png");
    message_sprite = Sprite(wallpaper_image);
}
progress = ProgressBar();
progress.SetPosition(Screen.Width * 0.25, Screen.Height * 0.8);
progress.SetSize(Screen.Width * 0.5, 10);
EOF
        plymouth-set-default-theme topoos || true
        if command -v mkinitcpio &>/dev/null; then
            plymouth-set-default-theme -R topoos || true
        fi
    fi

    # SDDM (Breeze) background
    if chkpkg sddm; then
        mkdir -p /etc/sddm.conf.d
        local bg="$assets_dir/wallpaper.png"
        if [[ -f "$assets_dir/wallpaper-dark.png" ]]; then
            bg="$assets_dir/wallpaper-dark.png"
        fi
        cat <<EOF > /etc/sddm.conf.d/10-topo.conf
[Theme]
Current=breeze
CursorTheme=breeze_cursors
Background=${bg}
EOF
    fi

    # Fastfetch logo
    local ff_logo_source=""
    local ff_logo_type="auto"
    if [[ -f "$assets_dir/icon.png" ]]; then
        mkdir -p /usr/share/fastfetch
        cp "$assets_dir/icon.png" /usr/share/fastfetch/logo.png
        ff_logo_source="/usr/share/fastfetch/logo.png"
    elif [[ -f "$assets_dir/icon-ascii.txt" ]]; then
        mkdir -p /usr/share/fastfetch
        cp "$assets_dir/icon-ascii.txt" /usr/share/fastfetch/logo.txt
        ff_logo_source="/usr/share/fastfetch/logo.txt"
    fi
    if [[ -n "$ff_logo_source" ]]; then
        mkdir -p /etc/fastfetch /etc/xdg/fastfetch /etc/fastfetch/presets /etc/skel/.config/fastfetch
        cat <<EOF | tee /etc/fastfetch/config.jsonc /etc/fastfetch/presets/default.jsonc /etc/xdg/fastfetch/config.jsonc > /etc/skel/.config/fastfetch/config.jsonc
{
    "logo": {
        "type": "${ff_logo_type}",
        "source": "${ff_logo_source}"
    },
    "modules": [
        "title",
        "os",
        "host",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "resolution",
        "de",
        "wm",
        "theme",
        "icons",
        "terminal",
        "cpu",
        "gpu",
        "memory"
    ]
}
EOF
    fi

    # System icons (About/launcher branding)
    if [[ -f "$assets_dir/icon.png" ]]; then
        for sz in 64 128 256 512; do
            mkdir -p "/usr/share/icons/hicolor/${sz}x${sz}/apps"
            cp "$assets_dir/icon.png" "/usr/share/icons/hicolor/${sz}x${sz}/apps/start-here-kde.png"
            cp "$assets_dir/icon.png" "/usr/share/icons/hicolor/${sz}x${sz}/apps/start-here.png"
        done
        mkdir -p /usr/share/pixmaps
        cp "$assets_dir/icon.png" /usr/share/pixmaps/archlinux-logo.png
        if command -v gtk-update-icon-cache &>/dev/null; then
            gtk-update-icon-cache -q /usr/share/icons/hicolor || true
        fi
    fi

    echo "Branding applied."
}

apply_branding

echo "Post-installation configuration completed."

exit 0
