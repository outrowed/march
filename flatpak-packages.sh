#!/usr/bin/bash

## Flatpak system-wide packages
IFLATPAK_PACKAGES=(
    ## Theme
    org.gtk.Gtk3theme.Breeze

    ## Util
    # Camera
    org.kde.kamoso
    io.github.webcamoid.Webcamoid
    # Flatpak manager
    com.github.tchx84.Flatseal
    io.github.flattool.Warehouse
    # LAN / remote
    org.localsend.localsend_app
    com.moonlight_stream.Moonlight  # sunshine

    ## Multimedia
    org.kde.haruna
    com.github.wwmm.easyeffects

    ## Gaming + Windows compat
    com.valvesoftware.Steam
    com.usebottles.bottles
    net.davidotek.pupgui2
    com.github.Matoking.protontricks

    ## User
    com.bitwarden.desktop
    # ex: com.vscodium.codium -- AUR code code-features code-marketplace

    ## Internet social
    dev.vencord.Vesktop     # better discord
    org.kde.konversation
    org.kde.neochat
    # ex: com.ktechpit.whatsie -- whatsapp on web is just better

    ## Office
    org.libreoffice.LibreOffice
    org.kde.ghostwriter
    org.kde.okular

    ## Internet
    org.mozilla.firefox
    org.mozilla.Thunderbird
    io.github.ungoogled_software.ungoogled_chromium
    org.qbittorrent.qBittorrent
    org.kde.kget
    org.kde.alligator
    com.spotify.Client

    ## Creative & Graphics
    org.gimp.GIMP
    org.kde.krita
    org.kde.kdenlive
    com.obsproject.Studio
    org.blender.Blender
    org.inkscape.Inkscape
    org.kde.digikam

    ## Miscellaneous
    org.godotengine.Godot
)
