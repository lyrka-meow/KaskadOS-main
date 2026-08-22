#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly SOURCE_PROFILE="${PROJECT_DIR}/profile"
readonly BUILD_ROOT="${PROJECT_DIR}/build"
readonly COMPOSITOR_BUILD="${BUILD_ROOT}/kaskad-installer-compositor"
readonly CALAMARES_BUILD="${BUILD_ROOT}/calamares"
readonly INSTALLER_THEMES="${PROJECT_DIR}/components/installer-themes"
readonly PROFILE_DIR="${PROFILE_DIR:-${BUILD_ROOT}/iso-profile}"
readonly BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"

die() {
  printf 'Ошибка: %s\n' "$*" >&2
  exit 1
}

for command_name in cmake ldd ninja pacman readelf; do
  command -v "${command_name}" >/dev/null 2>&1 || die "не найдена команда ${command_name}"
done

required_build_packages=(
  extra-cmake-modules
  kpmcore
  libpwquality
  plasma-wayland-protocols
  vulkan-headers
  wayland-protocols
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

declare -A runtime_packages=()
declare -A system_libraries=()
readonly STAGED_ROOT="${PROFILE_DIR}/airootfs"
readonly STAGED_LIBRARY_PATH="${STAGED_ROOT}/usr/lib:${STAGED_ROOT}/opt/kaskados-installer/bin"
for package_name in mesa qt6-wayland ttf-dejavu xkeyboard-config; do
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
