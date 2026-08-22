#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly SOURCE_PROFILE="${PROJECT_DIR}/profile"
readonly BUILD_ROOT="${PROJECT_DIR}/build"
readonly COMPOSITOR_BUILD="${BUILD_ROOT}/kaskad-installer-compositor"
readonly CALAMARES_BUILD="${BUILD_ROOT}/calamares"
readonly MACQUEENDE_SOURCE="${PROJECT_DIR}/components/macqueende"
readonly MACQUEENDE_BUILD="${BUILD_ROOT}/macqueende"
readonly MACQUEEN_COMPOSITOR_BUILD="${MACQUEENDE_BUILD}/compositor"
readonly MACQUEEN_PORTAL_BUILD="${MACQUEENDE_BUILD}/portal"
readonly MACQUEEN_QUICKSHELL_BUILD="${MACQUEENDE_BUILD}/quickshell-macqueen"
readonly MACQUEEN_SHELL_BUILD="${MACQUEENDE_BUILD}/shell-source"
readonly INSTALLER_THEMES="${PROJECT_DIR}/components/installer-themes"
readonly PROFILE_DIR="${PROFILE_DIR:-${BUILD_ROOT}/iso-profile}"
readonly BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
readonly MACQUEEN_BUILD_JOBS="${MACQUEEN_BUILD_JOBS:-8}"
readonly MACQUEEN_SOURCE_COMMIT="$(git -C "${PROJECT_DIR}" rev-parse HEAD 2>/dev/null || printf 'unknown')"

die() {
  printf 'Ошибка: %s\n' "$*" >&2
  exit 1
}

for command_name in cmake go ldd make ninja pacman readelf; do
  command -v "${command_name}" >/dev/null 2>&1 || die "не найдена команда ${command_name}"
done

