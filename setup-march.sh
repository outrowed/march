#!/usr/bin/bash

# Sync and get package list in Arch ISO (which may be outdated)
pacman -Sy git

# Make shell scripts in current PWD executable
chmod +x ./*.sh