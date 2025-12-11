#!/usr/bin/bash

# wz-backup flatpak-packages.sh.bak

## Flatpak system-wide packages
IFLATPAK_SYSTEM_PACKAGES=(
    ## Theme
    org.gtk.Gtk3theme.Breeze

    ## Util
    # Admin
    # opt: io.github.mfat.sshpilot
    # Camera
    org.kde.kamoso
    io.github.webcamoid.Webcamoid
    # Flatpak manager
    com.github.tchx84.Flatseal
    io.github.flattool.Warehouse
    # LAN / remote
    org.localsend.localsend_app
    com.moonlight_stream.Moonlight  # sunshine
    # Devel
    org.kde.kdiff3
    org.kde.kompare

    ## Multimedia
    org.kde.haruna
    com.github.wwmm.easyeffects
    org.tenacityaudio.Tenacity

    ## Gaming + Windows compat
    com.valvesoftware.Steam
    com.usebottles.bottles
    net.davidotek.pupgui2
    com.github.Matoking.protontricks

    ## Office
    org.libreoffice.LibreOffice
    org.kde.ghostwriter
    org.kde.okular
    org.gnome.gitlab.ilhooq.Bookup

    ## Internet social
    dev.vencord.Vesktop     # better discord
    org.kde.konversation
    org.kde.neochat

    ## Internet
    org.mozilla.firefox
    org.mozilla.Thunderbird
    # ex: io.github.ungoogled_software.ungoogled_chromium -- helium-browser-bin in IAUR_PACKAGES
    org.qbittorrent.qBittorrent
    org.kde.kget
    org.kde.alligator

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
    com.bitwarden.desktop
)

## Flatpak main user packages
IFLATPAK_USER_PACKAGES=(
    # opt: io.github.giantpinkrobots.varia -- download manager
    # opt: com.github.marinm.songrec -- unofficial Shazam client (song recognition) app
    # opt: com.spotify.Client -- normal spotify
    # opt: dev.diegovsky.Riff -- spotify backend, requires spotify premium
    # ex: com.vscodium.codium -- AUR code code-features code-marketplace
)
