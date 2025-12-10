#!/usr/bin/bash

# resources:
# https://github.com/imputnet/helium/issues/116#issuecomment-3455140414 (widevine drm linking)
# https://github.com/imputnet/helium/issues/116#issuecomment-3506881566 (chromium-widevine)

paru -S chromium-widevine

sudo ln -s /usr/lib/chromium/WidevineCdm /opt/helium-browser-bin/WidevineCdm

echo 'Enter "chrome://restart" on the address bar in Helium browser to load the WidevineCdm libraries'
echo "Do note that Chromium's WidevineCdm libraries for the browser may be removed without notice during pacman/AUR upgrades, in that case, you will need to re-run this script again"