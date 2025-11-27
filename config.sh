#!/usr/bin/bash

export ISUPER_USER=outrowed
export IHOSTNAME=archie

export ITIMEZONE=Asia/Singapore
ILOCALE_GEN_LIST=(
    en_US.UTF-8
    en_GB.UTF-8
    en_IE.UTF-8
    en_DK.UTF-8
    ja_JP.UTF-8
    ja_JP.EUC-JP
    ko_KR.UTF-8
    zh_CN.UTF-8
    zh_TW.UTF-8
    zh_HK.UTF-8
    zh_SG.UTF-8
)
ILOCALE_CONF=(
    "LANG=en_US.UTF-8"
    "LANGUAGE=en_GB:en:C"
    "LC_TIME=en_DK.UTF-8"
    "LC_MEASUREMENT=en_GB.UTF-8"
)    
export IKEYMAP=us
export INTP="0.arch.pool.ntp.org 1.arch.pool.ntp.org"
export INTP_FALLBACK="0.pool.ntp.org 1.pool.ntp.org"

export IROOT_PARTITION_LABEL=arch-linux-root
# Only ext4 is supported by the current formatter; keep this as ext4.
export IROOT_PARTITION_FSTYPE=ext4
export IHOME_PARTITION_LABEL=arch-linux-home
# Only ext4 is supported by the current formatter; keep this as ext4.
export IHOME_PARTITION_FSTYPE=ext4

export IREFLECTOR_COUNTRIES="Singapore"

# EFI System Partition location
export IEFI_DEVICE_FULL=/dev/nvme0n1p1
export IEFI_DEVICE=/dev/nvme0n1
export IEFI_PARTITION_INDEX=1
export IEFI_LINUX_DIRNAME="Arch Linux"

export IBOOTLOADER=systemd-boot

export ISYSTEMD_BOOT_ARCH_LABEL="Arch Linux"
export ISYSTEMD_BOOT_EFI_LABEL="Arch Linux Boot Manager"

export IUKI_LABEL="Arch Linux"
export IUKI_EXEC=arch.efi

# Path for visudo editor
export IVISUDO_EDITOR=/usr/bin/nano

# Install pylolcat for funzies
export IPYLOLCAT=true
