# Usage Guide

## Main installer (install.sh)
- Run from repo root on a live Arch ISO: `sudo ./install.sh`.
- Prompts before formatting and pacstrap; uses `config.sh` for host/user/locale/bootloader/swap settings.
- High-level flow:
  1) Mirror setup: reflector updates `/etc/pacman.d/mirrorlist`.
  2) Partitioning/mount: optional reformat/mount helpers; cleans `/mnt/boot`.
  3) Pacstrap: seeds pacman cache if available, installs base packages from packages.sh into `/mnt` (idempotent via `pacstrap.done`).
  4) System config: writes fstab, hostname, locale (locale.gen, locale.conf), keymap.
  5) Swap: supports `zram`, `swapfile`, or `zram+swapfile`; creates swapfile, sets priorities, captures `resume` args.
  6) Initramfs: drops mkinitcpio fragments (modules), sets HOOKS based on initramfs type, rebuilds.
  7) Bootloader: installs systemd-boot or UKI preset with cmdline from `root=UUID` + IKERNEL_CMDLINE (+ zswap/resume when applicable).
  8) Users/sudo: configures sudoers, creates users from `passwords/`, ensures main user in wheel.
  9) Pacman tweaks: color, parallel downloads, reflector config.
  10) AUR helper: builds `yay-bin` (aliased to `paru`).
  11) Hooks/services: installs pacman hooks, then runs post-bootstrap package/service setup.
  12) First-boot tasks: enables services to install late packages/Flatpaks and apply branding.

## Config (config.sh) and front-end (installer.py)
- `config.sh` holds install inputs (hostname, user, partitions, swap type, bootloader, kernel cmdline, branding defaults).
- `installer.py` is an interactive CLI editor for common fields: hostname, default locale, main user (`ISUPER_USER`), swap type, partition labels/EFI path, and user password entries. It merges changes into `config.sh` without dropping unrelated values. Run: `python3 installer.py`.
- Branding values live in `config.sh` (`IBRAND_*`) and are applied automatically post-install; installer UI doesn’t expose them.

## Auto partitioner (`auto-partition.py`)
- Creates partitions on an empty disk: `sudo python3 auto-partition.py /dev/sdX [root_percent] [--add-efi=sizeMiB]`.
- Wipes the disk, makes GPT, optional FAT32 ESP, ext4 root/home with labels from `config.sh`. Root% defaults to 60; rest to home.
- Requires ext4 root/home; aborts if existing partitions are present.

## ISO builder (`build-iso.sh`)
- Builds a releng-based Arch ISO with this repo preloaded to `/root/march` and git added.
- Usage: `sudo ./build-iso.sh` (env: `WORKDIR`, `OUTDIR`, `ISO_LABEL`, `CACHE_SRC`).
- Cleans previous work/output, seeds pacman cache into the ISO if available or prefetchable, then runs `mkarchiso`.

## Pacman cache prefetch (`generate-pacman-cache.sh`)
- Pre-downloads repo packages defined in `packages.sh` into a cache directory (default `./cache/pacman`).
- Usage: `sudo ./generate-pacman-cache.sh [cache_dir]`.
- Skips AUR packages by design; installer consumes this cache automatically.

## Bootstrap helpers
- `install-post-install-setup.sh`: Copies helper scripts and branding assets into the target under `/usr/local/sbin` and `/usr/local/share`, and installs/ enables two one-shot services for first boot:
  - `march-post-install-config.service` → runs `post-install-config.sh` (firewall, Samba tweaks, Sunshine, branding, fastfetch/plasma/plymouth/sddm icons/wallpapers).
  - `march-post-install-packages.service` → runs `post-install-packages.sh` (late packages + Flatpaks) after network-online.
- `install-paru.sh`: Builds and installs `yay-bin` inside the target (as main user via temporary passwordless sudo), then symlinks `/usr/bin/paru` → `/usr/bin/yay` for compatibility; pulls in `go` as a build dep.
- `install-paru-packages-systemd.sh`: From outside the chroot, runs two `arch-chroot ... sudo -u "$ISUPER_USER" yay -Syu ...` batches to install pre-pacman and pacman/AUR packages (from `packages.sh`), then conditionally enables services/timers (timesyncd, sshd, systemd-boot-update, resolved/NetworkManager DNS, ufw, bluetooth, sddm, pipewire stack, oomd, fwupd, autorotate, bolt, fstrim, man/plocate, reflector, paccache) if installed.
