#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly PROFILE_DIR="${PROJECT_DIR}/profile"

die() {
  printf 'Ошибка: %s\n' "$*" >&2
  exit 1
}

required_paths=(
  'profiledef.sh'
  'pacman.conf'
  'packages.x86_64'
  'airootfs'
  'efiboot'
  'syslinux'
)

for path in "${required_paths[@]}"; do
  [[ -e "${PROFILE_DIR}/${path}" ]] || die "в профиле отсутствует ${path}"
done

while IFS= read -r -d '' script; do
  bash -n -- "${script}"
done < <(find "${PROFILE_DIR}" "${SCRIPT_DIR}" -type f -name '*.sh' -print0)

mapfile -t repositories < <(pacman-conf -c "${PROFILE_DIR}/pacman.conf" -l)
[[ " ${repositories[*]} " == *' core '* ]] || die 'в pacman.conf не включён репозиторий core'
[[ " ${repositories[*]} " == *' extra '* ]] || die 'в pacman.conf не включён репозиторий extra'

duplicates="$({ sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "${PROFILE_DIR}/packages.x86_64" || true; } | sort | uniq -d)"
[[ -z "${duplicates}" ]] || die $'в packages.x86_64 есть дубликаты:\n'"${duplicates}"

LC_ALL=C sort -c "${PROFILE_DIR}/packages.x86_64" || die 'packages.x86_64 должен быть отсортирован'

grep -Fxq 'breeze-cursors' "${PROFILE_DIR}/packages.x86_64" \
  || die 'в packages.x86_64 отсутствует тема курсора breeze-cursors'

required_installed_packages=(
  brightnessctl
  cava
  fastfetch
  flameshot
  grub
  kwin
  networkmanager
  python-pillow
  qt6-5compat
  qt6-multimedia
  qt6-multimedia-ffmpeg
  quickshell
  sddm
  xdg-desktop-portal-kde
  xorg-xwayland
)
for package_name in "${required_installed_packages[@]}"; do
  grep -Fxq "${package_name}" "${PROFILE_DIR}/packages.x86_64" \
    || die "в packages.x86_64 отсутствует обязательный пакет ${package_name}"
done

readonly SESSION_SCRIPT="${PROFILE_DIR}/airootfs/usr/local/bin/kaskados-installer-session"
grep -Fxq "export XCURSOR_THEME='breeze_cursors'" "${SESSION_SCRIPT}" \
  || die 'в live-сеансе не выбрана тема курсора breeze_cursors'
grep -Eq "^export XCURSOR_SIZE='[1-9][0-9]*'$" "${SESSION_SCRIPT}" \
  || die 'в live-сеансе не задан корректный размер курсора'
grep -Fxq 'LANG=ru_RU.UTF-8' "${PROFILE_DIR}/airootfs/etc/locale.conf" \
  || die 'русский язык не выбран в live-системе по умолчанию'
grep -Fxq "export LANG='ru_RU.UTF-8'" "${SESSION_SCRIPT}" \
  || die 'русский язык не выбран для live-установщика по умолчанию'

readonly WELCOME_CONFIG="${PROJECT_DIR}/components/calamares/src/modules/welcome/welcome.conf"
if grep -Eq '^[[:space:]]*-[[:space:]]*("false"|slow-false|slow-true|snark)[[:space:]]*$' "${WELCOME_CONFIG}"; then
  die 'в welcome.conf включены тестовые проверки Calamares'
fi
grep -Eq '^showSupportUrl:[[:space:]]+false$' "${WELCOME_CONFIG}" \
  || die 'в welcome.conf отображается ссылка поддержки'
grep -Eq '^showKnownIssuesUrl:[[:space:]]+false$' "${WELCOME_CONFIG}" \
  || die 'в welcome.conf отображается ссылка известных проблем'
if grep -Eq '^[[:space:]]*geoip:' "${WELCOME_CONFIG}"; then
  die 'в welcome.conf включено сетевое определение местоположения'
fi

readonly LOCALE_CONFIG="${PROJECT_DIR}/components/calamares/src/modules/locale/locale.conf"
if grep -Eq '^[[:space:]]*geoip:' "${LOCALE_CONFIG}"; then
  die 'в locale.conf включено сетевое определение часового пояса'
fi
grep -Eq '^[[:space:]]*ru:[[:space:]]+"Europe/Moscow"$' "${LOCALE_CONFIG}" \
  || die 'для русской локали не задан часовой пояс Europe/Moscow'
grep -Eq '^localeTimezones:$' "${LOCALE_CONFIG}" \
  || die 'в locale.conf отсутствуют офлайн-правила выбора часового пояса'

readonly CALAMARES_WINDOW="${PROJECT_DIR}/components/calamares/src/calamares/CalamaresWindow.cpp"
if grep -Eq 'setObjectName\([[:space:]]*"(aboutButton|debugButton)"' "${CALAMARES_WINDOW}"; then
  die 'в боковой панели Calamares создаются кнопки About или Debug'
fi

