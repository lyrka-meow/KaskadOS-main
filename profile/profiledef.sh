#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="kaskados"
iso_label="KASKADOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="KaskadOS <https://github.com/lyrka-meow/KaskadOS-main>"
iso_application="KaskadOS Live Installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.grub')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/opt/kaskados-installer/bin/kaskad-installer"]="0:0:755"
  ["/opt/macqueende/build/compositor/bin/macqueen"]="0:0:755"
  ["/opt/macqueende/build/portal/bin/xdg-desktop-portal-macqueen"]="0:0:755"
  ["/opt/macqueende/session/prepare-user-config"]="0:0:755"
  ["/opt/macqueende/session/run-molniya"]="0:0:755"
  ["/opt/macqueende/shell/MolniyaMacqueenShell/core/bin/dms"]="0:0:755"
  ["/opt/macqueende/shell/MolniyaMacqueenShell/quickshell/scripts/system-info.sh"]="0:0:755"
  ["/opt/macqueende/shell/MolniyaMacqueenShell/quickshell/scripts/system-maintenance.sh"]="0:0:755"
  ["/opt/macqueende/start-macqueende"]="0:0:755"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/bin/calamares"]="0:0:755"
  ["/usr/bin/regalia"]="0:0:755"
  ["/usr/bin/regaliad"]="0:0:755"
  ["/usr/bin/start-macqueende"]="0:0:755"
  ["/usr/lib/regalia/regalia-engine"]="0:0:755"
  ["/usr/lib/regalia/sing-box"]="0:0:755"
  ["/usr/local/bin/kaskados-installer-session"]="0:0:755"
  ["/usr/local/bin/kaskados-run-calamares"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
)
