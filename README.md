# march

*Another Arch Linux installation script*

Opiniated Arch Linux installation script (for personal use).

It reformats partitions, bootstraps the system, installs a desktop stack, and sets up post-boot tasks.

## Disclaimer
* **It will reformat partitions** labeled in [`config.sh`](config.sh) (`IROOT_PARTITION_LABEL`, `IHOME_PARTITION_LABEL`). Only [ext4](https://wiki.archlinux.org/title/ext4) is supported for now.
* Requires internet ([pacman mirror](https://wiki.archlinux.org/title/Reflector) & packages installation).
* Not fully unattended; prompts remain (e.g., paru password, confirmation before formatting).

## What it does
* Mounts [ESP](https://wiki.archlinux.org/title/EFI_system_partition), root, and home partitions by label, pacstraps base and configured packages in [`packages.sh`](./packages.sh), sets hostname, locale, timezone, and keymap.
* Sets up [systemd-boot](https://wiki.archlinux.org/title/systemd-boot) or [unified kernel image (UKI)](https://wiki.archlinux.org/title/Unified_kernel_image).
* Creates users from hashed passwords in [`passwords/`](passwords/).
* Installs AUR helper ([paru](https://github.com/Morganamilo/paru)), pacman hooks, and systemd services.
* Post-installation systemd services, packages, and [flatpak](https://wiki.archlinux.org/title/Flatpak) applications.

## Configure before running
* [`config.sh`](config.sh): host/user names, timezone/locale, partition labels, EFI path (`IEFI_DEVICE_FULL`), bootloader choice (`IBOOTLOADER=systemd-boot|uki`).
* [`packages.sh`](packages.sh): base/pacman/AUR/late package selections.
* [`flatpak-packages.sh`](flatpak-packages.sh): flatpaks to install post-boot.
* [`users-gen.sh`](users-gen.sh): generate hashed passwords into [`passwords/`](passwords/) (`filename` = username or `username+groups`; contents from `openssl passwd -6`).

## Quickstart
1) Boot Arch ISO with internet.
2) Clone this repo into the live environment.
3) Adjust [`config.sh`](config.sh), [`packages.sh`](packages.sh), [`flatpak-packages.sh`](flatpak-packages.sh).
4) Generate users: [`./users-gen.sh`](users-gen.sh) (creates [`passwords/`](passwords/) entries).
5) Run the installer: [`./install.sh`](install.sh) (will prompt before formatting and during paru build).
6) Reboot into the installed system; post-install services will finish remaining packages/flatpaks.

## Post-boot services
* `march-post-install-config.service`: one-time system config (firewall, samba groups, etc.).
* `march-post-install-packages.service`: late paru packages + flatpaks.

## Notes
* Bootloaders: `IBOOTLOADER=systemd-boot` or `uki`; EFI device set from `IEFI_DEVICE_FULL`.
* GPU: installs NVIDIA, AMD, and Intel GPU stack by default; adjust in `packages.sh` if not needed.
* Security: temporary passwordless sudo is used during paru installation and then removed.

## License

GPLv2 or later (see [`COPYING`](COPYING)).