readonly CALAMARES_RUNNER="${PROFILE_DIR}/airootfs/usr/local/bin/kaskados-run-calamares"
if grep -Eq 'exec .*calamares.*[[:space:]]-D[0-9]+' "${CALAMARES_RUNNER}"; then
  die 'Calamares запускается с диагностическим уровнем журналирования'
fi
if grep -Fq 'Logger::setupLogfile();' "${PROJECT_DIR}/components/calamares/src/calamares/CalamaresApplication.cpp"; then
  die 'Calamares создаёт диагностический session.log'
fi

readonly CALAMARES_SETTINGS="${PROJECT_DIR}/components/calamares/settings.conf"
grep -Fq 'packagechooser@grubtheme' "${CALAMARES_SETTINGS}" \
  || die 'в Calamares не подключён выбор темы GRUB'
grep -Fq 'packagechooser@sddmtheme' "${CALAMARES_SETTINGS}" \
  || die 'в Calamares не подключён выбор темы SDDM'
grep -Fq 'kaskadthemes@themes-prepare' "${CALAMARES_SETTINGS}" \
  || die 'в Calamares не подключена установка выбранных тем'
grep -Fq 'kaskadthemes@themes-finalize' "${CALAMARES_SETTINGS}" \
  || die 'в Calamares не подключено завершение настройки GRUB'
if grep -Eq '^[[:space:]]*-[[:space:]]*(packages|netinstall)(@[^[:space:]]+)?[[:space:]]*$' "${CALAMARES_SETTINGS}"; then
  die 'в последовательности установки присутствует сетевой модуль пакетов'
fi

readonly UNPACKFS_CONFIG="${PROJECT_DIR}/components/calamares/src/modules/unpackfs/unpackfs.conf"
grep -Fq 'source: "/run/archiso/airootfs"' "${UNPACKFS_CONFIG}" \
  || die 'unpackfs не копирует автономную live-систему в установленную систему'
if grep -Eq '^[[:space:]]*-[[:space:]]*source:[[:space:]]+\.\./CHANGES' "${UNPACKFS_CONFIG}"; then
  die 'в unpackfs остался тестовый источник Calamares'
fi
grep -Fq '_install_kernel(root)' "${PROJECT_DIR}/components/calamares/src/modules/kaskadthemes/main.py" \
  || die 'установщик не переносит ядро из live-образа в /boot'
if grep -Fq '"/opt/macqueende/' "${UNPACKFS_CONFIG}"; then
  die 'unpackfs исключает MacqueenDE из установленной системы'
fi

readonly MACQUEENDE_DIR="${PROJECT_DIR}/components/macqueende"
for source_path in \
  VERSION \
  compositor/CMakeLists.txt \
  portal/CMakeLists.txt \
  quickshell/macqueen-module/CMakeLists.txt \
  shell/MolniyaMacqueenShell/core/Makefile \
  shell/MolniyaMacqueenShell/quickshell/shell.qml \
  session/macqueende.desktop \
  session/run-molniya \
  start-macqueende; do
  [[ -e "${MACQUEENDE_DIR}/${source_path}" ]] \
    || die "в MacqueenDE отсутствует ${source_path}"
done

readonly MACQUEEN_SESSION="${PROFILE_DIR}/airootfs/usr/share/wayland-sessions/macqueende.desktop"
grep -Fxq 'Exec=/usr/bin/start-macqueende' "${MACQUEEN_SESSION}" \
  || die 'сеанс SDDM не запускает MacqueenDE'
grep -Fxq 'TryExec=/usr/bin/start-macqueende' "${MACQUEEN_SESSION}" \
  || die 'в сеансе SDDM не задана проверка запуска MacqueenDE'

readonly DISPLAYMANAGER_CONFIG="${PROJECT_DIR}/components/calamares/src/modules/displaymanager/displaymanager.conf"
grep -Fq 'executable: "/usr/bin/start-macqueende"' "${DISPLAYMANAGER_CONFIG}" \
  || die 'Calamares не выбирает запуск MacqueenDE по умолчанию'
grep -Fq 'desktopFile: "macqueende"' "${DISPLAYMANAGER_CONFIG}" \
  || die 'Calamares не выбирает сеанс MacqueenDE по умолчанию'

readonly PREPARE_PROFILE="${SCRIPT_DIR}/prepare-live-profile.sh"
grep -Fq -- '--target macqueen screenshot screencast' "${PREPARE_PROFILE}" \
  || die 'prepare-live-profile.sh не собирает обязательные цели Macqueen'
grep -Fq 'readonly MACQUEEN_STAGE="${PROFILE_DIR}/airootfs/opt/macqueende"' "${PREPARE_PROFILE}" \
  || die 'prepare-live-profile.sh не добавляет MacqueenDE в ISO'

readonly BOOTLOADER_CONFIG="${PROJECT_DIR}/components/calamares/src/modules/bootloader/bootloader.conf"
grep -Eq '^efiBootLoader:[[:space:]]+"grub"$' "${BOOTLOADER_CONFIG}" \
  || die 'GRUB не выбран обязательным загрузчиком'

readonly SERVICES_CONFIG="${PROJECT_DIR}/components/calamares/src/modules/services-systemd/services-systemd.conf"
grep -Fq 'name: "sddm.service"' "${SERVICES_CONFIG}" \
  || die 'SDDM не включается в установленной системе'
