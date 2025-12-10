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
* [`config.sh`](config.sh): host/user names, timezone/locale, partition labels, EFI path (`IEFI_PARTITION`), bootloader choice (`IBOOTLOADER=systemd-boot|uki`), swap (`ISWAP_TYPE=zram|swapfile`, defaults to zram).
* [`packages.sh`](packages.sh): base/pacman/AUR/late package selections. Late packages are installed after the system is fully installed (after base, pacman, and AUR packages).
* [`flatpak-packages.sh`](flatpak-packages.sh): flatpaks to install post-boot.
* You can use the interactive wizard to generate the configs: [`./config-wizard.sh`](config-wizard.sh) (defaults to `config-user.sh` when saving) and [`./packages-wizard.sh`](packages-wizard.sh) (defaults to `packages-user.sh` / `flatpak-packages-user.sh` when saving).
* [`users-wizard.sh`](users-wizard.sh): generate hashed passwords into [`passwords/`](passwords/) (`filename` = username or `username+groups`; contents from `openssl passwd -6`).

## Quickstart
1. Boot Arch ISO with internet.
1. Install `git` by `pacman -Sy git`.
1. Clone this repo into the live environment.
1. Make scripts executable: `chmod +x *.sh`.
1. Adjust [`config.sh`](config.sh), [`packages.sh`](packages.sh), [`flatpak-packages.sh`](flatpak-packages.sh) (or use the wizards: [`./config-wizard.sh`](config-wizard.sh), [`./packages-wizard.sh`](packages-wizard.sh)).
1. Generate users: [`./user-wizard.sh`](user-wizard.sh) (creates [`passwords/`](passwords/) entries).
1. Run the installer: [`./install.sh`](install.sh) (will prompt before formatting and during paru build).
1. Reboot into the installed system; post-install services will finish remaining packages/flatpaks.

## Calamares ISO (mkarchiso)
* Calamares still needs to be built from AUR; drop `calamares-*.pkg.tar.zst` into `archiso/localrepo/`, or let `MARCH_BUILD_CALAMARES_AUR=1 archiso/build-archiso.sh` build it (requires `git`, `base-devel`, and network to fetch deps).
* Build: `archiso/build-archiso.sh` (prefers `packages-user.sh` / `flatpak-packages-user.sh` when present). It regenerates `archiso/packages.x86_64`, syncs this repo into the ISO at `/opt/march`, wires `archiso/localrepo/` if needed, and runs `mkarchiso` (output in `archiso/out/`). Set `SKIP_MKARCHISO=1` to only regenerate configs/sync files.
* Live session: autologins `liveuser` into Plasma and auto-starts Calamares.
  * GUI modules handle locale, keyboard, partitioning, users, bootloader, and services.
  * `shellprocess@march-pacstrap` runs `/usr/local/bin/march-calamares-pacstrap` (pacstrap using `packages.sh`/`packages-user.sh`, then installs pacman hooks + first-boot services into the target).
  * `shellprocess@march-postinstall` runs inside the target and wires the march post-install services (`post-install-config`, `post-install-packages`, Flatpak install, late AUR/paru bootstrap).
* Package lists (`packages.sh` / `flatpak-packages.sh`) are respected; packages not in the repos (AUR) are skipped during pacstrap and handled later by the post-install services once paru is available.

## Post-boot services
* `march-post-install-config.service`: one-time system config (firewall, samba groups, etc.).
* `march-post-install-packages.service`: late paru packages + flatpaks.

## Notes
* Bootloaders: `IBOOTLOADER=systemd-boot` or `uki`; EFI device set from `IEFI_PARTITION`.
* GPU: installs NVIDIA, AMD, and Intel GPU stack by default; adjust in `packages.sh` if not needed.
* Security: temporary passwordless sudo is used during paru installation and then removed.

## License

GPLv2 or later (see [`COPYING`](COPYING)).
