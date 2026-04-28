# march - (My-)Arch Linux

march is a semi-unattended Arch Linux installation scripts customizable for personal uses.

This project is a *template* rather than a full-fledge OS installation experience. It's designed for tinkers and developers to quickly setup Arch system and customize their step-by-step installation. In other words, it's a cooking recipe intended that you can change and modify.

## Technical notes

* This project exclusively supports:
    * NetworkManager and systemd-resolved for networking
    * systemd-boot or [Unified Kernel Image (UKI)](https://wiki.archlinux.org/title/Unified_Kernel_Image) for the bootloader
    * CachyOS Linux kernel, and additionally other tools and utilities made by them
* It supports *most variations of common PC hardware* -- meaning it will install many drivers to support common hardware you'll see on PC builds
    * For example, NVIDIA, AMD, and Intel graphics drivers are intentionally added in the installation so it support most common graphics card extensively
    * Most available printers drivers are also installed, including Cups, Gutenprint, and hplip packages

## License

This project is licensed under the terms of the GNU General Public License, version 2 or (at your option) any later version.

See [`LICENSE`](LICENSE) file for more information.

SPDX-License-Identifier: GPL-2.0-or-later