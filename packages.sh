#!/usr/bin/bash

## Installation packages
IPACSTRAP_PACKAGES=(
    ## Base System & Microcode
    base
    linux
    linux-firmware
    base-devel
    intel-ucode
    amd-ucode

    ## Partition & Filesystem Tools
    efibootmgr
    efivar
    btrfs-progs
    ntfs-3g
    dosfstools
    e2fsprogs
    parted

    ## Admin & System Utilities
    sudo
    openssh
    openssl
    git
    curl
    nano
    vim
    man-db
    man-pages
    bash-completion
    less
    gzip
    gparted
    xz
    zip
    unzip
    linux-headers
    htop
    fwupd           # Firmware updates
    fastfetch
    rsync
    smartmontools
    timeshift
    plocate         # "everything" in linux
    plymouth        # boot startup
    zsh
    zram-generator
    arch-audit-gtk

    ## Network
    systemd-resolvconf
    networkmanager
    wireguard-tools
    ufw                     # firewall
    network-manager-applet
    inetutils
    openbsd-netcat
    wget
    kdenetwork-filesharing
    iwd
    wireless_tools
    wpa_supplicant
    bluez                   # bluetooth support
    bluez-utils
    avahi                   # Network discovery (mDNS/Bonjour)
    nss-mdns                # Hostname resolution for .local domains

    ## Pacman Utilities
    pacman-contrib
    reflector
    arch-audit

    ## Development Tools
    python
    shellcheck
    gcc
    make
    cmake
    pkgconf
    git-lfs
    jq
    go

    ## Multimedia & Audio
    mpv
    vlc
    ffmpeg
    ffmpegthumbs
    pipewire
    wireplumber
    pipewire-jack
    pipewire-pulse
    pipewire-alsa
    phonon-qt6-vlc
    alsa-utils
    gst-plugin-pipewire
    pavucontrol
    sof-firmware
    alsa-firmware

    ## Generic GPU Drivers
    mesa

    ## NVIDIA Drivers
    nvidia
    nvidia-utils
    nvidia-settings

    ## Zsh Plugins / Configs
    zsh-completions
    zsh-syntax-highlighting
    zsh-autosuggestions
    grml-zsh-config         # Recommendation per https://wiki.archlinux.org/title/Zsh#Sample_.zshrc_files
)

## Post install Pacman packages
# massive packages that are not that "important" for the base installation
IPACMAN_PACKAGES=(
    ## System Utilities
    nvtop
    iotop

    ## Generic GPU Drivers
    vulkan-icd-loader

    ## NVIDIA Drivers
    nvidia-prime
    cuda            # here's the big boi

    ## Intel Drivers
    intel-media-driver
    vulkan-intel

    ## AMD Drivers
    libva-mesa-driver
    mesa-vdpau
    vulkan-radeon

    ## Desktop Environment (KDE Plasma)
    xorg-xwayland
    sddm
    sddm-kcm
    plymouth-kcm
    plasma-meta
    kde-accessibility
    kde-system
    kde-utilities
    kio-admin
    kio-extras
    kio-gdrive
    kio-zeroconf
    krdc
    # kde-network
    # kde-office
    # kde-multimedia
    kde-graphics
    breeze
    xdg-utils
    trash-cli
    iio-sensor-proxy
    bolt
    plasma-thunderbolt

    ## Localization
    hunspell
    hyphen

    ## Development Tools (post install)
    nodejs
    npm
    pnpm

    ## User Applications
    flatpak
    bat
    fuse3
    syncthing
    yt-dlp

    ## Fonts
    ttf-dejavu
    ttf-liberation
    ttf-roboto
    ttf-cascadia-code
    ttf-jetbrains-mono
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    otf-font-awesome

    ## Virtualization
    qemu-desktop
    virt-manager
    libvirt
    edk2-ovmf
    dnsmasq
    virt-viewer
    dmidecode

    ## Printing Support
    cups                            # The core printing system
    cups-pdf                        # Print to PDF support
    gutenprint                      # High-quality drivers for Canon, Epson, etc.
    foomatic-db-gutenprint-ppds     # PPD files for Gutenprint
    hplip                           # Drivers for HP printers
)

## AUR packages
IAUR_PACKAGES=(
    ## System Utilities
    timeshift-systemd-timer
    topgrade
    needrestart
)

## Late AUR / Pacman packages (need user to build)
ILATE_PACKAGES=(
    ## Utilities
    maliit-keyboard
    ventoy-bin

    ## Applications
    sunshine-bin    # moonlight
)