required_build_packages=(
  base-devel
  extra-cmake-modules
  git
  go
  kpmcore
  kwin
  libpwquality
  plasma-wayland-protocols
  qt6-declarative
  vulkan-headers
  wayland-protocols
  xdg-desktop-portal-kde
  yaml-cpp
)
mapfile -t missing_build_packages < <(pacman -T "${required_build_packages[@]}" 2>/dev/null || true)
if (( ${#missing_build_packages[@]} > 0 )); then
  printf 'Не установлены пакеты для сборки:\n' >&2
  printf '  %s\n' "${missing_build_packages[@]}" >&2
  printf 'Установите их командой:\n  sudo pacman -S --needed' >&2
  printf ' %q' "${missing_build_packages[@]}" >&2
  printf '\n' >&2
  exit 2
fi

[[ "$(uname -m)" == 'x86_64' ]] || die 'сборка поддерживается только на x86_64'
[[ "$(realpath -m -- "${PROFILE_DIR}")" == "${BUILD_ROOT}"/* ]] || die 'подготовленный профиль должен находиться внутри build/'
[[ -d "${INSTALLER_THEMES}/grub" ]] || die 'не найдены темы GRUB для установщика'
[[ -d "${INSTALLER_THEMES}/sddm" ]] || die 'не найдены темы SDDM для установщика'
[[ -d "${INSTALLER_THEMES}/previews" ]] || die 'не найдены превью тем для установщика'
[[ -f "${MACQUEENDE_SOURCE}/VERSION" ]] || die 'не найден исходный код MacqueenDE'
[[ -f "${MACQUEENDE_SOURCE}/session/macqueende.desktop" ]] || die 'не найдена сессия MacqueenDE'

"${SCRIPT_DIR}/check-profile.sh"

env -u LD_LIBRARY_PATH cmake -S "${PROJECT_DIR}/components/kaskad-installer-compositor" -B "${COMPOSITOR_BUILD}" -G Ninja \
  -DBUILD_TESTING=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON \
  -DKASKAD_INSTALLER_MINIMAL=ON \
  -DKWIN_BUILD_ACTIVITIES=OFF \
  -DKWIN_BUILD_DECORATIONS=OFF \
  -DKWIN_BUILD_EIS=OFF \
  -DKWIN_BUILD_GAMECONTROLLER=OFF \
  -DKWIN_BUILD_GLOBALSHORTCUTS=OFF \
  -DKWIN_BUILD_KCMS=OFF \
  -DKWIN_BUILD_NOTIFICATIONS=OFF \
  -DKWIN_BUILD_QACCESSIBILITYCLIENT=OFF \
  -DKWIN_BUILD_RUNNERS=OFF \
  -DKWIN_BUILD_SCREENLOCKER=OFF \
  -DKWIN_BUILD_TABBOX=OFF \
  -DKWIN_BUILD_X11=OFF
env -u LD_LIBRARY_PATH cmake --build "${COMPOSITOR_BUILD}" --target kaskad-installer --parallel "${BUILD_JOBS}"

env -u LD_LIBRARY_PATH cmake -S "${MACQUEENDE_SOURCE}/compositor" -B "${MACQUEEN_COMPOSITOR_BUILD}" -G Ninja \
  -DBUILD_TESTING=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueende
env -u LD_LIBRARY_PATH cmake --build "${MACQUEEN_COMPOSITOR_BUILD}" \
  --target macqueen screenshot screencast \
  --parallel "${MACQUEEN_BUILD_JOBS}"

env -u LD_LIBRARY_PATH cmake -S "${MACQUEENDE_SOURCE}/portal" -B "${MACQUEEN_PORTAL_BUILD}" -G Ninja \
  -DBUILD_TESTING=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueende
env -u LD_LIBRARY_PATH cmake --build "${MACQUEEN_PORTAL_BUILD}" --parallel "${MACQUEEN_BUILD_JOBS}"

env -u LD_LIBRARY_PATH cmake -S "${MACQUEENDE_SOURCE}/quickshell/macqueen-module" -B "${MACQUEEN_QUICKSHELL_BUILD}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueende
env -u LD_LIBRARY_PATH cmake --build "${MACQUEEN_QUICKSHELL_BUILD}" --parallel "${MACQUEEN_BUILD_JOBS}"

if [[ -e "${MACQUEEN_SHELL_BUILD}" ]]; then
  rm -rf -- "${MACQUEEN_SHELL_BUILD}"
fi
mkdir -p -- "${MACQUEEN_SHELL_BUILD}"
cp -a -- "${MACQUEENDE_SOURCE}/shell/MolniyaMacqueenShell/." "${MACQUEEN_SHELL_BUILD}/"
make -C "${MACQUEEN_SHELL_BUILD}/core" \
  VERSION="$(tr -d '\n' < "${MACQUEENDE_SOURCE}/VERSION")" \
  COMMIT=kaskados \
  build

env -u LD_LIBRARY_PATH cmake -S "${PROJECT_DIR}/components/calamares" -B "${CALAMARES_BUILD}" -G Ninja \
  -DBUILD_SCHEMA_TESTING=OFF \
  -DBUILD_TESTING=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DINSTALL_CONFIG=ON \
  -DWITH_QT6=ON
env -u LD_LIBRARY_PATH cmake --build "${CALAMARES_BUILD}" --parallel "${BUILD_JOBS}"

if [[ -e "${PROFILE_DIR}" ]]; then
  rm -rf -- "${PROFILE_DIR}"
fi
mkdir -p -- "${PROFILE_DIR}"
cp -a -- "${SOURCE_PROFILE}/." "${PROFILE_DIR}/"

install -d -m 0755 \
  "${PROFILE_DIR}/airootfs/usr/share/kaskados-installer/theme-pool" \
  "${PROFILE_DIR}/airootfs/usr/share/kaskados-installer/theme-previews"
cp -a -- \
  "${INSTALLER_THEMES}/grub" \
  "${INSTALLER_THEMES}/sddm" \
  "${INSTALLER_THEMES}/SOURCES.md" \
  "${PROFILE_DIR}/airootfs/usr/share/kaskados-installer/theme-pool/"
cp -a -- \
  "${INSTALLER_THEMES}/previews/." \
  "${PROFILE_DIR}/airootfs/usr/share/kaskados-installer/theme-previews/"

DESTDIR="${PROFILE_DIR}/airootfs" env -u LD_LIBRARY_PATH cmake --install "${CALAMARES_BUILD}" --strip

install -d -m 0755 "${PROFILE_DIR}/airootfs/opt/kaskados-installer/bin"
install -m 0755 \
  "${COMPOSITOR_BUILD}/bin/kaskad-installer" \
  "${PROFILE_DIR}/airootfs/opt/kaskados-installer/bin/kaskad-installer"
cp -a -- \
  "${COMPOSITOR_BUILD}"/bin/libkwin.so* \
  "${PROFILE_DIR}/airootfs/opt/kaskados-installer/bin/"

readonly MACQUEEN_STAGE="${PROFILE_DIR}/airootfs/opt/macqueende"
install -d -m 0755 \
  "${MACQUEEN_STAGE}/build/compositor" \
  "${MACQUEEN_STAGE}/build/portal" \
  "${MACQUEEN_STAGE}/build/quickshell-macqueen" \
  "${MACQUEEN_STAGE}/shell/MolniyaMacqueenShell/core/bin" \
  "${PROFILE_DIR}/airootfs/usr/share/applications" \
  "${PROFILE_DIR}/airootfs/usr/share/xdg-desktop-portal"
cp -a -- "${MACQUEEN_COMPOSITOR_BUILD}/bin" "${MACQUEEN_STAGE}/build/compositor/"
cp -a -- "${MACQUEEN_PORTAL_BUILD}/bin" "${MACQUEEN_STAGE}/build/portal/"
cp -a -- "${MACQUEEN_QUICKSHELL_BUILD}/Macqueen" "${MACQUEEN_STAGE}/build/quickshell-macqueen/"
cp -a -- "${MACQUEEN_QUICKSHELL_BUILD}"/libquickshell-macqueen.so* \
  "${MACQUEEN_STAGE}/build/quickshell-macqueen/"
install -m 0755 "${MACQUEEN_SHELL_BUILD}/core/bin/dms" \
  "${MACQUEEN_STAGE}/shell/MolniyaMacqueenShell/core/bin/dms"
cp -a -- \
  "${MACQUEENDE_SOURCE}/shell/MolniyaMacqueenShell/quickshell" \
  "${MACQUEENDE_SOURCE}/shell/MolniyaMacqueenShell/dank-qml-common" \
  "${MACQUEEN_STAGE}/shell/MolniyaMacqueenShell/"
cp -a -- \
  "${MACQUEENDE_SOURCE}/config" \
  "${MACQUEENDE_SOURCE}/session" \
  "${MACQUEENDE_SOURCE}/start-macqueende" \
  "${MACQUEEN_STAGE}/"
install -m 0644 "${MACQUEENDE_SOURCE}/session/macqueende-portals.conf" \
  "${PROFILE_DIR}/airootfs/usr/share/xdg-desktop-portal/macqueende-portals.conf"
sed 's|@MACQUEENDE_ROOT@|/opt/macqueende|g' \
  "${MACQUEENDE_SOURCE}/session/org.freedesktop.impl.portal.desktop.kde.desktop.in" \
  > "${PROFILE_DIR}/airootfs/usr/share/applications/org.macqueen.portal.desktop"
install -m 0644 "${MACQUEENDE_SOURCE}/VERSION" "${MACQUEEN_STAGE}/VERSION"
printf '%s\n' \
  'METHOD=kaskados' \
  "VERSION=$(tr -d '\n' < "${MACQUEENDE_SOURCE}/VERSION")" \
  'SOURCE_REPOSITORY=https://github.com/lyrka-meow/KaskadOS-main' \
  'SOURCE_PATH=components/macqueende' \
  "SOURCE_COMMIT=${MACQUEEN_SOURCE_COMMIT}" \
  'BUILD_PACKAGES=' \
  'MANAGED_FLAMESHOT=0' \
  > "${MACQUEEN_STAGE}/INSTALL_INFO"

declare -A runtime_packages=()
declare -A system_libraries=()
readonly STAGED_ROOT="${PROFILE_DIR}/airootfs"
readonly STAGED_LIBRARY_PATH="${STAGED_ROOT}/usr/lib:${STAGED_ROOT}/opt/kaskados-installer/bin:${MACQUEEN_STAGE}/build/compositor/bin:${MACQUEEN_STAGE}/build/portal/bin:${MACQUEEN_STAGE}/build/quickshell-macqueen"
for package_name in \
  brightnessctl \
  cava \
  curl \
  ddcutil \
  flameshot \
  kwin \
  mesa \
  pacman-contrib \
  pciutils \
  qt6-5compat \
  qt6-connectivity \
  qt6-imageformats \
  qt6-multimedia \
  qt6-positioning \
  qt6-sensors \
  qt6-svg \
  qt6-wayland \
  quickshell \
  ttf-dejavu \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-kde \
  xkeyboard-config \
  xorg-xwayland; do
  runtime_packages["${package_name}"]=1
done

while IFS= read -r -d '' artifact; do
  if ! readelf -h "${artifact}" >/dev/null 2>&1; then
    continue
  fi

  ldd_output="$(env LD_LIBRARY_PATH="${STAGED_LIBRARY_PATH}" ldd "${artifact}" 2>/dev/null || true)"
  if grep -Fq 'not found' <<< "${ldd_output}"; then
    printf 'Неразрешённые библиотеки в %s:\n%s\n' "${artifact}" "${ldd_output}" >&2
    exit 1
  fi

  while IFS= read -r library; do
    [[ -e "${library}" ]] || continue
    [[ "${library}" != "${STAGED_ROOT}/"* ]] || continue
    system_libraries["${library}"]=1
  done < <(awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^\//) { sub(/\(.*/, "", $i); print $i } }' <<< "${ldd_output}")
done < <(find \
  "${PROFILE_DIR}/airootfs/usr/bin" \
  "${PROFILE_DIR}/airootfs/usr/lib" \
  "${PROFILE_DIR}/airootfs/opt/kaskados-installer/bin" \
  "${PROFILE_DIR}/airootfs/opt/macqueende" \
  -type f -print0)

if (( ${#system_libraries[@]} > 0 )); then
  package_owner_output="$(pacman -Qqo -- "${!system_libraries[@]}")" \
    || die 'не удалось определить пакеты системных библиотек'
  while IFS= read -r package_name; do
    [[ -n "${package_name}" ]] && runtime_packages["${package_name}"]=1
  done <<< "${package_owner_output}"
fi

pacman --config "${SOURCE_PROFILE}/pacman.conf" -Si "${!runtime_packages[@]}" >/dev/null \
  || die 'один или несколько пакетов времени выполнения отсутствуют в репозиториях ISO'

for package_name in "${!runtime_packages[@]}"; do
  printf '%s\n' "${package_name}" >> "${PROFILE_DIR}/packages.x86_64"
done

LC_ALL=C sort -u -o "${PROFILE_DIR}/packages.x86_64" "${PROFILE_DIR}/packages.x86_64"

printf 'Подготовлен live-профиль: %s\n' "${PROFILE_DIR}"
printf 'Композитор: %s\n' "${PROFILE_DIR}/airootfs/opt/kaskados-installer/bin/kaskad-installer"
printf 'Calamares:  %s\n' "${PROFILE_DIR}/airootfs/usr/bin/calamares"
printf 'MacqueenDE: %s\n' "${PROFILE_DIR}/airootfs/opt/macqueende/start-macqueende"
