#!/usr/bin/bash

## Pacstrap packages
# essential packages for "comfortable but minimal" base Arch Linux installation
# -- that may be used for rescue or recovery mode
# anything that would make sense for DE is not included here, instead in later IPACMAN_PACKAGES, IAUR_PACKAGES, or ILATE_PACKAGES
# minimize the download/installation time
IPACSTRAP_PACKAGES=(
    ## System + microcode
    base
    linux
    linux-firmware
    intel-ucode
    amd-ucode
    # Extra
    base-devel
    linux-headers
    zram-generator
    plymouth        # boot startup

    ## Partition + FS
    # EFI
    efibootmgr
    efivar
    # FS
    btrfs-progs
    ntfs-3g
    dosfstools
    e2fsprogs
    # Partition
    parted
    gptfdisk

    ## Admin
    sudo
    openssh
    openssl
    # System info
    btop            # alternative to htop
    fwupd           # firmware updates
    fastfetch
    # Z shell
    zsh
    zsh-completions
    zsh-syntax-highlighting
    zsh-autosuggestions
    grml-zsh-config         # ArchISO Zsh Config per https://wiki.archlinux.org/title/Zsh#Sample_.zshrc_files
    # Bash
    bash
    bash-completion
    bash-language-server
    # Remote downloader
    git
    curl
    wget
    rsync
    # Text editor
    nano
    vim
    # Text util
    man-db
    man-pages
    less
    dos2unix    # convert CRLF to LF
    # Archival
    gzip
    xz
    zip
    unzip
    # FS listing / finder
    tree
    plocate         # "everything" file finder in linux

    ## Network
    # Core
    systemd-resolvconf
    networkmanager
    ufw                 # firewall
    # Utils
    inetutils
    openbsd-netcat
    nmap
    speedtest-cli
    # Wireless
    iwd
    wireless_tools
    wpa_supplicant
    # Bluetooth
    bluez               # bluetooth support
    bluez-utils
    # Extra
    wireguard-tools

    ## Pacman extra
    pacman-contrib
    reflector
    arch-audit

    ## Devel
    python
    shellcheck
    gcc
    make
    cmake
    pkgconf
    git-lfs
    jq
    go

    ## Multimedia
    ffmpeg

    ## Audio firmware
    sof-firmware
    alsa-firmware

    ## Generic GPU
    mesa

    ## NVIDIA
    nvidia
    nvidia-utils
    nvidia-settings
)

## Pre-Pacman packages
# packages that are before IPACMAN_PACKAGES
# usually this is required because of dependency conflict and explicitly choosing which one to install
IPREPACMAN_PACKAGES=(
    ## Audio
    pipewire
    wireplumber
    pipewire-jack
    pipewire-pulse
    pipewire-alsa
    phonon-qt6-vlc
    alsa-utils
    gst-plugin-pipewire
    pavucontrol
)

## Pacman packages
# packages installed after the base system installation
# usually this is where DE and graphical related things are installed
IPACMAN_PACKAGES=(
    ## Generic GPU/CPU
    vulkan-icd-loader
    vulkan-swrast                   # Vulkan Software Rasterizer (CPU)
    # ex: vulkan-mesa-device-select -- conflict with vulkan-mesa-implicit-layers

    ## NVIDIA
    nvidia-prime
    # ex: cuda -- added in ILATE_PACKAGES

    ## Intel
    intel-media-driver
    vulkan-intel

    ## AMD
    libva-mesa-driver
    vulkan-radeon

    ## Thunderbolt
    bolt

    ## Admin
    gparted
    smartmontools
    nvtop
    iotop
    vulkan-tools
    # ex: timeshift

    ## Desktop Environment (KDE Plasma)
    # Core
    sddm
    plasma-meta
    xorg-xwayland
    # Extra
    kde-accessibility
    kde-system
    kde-utilities
    kde-graphics
    # ex: kde-network
    # ex: kde-office
    # ex: kde-multimedia
    # KCM
    sddm-kcm
    plymouth-kcm
    # KIO
    kio-admin
    kio-extras
    kio-gdrive
    kio-zeroconf
    # Theme
    breeze
    # Remote
    krdc
    # Plugin + integration
    kdenetwork-filesharing
    plasma-thunderbolt

    ## Generic DE
    wl-clipboard
    xdg-utils
    trash-cli
    iio-sensor-proxy
    # Extra
    network-manager-applet
    arch-audit-gtk

    ## Audio player
    mpv
    vlc

    ## Multimedia
    ffmpegthumbs

    ## Network
    avahi       # Network discovery (mDNS/Bonjour)
    nss-mdns    # Hostname resolution for .local domains

    ## Localization
    hunspell
    hyphen

    ## Devel
    # AUR VSCode
    code
    code-features
    code-marketplace
    # NodeJS
    nodejs
    npm
    pnpm

    ## Package manager
    flatpak     # mostly user-space GUI-based applications

    ## User software
    syncthing   # syncthing
    yt-dlp      # youtube download
    bat         # cat clone
    fuse3       # Filesystem in Userspace -- mount filesystem without root

    ## Fonts
    ttf-dejavu
    ttf-liberation
    ttf-roboto
    gnu-free-fonts
    ttf-ms-fonts
    noto-fonts
    noto-fonts-cjk
    # Emoji / custom icon
    noto-fonts-emoji
    nerd-fonts
    otf-font-awesome
    # Mono
    ttf-jetbrains-mono
    ttf-cascadia-code
    # Bitmap
    bdf-unifont

    ## Virtualization
    qemu-desktop    # QEMU setup for desktop environment
    virt-manager    # GUI front end for virtualization
    libvirt         # virtualizatin API
    edk2-ovmf       # UEFI firmware for virtual machines
    virt-viewer     # graphical display required by virt-manager
    
    ## Virtualization utility
    dnsmasq         # DNS + DHCP server
    dmidecode       # system hardware report via SMBIOS/DMI standard

    ## Print support
    cups                        # The core printing system
    cups-pdf                    # Print to PDF support
    gutenprint                  # High-quality drivers for Canon, Epson, etc.
    foomatic-db-gutenprint-ppds # PPD files for Gutenprint
    hplip                       # Drivers for HP printers
)

## AUR packages
# run with no password sudo
IAUR_PACKAGES=(
    needrestart # automatically restart daemon after library update
    # ex: timeshift-systemd-timer
)

## Late AUR / Pacman packages
# some packages have very long compile time and thus needs to be deferred / ran in background after KDE Plasma installation
ILATE_PACKAGES=(
    cuda                # big boi NVIDIA driver
    maliit-keyboard     # virtual keyboard
    topgrade            # all-in-one universal system upgrade
    sunshine-bin        # remote server
    ventoy-bin          # ventoy bootloader
    archiso             # archiso creation
    optimus-manager-git # NVIDIA optimus manager
)