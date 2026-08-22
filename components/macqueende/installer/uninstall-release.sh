#!/usr/bin/env bash

set -euo pipefail

build_packages=
managed_flameshot=0
if [[ -r /opt/macqueende/INSTALL_INFO ]]; then
    build_packages=$(sed -n 's/^BUILD_PACKAGES=//p' \
        /opt/macqueende/INSTALL_INFO |
        head -n1)
    managed_flameshot=$(sed -n 's/^MANAGED_FLAMESHOT=//p' \
        /opt/macqueende/INSTALL_INFO |
        head -n1)
fi

sudo rm -f /usr/bin/start-macqueende \
    /usr/bin/macqueende-manager \
    /usr/share/wayland-sessions/macqueende.desktop \
    /usr/share/xdg-desktop-portal/macqueende-portals.conf \
    /usr/share/applications/org.macqueen.portal.desktop
sudo rm -rf /opt/macqueende
sudo find /opt -maxdepth 1 -type d -name 'macqueende.previous.*' \
    -exec rm -rf -- {} +

if [[ -n "$build_packages" && ${MACQUEENDE_KEEP_BUILD_DEPS:-0} != 1 ]] &&
   command -v pacman >/dev/null; then
    read -r -a packages <<<"$build_packages"
    installed=()
    for package in "${packages[@]}"; do
        pacman -Q "$package" >/dev/null 2>&1 &&
            installed+=("$package")
    done
    if ((${#installed[@]})); then
        echo "Removing build packages installed by MacqueenDE..."
        sudo pacman -Rns --noconfirm "${installed[@]}" || {
            echo "Some build packages are still required by other software and were kept." >&2
        }
    fi
fi

if [[ "$managed_flameshot" == 1 &&
      ${MACQUEENDE_KEEP_FLAMESHOT:-0} != 1 ]] &&
   command -v pacman >/dev/null &&
   pacman -Q flameshot >/dev/null 2>&1; then
    echo "Removing Flameshot installed by MacqueenDE..."
    sudo pacman -Rns --noconfirm flameshot || {
        echo "Flameshot is still required by other software and was kept." >&2
    }
fi

echo "MacqueenDE removed. User configuration in ~/.config was preserved."
