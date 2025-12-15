# March Installer Overview

## What this repo is for
Scripts to install a full Arch Linux desktop (KDE Plasma by default) from an Arch ISO. The entrypoint is `install.sh`, which assumes the repo is run directly on the live ISO with network access.

## Inputs you must set
- `config.sh`: host/user names, timezone/locale, swap choice (`zram`, `swapfile`, or both), EFI partition path, bootloader (`systemd-boot` or `uki`), kernel cmdline, initramfs type.
- `packages.sh`: package groups for pacstrap, post-install pacman/AUR, and late/background installs.
- `flatpak-packages.sh`: system/user Flatpaks installed after first boot.
- `passwords/`: password hashes per user (`openssl passwd -6`). The filename may include extra groups (e.g., `alice+wheel,sambashare`).
- Wizards can author these files interactively: `config-wizard.sh`, `packages-wizard.sh`, `users-wizard.sh`.

## High-level flow (install.sh)
1) Connectivity + mirrors: pings archlinux.org and runs reflector with your country/latest settings.  
2) Disks: optional reformat of root/home (labels from `config.sh`), then mounts root→`/mnt`, home→`/mnt/home`, ESP→`/mnt/efi`, and bind-mounts `/mnt/boot` to the ESP subdir. `/mnt/boot` is wiped to avoid stale entries.  
3) Bootstrap: runs `pacstrap` with `IPACSTRAP_PACKAGES` unless `var/lib/march-install/pacstrap.done` exists. Creates `fstab`, hostname, timezone, locale, and keymap.  
4) Swap: builds zram and/or swapfile according to `ISWAP_TYPE`, wiring `fstab` and optional `resume=` args.  
5) Initramfs + kernel cmdline: writes mkinitcpio fragments (GPU/USB modules and HOOKS tuned for systemd or busybox init), regenerates initramfs, builds kernel cmdline (`root=UUID=…` + custom flags + optional zswap/resume).  
6) Bootloader: installs either `systemd-boot` (`install-systemd-boot.sh`) or UKI (`install-uki.sh`) into the ESP path in `config.sh`.  
7) Shell/user defaults: sets default shell to zsh for new users, appends quality-of-life aliases to `/etc/bash.bashrc`, ensures wheel sudo policy, then creates users from `passwords/` (prompts wizard if missing) and puts the main user into `wheel`.  
8) Pacman: enables color/parallel downloads, seeds reflector config.  
9) Paru + hooks: installs paru as the main user, installs pacman hooks (systemd-boot update, NVIDIA initramfs, arch-audit).  
10) Desktop + services: installs post-bootstrap packages via paru/pacman (`install-paru-packages-systemd.sh`), enables networking, display manager, audio, timers, and other services conditionally based on installed packages.  
11) First-boot tasks: installs two systemd oneshot services—`march-post-install-config.service` (firewall, samba, sunshine) and `march-post-install-packages.service` (late packages + flatpaks)—pointing to copies of the scripts under `/usr/local/sbin/`.  
12) Finish: reports completion; reboot into the installed system where the post-install services will run once.

## Post-boot behavior
- `march-post-install-config.service`: one-time system config (UFW, samba groups/config, sunshine caps/service).
- `march-post-install-packages.service`: waits for DNS, installs `ILATE_PACKAGES` via paru, sets up Flatpak remotes, and installs the defined system/user Flatpaks.

## Key directories and state
- `/mnt/var/lib/march-install/`: installation flags, currently `pacstrap.done`.
- `/mnt/etc/mkinitcpio.conf.d/`: module/HOOK fragments assembled during install.
- `/mnt/efi/EFI/$IEFI_LINUX_DIRNAME/`: boot artifacts (kernel, initramfs/UKI).
- `/usr/local/sbin/march-*.sh` (inside target): copies of config/common/scripts used by the post-install services.