grep -Fq 'action: "set-default"' "${SERVICES_CONFIG}" \
  || die 'графический режим не выбран режимом загрузки по умолчанию'

readonly THEMES_DIR="${PROJECT_DIR}/components/installer-themes"
grub_themes=(minegrub-combined crt-amber fallout lobotomy bsol billys-agent aero milk)
sddm_themes=(pixel-coffee pixel-munchlax pixel-hollowknight enfield winter material-you windows_7 terraria)
for theme_name in "${grub_themes[@]}"; do
  [[ -d "${THEMES_DIR}/grub/${theme_name}" ]] || die "не найдена тема GRUB ${theme_name}"
  [[ -f "${THEMES_DIR}/previews/grub/${theme_name}.png" ]] || die "не найдено превью GRUB ${theme_name}"
done
[[ -f "${THEMES_DIR}/grub/minegrub-combined/minegrub-update.service" ]] \
  || die 'для Minegrub не найден сервис смены текста'
for theme_name in "${sddm_themes[@]}"; do
  [[ -f "${THEMES_DIR}/sddm/${theme_name}/Main.qml" ]] || die "не найдена тема SDDM ${theme_name}"
  [[ -f "${THEMES_DIR}/previews/sddm/${theme_name}.gif" ]] || die "не найдено GIF-превью SDDM ${theme_name}"
done

readonly KEYBOARD_DIR="${PROJECT_DIR}/components/calamares/src/modules/keyboard"
grep -Eq '^guessLayout:[[:space:]]+true$' "${KEYBOARD_DIR}/keyboard.conf" \
  || die 'автоматический выбор раскладки по языку отключён'
grep -Fq 'isRussianLocale( lang )' "${KEYBOARD_DIR}/Config.cpp" \
  || die 'для русского языка не задано отдельное правило выбора раскладки'
grep -Fq 'lang = QStringLiteral( "us" );' "${KEYBOARD_DIR}/Config.cpp" \
  || die 'для русского языка не задана раскладка us по умолчанию'
if grep -Eq 'groupSelector|Switch Keyboard:' "${KEYBOARD_DIR}/KeyboardPage.ui"; then
  die 'в интерфейсе Calamares осталась настройка переключения раскладок'
fi
if grep -Eq 'gs->insert\([[:space:]]*"keyboard(AdditionalLayout|AdditionalVariant|GroupSwitcher|VConsoleKeymap)"' \
  "${KEYBOARD_DIR}/Config.cpp"; then
  die 'Calamares передаёт дополнительную live-раскладку в установленную систему'
fi

# shellcheck disable=SC1090
declare -A file_permissions=()
source "${PROFILE_DIR}/profiledef.sh"
[[ -n "${iso_name:-}" ]] || die 'в profiledef.sh не задан iso_name'
[[ -n "${iso_version:-}" ]] || die 'в profiledef.sh не задан iso_version'
(( ${#bootmodes[@]} > 0 )) || die 'в profiledef.sh не заданы bootmodes'
[[ " ${bootmodes[*]} " == *' uefi.grub '* ]] \
  || die 'UEFI-загрузка ISO должна использовать GRUB'
[[ " ${bootmodes[*]} " != *' uefi.systemd-boot '* ]] \
  || die 'systemd-boot не должен использоваться в ISO'

readonly ISO_GRUB_CONFIG="${PROFILE_DIR}/grub/grub.cfg"
[[ -f "${PROFILE_DIR}/grub/theme/theme.txt" ]] \
  || die 'в ISO отсутствует тема GRUB'
grep -Fq 'set theme="/boot/grub/theme/theme.txt"' "${ISO_GRUB_CONFIG}" \
  || die 'тема GRUB не подключена в загрузочном меню ISO'
(( $(grep -Ec '^[[:space:]]*menuentry[[:space:]]' "${ISO_GRUB_CONFIG}") == 1 )) \
  || die 'в загрузочном меню ISO должен оставаться ровно один пункт'
grep -Fq 'menuentry "Начать установку"' "${ISO_GRUB_CONFIG}" \
  || die 'в загрузочном меню ISO отсутствует запуск KaskadOS'
if grep -Eqi 'speech|memtest|efi shell|firmware|reboot|shutdown' "${ISO_GRUB_CONFIG}"; then
  die 'в загрузочном меню ISO остались служебные пункты'
fi

required_executables=(
  '/opt/kaskados-installer/bin/kaskad-installer'
  '/opt/macqueende/start-macqueende'
  '/usr/bin/calamares'
  '/usr/bin/start-macqueende'
  '/usr/local/bin/kaskados-installer-session'
  '/usr/local/bin/kaskados-run-calamares'
)
for executable_path in "${required_executables[@]}"; do
  [[ "${file_permissions[${executable_path}]:-}" == '0:0:755' ]] \
    || die "для ${executable_path} в profiledef.sh должны быть заданы права 0:0:755"
done

printf 'Профиль корректен: %s (%s)\n' "${iso_name}" "${iso_version}"
