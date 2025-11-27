# march

*Another Arch Linux installation script*

* **DISCLAIMER** This is a personal project of mine. If you don't know why are you doing, please don't try this at home. **It WILL reformat specific partitions.**

* This script automatically mounts the required partitions by their labels, specified in `./config.sh`.

* Please configure `./config.sh` file to personalize your Arch Linux installation.

* Also configure `./packages.sh` and `./flatpak-packages.sh` files to specify which packages you want to install.

    * By default, the packages selected are very bloated (including NVIDIA, Intel, and AMD drivers), and this is by design to support many devices with different hardware and specification in the long run.

* Generate users used in the installation via `./users-gen.sh` to automatically generate users in the `./passwords` directory.

    * The filenames in `./passwords` directory are used for the usernames, and the files' content are the hashed password via `openssl passwd -6`.

* The "main" script you're supposed to run for the first time is: `./install.sh`.

## License

This project is licensed under the terms of the
GNU General Public License, version 2 or (at your option) any later version.

See the `COPYING` file for the full license text.