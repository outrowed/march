# STEPS (Technical Walkthrough)

## Preparation
1) Obtain an Arch ISO and boot it (UEFI recommended, Secure Boot off).  
2) Clone this repo into the live environment.  
3) (Optional) Prefetch packages: `sudo ./generate-pacman-cache.sh` to warm `./cache/pacman`.  
4) (Optional) Build a custom installer ISO: `sudo ./build-iso.sh` (preloads repo and cache).

## Configure
1) Edit `config.sh` directly, or run `python3 installer.py` to set hostname, default locale, main user, swap type, and partition labels/EFI path; manage user password hashes (writes to `passwords/`).  
2) Ensure `packages.sh` lists desired packages. Branding defaults live in `config.sh` (`IBRAND_*`); assets in `os-assets/` are copied automatically.  
3) If using auto-partition on a clean disk: `sudo python3 auto-partition.py /dev/sdX [root_percent] [--add-efi=sizeMiB]`.

## Install
1) Run from repo root: `sudo ./install.sh`. Key stages:
   - Reflector updates mirrors.
   - Optional reformat/mount via helper scripts; cleans /mnt/boot.
   - Pacstrap using `packages.sh`, seeding pacman cache if present.
   - Writes fstab, hostname, locale, keymap.
   - Swap setup: zram / swapfile / combined; captures resume args for swapfile.
   - mkinitcpio fragments + HOOKS; rebuilds initramfs.
   - Bootloader: systemd-boot or UKI (mkinitcpio preset).
   - Users: sudoers, user creation from `passwords/`, wheel group.
   - Pacman tweaks: color, parallel downloads, reflector config.
   - Installs AUR helper yay-bin (with `paru` alias), pacman hooks, deferred packages/services, schedules first-boot jobs.
2) First boot: systemd services run:
   - `march-post-install-packages`: late packages + Flatpaks.
   - `march-post-install-config`: firewall, samba tweaks, sunshine, branding (os-release, boot entry titles, plymouth theme, SDDM background, Plasma wallpaper via autostart, icons, fastfetch, KDE defaults), fastfetch config.

## Branding assets
1) Place assets in `os-assets/` (e.g., `icon.png`, `icon-wordmark.png`, `wallpaper.png`, `wallpaper-dark.png`, `icon-ascii.txt`).  
2) They are copied to the target in `install-post-install-setup.sh`; branding applied on first boot by `post-install-config.sh`.

## ISO building (mkarchiso)
1) `sudo ./build-iso.sh`  
   - Clones releng profile into `.mkarchiso-work/profile`, adds git, seeds pacman cache if available, copies repo to `/root/march` in the ISO, runs `mkarchiso`.  
   - Outputs to `./out` by default; cleans previous work/output each run.

## Pacman cache usage
1) Host-side prefetch: `sudo ./generate-pacman-cache.sh` → `./cache/pacman`.  
2) Installer consumes cache automatically (`install.sh` seeds host and target caches from `LOCAL_PACMAN_CACHE` or default).

## Maintenance Notes
- Yay is installed but `paru` is symlinked for compatibility; scripts calling paru still work.  
- Branding leaves `/usr/lib/os-release` and `/etc/os-release` `ID` as `arch`; only `NAME/PRETTY_NAME/ID_LIKE` are changed.  
- Plymouth/theme apply only if packages are present; Plasma wallpaper is applied per-user at login via autostart helper.  
- Re-run `/usr/local/sbin/march-post-install-config.sh` after asset changes to reapply branding.
