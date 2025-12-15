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
    groupadd -r sambashare
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
    if [[ -f /etc/os-release ]]; then
        cp /etc/os-release /etc/os-release.bak || true
        sed -i \
            -e "s/^NAME=.*/NAME=\"${brand_name}\"/" \
            -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${brand_pretty}\"/" \
            /etc/os-release
        if grep -q "^ID_LIKE=" /etc/os-release; then
            sed -i "s/^ID_LIKE=.*/ID_LIKE=\"${IBRAND_ID_LIKE:-arch topo}\"/" /etc/os-release
        else
            echo "ID_LIKE=\"${IBRAND_ID_LIKE:-arch topo}\"" >> /etc/os-release
        fi
        # Leave ID untouched (defaults to 'arch') for repository compatibility.
    fi

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
        if [[ -f "$assets_dir/icon.png" ]]; then
            cp "$assets_dir/icon.png" "$ply_theme_dir/logo.png"
        elif [[ -f "$assets_dir/icon-wordmark.png" ]]; then
            cp "$assets_dir/icon-wordmark.png" "$ply_theme_dir/logo.png"
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
wallpaper_image = Image("logo.png");
message_sprite = Sprite(wallpaper_image);
progress = ProgressBar();
progress.SetPosition(Screen.Width * 0.25, Screen.Height * 0.8);
progress.SetSize(Screen.Width * 0.5, 10);
EOF
        cat <<EOF > /etc/plymouth/plymouthd.conf
[Daemon]
Theme=topoos
ShowDelay=0
DeviceTimeout=8
BackgroundColor=${ply_bg}
ForegroundColor=${ply_fg}
EOF
        plymouth-set-default-theme -R topoos || true
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

    # KDE wallpaper defaults (system-wide)
    local wp_dir="/usr/share/wallpapers/TopoOS"
    mkdir -p "$wp_dir/contents/images"
    if [[ -f "$assets_dir/wallpaper.png" ]]; then
        cp "$assets_dir/wallpaper.png" "$wp_dir/contents/images/3840x2160.png"
        cp "$assets_dir/wallpaper.png" "$wp_dir/contents/images/1920x1080.png"
    fi
    if [[ -f "$assets_dir/wallpaper-dark.png" ]]; then
        cp "$assets_dir/wallpaper-dark.png" "$wp_dir/contents/images/3840x2160-dark.png"
        cp "$assets_dir/wallpaper-dark.png" "$wp_dir/contents/images/1920x1080-dark.png"
    fi
    cat <<EOF > "$wp_dir/metadata.desktop"
[Desktop Entry]
Name=TopoOS
X-KDE-PluginInfo-Name=TopoOS
X-KDE-PluginInfo-Author=Topo Team
X-KDE-PluginInfo-Category=Wallpaper
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=CC-BY
X-Plasma-Wallpaper-MainImage=contents/images/1920x1080.png
EOF

    # Plasma look-and-feel default wallpaper (Breeze)
    local lnf_defaults="/usr/share/plasma/look-and-feel/org.kde.breeze.desktop/contents/defaults"
    if [[ -f "$lnf_defaults" ]]; then
        cp "$lnf_defaults" "${lnf_defaults}.bak" || true
    fi
    mkdir -p "$(dirname "$lnf_defaults")"
    cat <<EOF > "$lnf_defaults"
[Wallpaper]
Image=file://$wp_dir/contents/images/1920x1080.png
EOF

    # Fastfetch logo
    if [[ -f "$assets_dir/icon-ascii.txt" ]]; then
        mkdir -p /usr/share/fastfetch
        cp "$assets_dir/icon-ascii.txt" /usr/share/fastfetch/logo.txt
        mkdir -p /etc/fastfetch
        cat <<EOF > /etc/fastfetch/config.jsonc
{
    "logo": {
        "source": "/usr/share/fastfetch/logo.txt"
    }
}
EOF
    fi

    echo "Branding applied."
}

apply_branding

echo "Post-installation configuration completed."

exit 0
