#!/usr/bin/bash

# wz-backup flatpak-packages.sh.bak

## Flatpak system-wide packages
IFLATPAK_SYSTEM_PACKAGES=(
    ## Theme
    org.gtk.Gtk3theme.Breeze

    ## Util
    # Admin
    io.github.mfat.sshpilot
    # Security
    org.cryptomator.Cryptomator
    # Camera
    org.kde.kamoso
    io.github.webcamoid.Webcamoid
    # File / tools
    io.github.cboxdoerfer.FSearch
    io.gitlab.adhami3310.Converter
    # Flatpak manager
    com.github.tchx84.Flatseal
    io.github.flattool.Warehouse
    # LAN / remote
    org.localsend.localsend_app
    com.moonlight_stream.Moonlight  # sunshine
    # Devel
    com.gitbutler.gitbutler
    io.dbeaver.DBeaverCommunity
    org.kde.kdiff3
    org.kde.kompare
    org.octave.Octave

    ## Multimedia
    org.kde.haruna
    com.github.wwmm.easyeffects
    org.tenacityaudio.Tenacity
    com.github.marinm.songrec
    no.mifi.losslesscut

    ## Gaming + Windows compat
    com.valvesoftware.Steam
    com.usebottles.bottles
    net.davidotek.pupgui2
    com.github.Matoking.protontricks
    com.vysp3r.ProtonPlus
    org.prismlauncher.PrismLauncher
    org.vinegarhq.Sober

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
    one.ablaze.floorp
    # ex: org.mozilla.firefox -- replaced with one.ablaze.floorp
    org.mozilla.Thunderbird
    es.danirod.Cartero
    # ex: io.github.ungoogled_software.ungoogled_chromium -- helium-browser-bin in IAUR_PACKAGES
    org.qbittorrent.qBittorrent
    org.kde.kget
    org.kde.alligator

    ## Creative & Graphics
    org.gimp.GIMP
    com.github.PintaProject.Pinta
    org.kde.krita
    org.kde.kdenlive
    com.obsproject.Studio
    org.blender.Blender
    org.inkscape.Inkscape
    org.kde.digikam
    
    ## Miscellaneous
    info.febvre.Komikku
    org.godotengine.Godot
    com.bitwarden.desktop
)

## Flatpak main user packages
IFLATPAK_USER_PACKAGES=(
    com.spotify.Client
    # opt: dev.diegovsky.Riff -- spotify backend, requires spotify premium
    # ex: com.vscodium.codium -- AUR code code-features code-marketplace
)
