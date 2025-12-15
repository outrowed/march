# Script Inventory and Interactions

This repository is mostly shell scripts run directly from the live Arch ISO. They assume the repo is the working directory (`common.sh` enforces this unless running as a systemd service). Below are the roles and linkages.

## Shared foundations
- `common.sh`: defensive shell settings, run-directory guard, helpers (retry, prompt, autosudo, package checkers, root UUID discovery, EFI device derivation). Sourced by most scripts.
- `config.sh`: installer inputs (usernames, locale/timezone, partition labels/paths, swap, bootloader, kernel cmdline). Wizards can generate `config-user.sh` while preserving `config.sh` as canonical defaults.
- `packages.sh` / `flatpak-packages.sh`: package arrays consumed during install and first-boot services. Optional overlays `packages_user.sh`/`flatpak-packages-user.sh` can be created by the wizard.
- `config_wizard_cli.py`: Python CLI menu for editing `config.sh` fields, managing user password hashes, and launching the partition wizard (no Tk needed).
- `installer.py`: higher-level CLI front-end to set hostname, swap type, locales, manage users, open the partition wizard, launch the legacy config-wizard.sh, and optionally run `install.sh` for an all-in-one flow.

## Main installation chain
- `install.sh`: orchestrator. Verifies network, runs reflector, formats and mounts partitions, clears `/mnt/boot`, runs pacstrap (idempotent via `pacstrap.done`), writes fstab/hostname/locale/timezone/keymap, configures swap (zram/swapfile), composes mkinitcpio fragments + HOOKS and rebuilds initramfs, installs bootloader (`install-systemd-boot.sh` or `install-uki.sh`), tweaks shells/sudoers/bashrc, provisions users from `passwords/`, tunes pacman, installs paru (`install-paru.sh`), installs pacman hooks, runs post-bootstrap package/service setup (`install-paru-packages-systemd.sh`), and schedules post-boot tasks (`install-post-install-setup.sh`).
- `reformat-partitions.sh`: destructive ext4 mkfs on root/home by label from `config.sh`. Called optionally by `install.sh`.
- `mount-partitions.sh`: mounts root/home by PARTLABEL, mounts ESP, binds ESP subdir to `/mnt/boot`. Used by `install.sh`.
- `cleanup-boot.sh`: clears `/mnt/boot` after mounts to avoid stale entries.
- `install-systemd-boot.sh`: installs and registers systemd-boot, writes loader/entry files pointing at the kernel/initramfs under `EFI/$IEFI_LINUX_DIRNAME/`.
- `install-uki.sh`: converts mkinitcpio preset to emit UKIs into the ESP, stores kernel cmdline, ensures efibootmgr entry, and optionally adds a pacman hook to recreate the boot entry.
- `install-paru.sh`: installs Rust toolchain into target and builds paru as the main user via temporary passwordless sudo.
- `install-pacman-hooks.sh`: adds hooks for systemd-boot refresh, NVIDIA-only initramfs rebuilds, and arch-audit after transactions.
- `install-paru-packages-systemd.sh`: installs configured pre-pacman/pacman/AUR packages via paru, then enables services conditionally (timesyncd, sshd, systemd-boot-update, resolved/NetworkManager DNS settings, ufw, bluetooth, sddm theme, pipewire stack, oomd, fwupd, autorotate, bolt, fstrim, man/plocate, reflector, paccache).
- `install-post-install-setup.sh`: copies installer configs/scripts into `/usr/local/sbin/` on the target and registers two oneshot services (`march-post-install-config.service`, `march-post-install-packages.service`) that run on first boot and then disable themselves.
- `install-users.sh`: creates/updates users based on files in `passwords/` (filename encodes extra groups). Sets root shell to zsh.

## Post-boot services (run inside installed OS)
- `post-install-config.sh`: one-time host configuration. Syncs hwclock, sets up UFW (ssh + KDE Connect), populates samba config and group if Samba is installed, and wires sunshine permissions/service if present.
- `post-install-packages.sh`: waits for DNS, installs `ILATE_PACKAGES` in background with paru, configures Flathub, and installs system/user Flatpaks as defined.

## Interactive wizards
- `config-wizard.sh`: edits `config.sh`-style files using `wizard-common.sh` helpers. Handles defaults, backups via inline `# wz-backup <path>`, and writing arrays/exports.
- `packages-wizard.sh`: edits package/flatpak lists with the same helper functions; can read/write user overlay files.
- `users-wizard.sh`: prompts for users and generates password hashes under `passwords/`, enforcing creation of the required main user and root password unless explicitly skipped.
- `wizard-common.sh`: utilities for array editing, escaping, backup detection, and load/save path selection shared across the wizards.

## Disk/ESP utilities
- `detect-esp.sh`: given a disk, prints the ESP partition path by GPT type GUID.
- `format-esp.sh`: formats a specific partition as FAT32 ESP (with GUID sanity check).
- `set-partlabel.sh`: renames a partition label using `sgdisk`.
- `reformat-partitions.sh` / `mount-partitions.sh` / `cleanup-boot.sh`: used in the main flow but also runnable standalone for manual prep.
- `partitions-wizard.py`: CLI (no desktop needed) planner to stage/create/delete/move/resize/label partitions, assign root/home/EFI/swap roles, and write the chosen labels/paths back into `config.sh`. Uses lsblk/parted/sgdisk and Python stdlib.
- `auto-partition.py`: quickly wipe an empty disk and create two ext4 partitions (root/home) using labels from `config.sh` (default root 60%, rest home).

## Desktop variants and extras
- `packages_gnome.sh`, `packages_cosmic.sh`: optional scripts to append GNOME/COSMIC package groups to `IPACMAN_PACKAGES`/`IAUR_PACKAGES`.
- `install-helium-widevine.sh`: helper to install `chromium-widevine` and symlink Widevine into Helium browser; rerun after browser/Widevine updates if DRM stops working.
- `setup-march.sh`: quick helper to `pacman -Sy git` on the live ISO and chmod `*.sh` in the repo.

## Data and state conventions
- `passwords/`: required for user creation; filenames encode `username+group1,group2`. Contents are `openssl passwd -6` hashes.
- `/mnt/var/lib/march-install/pacstrap.done`: flag to skip/re-run pacstrap.
- `/mnt/etc/mkinitcpio.conf.d/*.conf`: assembled module/HOOK fragments generated during install.
- `/mnt/efi/EFI/$IEFI_LINUX_DIRNAME/`: boot artifacts (kernel, initramfs, UKI, firmware images).
