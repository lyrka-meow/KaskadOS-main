#!/usr/bin/env bash

set -uo pipefail

readonly SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
readonly PROJECT_DIR="$(cd -- "$(dirname -- "${SCRIPT_PATH}")" && pwd)"
readonly ISO_BUILD_SCRIPT="${PROJECT_DIR}/scripts/build-iso.sh"
readonly DESKTOP_BUILD_SCRIPT="${PROJECT_DIR}/scripts/build-desktop-package.sh"
readonly PUBLISH_SCRIPT="${PROJECT_DIR}/scripts/publish-repository.sh"
readonly VERSION_FILE="${PROJECT_DIR}/components/macqueende/VERSION"
readonly PACKAGE_DIR="${PROJECT_DIR}/out/packages/x86_64"
readonly OUTPUT_DIR="${PROJECT_DIR}/out"
readonly ISO_LOG="${HOME}/kaskados-build.log"
readonly DESKTOP_LOG="${HOME}/kaskados-desktop-build.log"
readonly PUBLISH_LOG="${HOME}/kaskados-publish.log"

if [[ -t 1 ]]; then
  readonly RESET=$'\033[0m'
  readonly BOLD=$'\033[1m'
  readonly GREEN=$'\033[32m'
  readonly YELLOW=$'\033[33m'
  readonly RED=$'\033[31m'
  readonly CYAN=$'\033[36m'
else
  readonly RESET=''
  readonly BOLD=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly RED=''
  readonly CYAN=''
fi

die() {
  printf '%sОшибка:%s %s\n' "${RED}" "${RESET}" "$*" >&2
  exit 1
}

current_version() {
  [[ -f "${VERSION_FILE}" ]] || return 1
  tr -d '\n' < "${VERSION_FILE}"
}

package_version() {
  current_version | tr '-' '_'
}

newest_file() {
  local directory="$1"
  local pattern="$2"

  [[ -d "${directory}" ]] || return 1
  find "${directory}" -maxdepth 1 -type f -name "${pattern}" \
    -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d ' ' -f 2-
}

latest_desktop_package() {
  local version
  version="$(package_version)" || return 1
  newest_file "${PACKAGE_DIR}" "kaskados-desktop-${version}-*-x86_64.pkg.tar.zst"
}

latest_iso() {
  newest_file "${OUTPUT_DIR}" '*.iso'
}

human_file() {
  local path="$1"

  if [[ -n "${path}" && -f "${path}" ]]; then
    printf '%s (%s)' "${path}" "$(du -h -- "${path}" | cut -f 1)"
  else
    printf 'не найден'
  fi
}

pause_menu() {
  printf '\n'
  read -r -p 'Нажмите Enter, чтобы вернуться в меню...' _ || true
}

confirm() {
  local prompt="$1"
  local answer

  read -r -p "${prompt} [д/Н]: " answer || return 1
  case "${answer}" in
    д|Д|y|Y|yes|YES|да|Да|ДА)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

print_result() {
  local result="$1"
  local success_text="$2"
  local failure_text="$3"

  printf '\n'
  if (( result == 0 )); then
    printf '%s%s%s\n' "${GREEN}" "${success_text}" "${RESET}"
  else
    printf '%s%s Код ошибки: %d.%s\n' "${RED}" "${failure_text}" "${result}" "${RESET}"
  fi
}

run_logged() {
  local title="$1"
  local log_file="$2"
  shift 2

  printf '\n%s%s%s\n' "${BOLD}" "${title}" "${RESET}"
  printf 'Журнал: %s\n\n' "${log_file}"

  (
    cd -- "${PROJECT_DIR}" || exit 1
    set -o pipefail
    "$@" 2>&1 | tee "${log_file}"
  )
}

build_iso() {
  run_logged 'Сборка ISO KaskadOS' "${ISO_LOG}" "${ISO_BUILD_SCRIPT}"
  local result=$?

  print_result "${result}" \
    "Сборка ISO завершена. Файл: $(human_file "$(latest_iso || true)")" \
    "Сборка ISO остановилась. Последние строки находятся в ${ISO_LOG}."
  return "${result}"
}

build_desktop() {
  run_logged 'Сборка пакета обновления MacqueenDE' \
    "${DESKTOP_LOG}" "${DESKTOP_BUILD_SCRIPT}"
  local result=$?

  print_result "${result}" \
    "Пакет DE готов: $(human_file "$(latest_desktop_package || true)")" \
    "Сборка пакета DE остановилась. Последние строки находятся в ${DESKTOP_LOG}."
  return "${result}"
}

signing_key() {
  if [[ -n "${KASKADOS_SIGNING_KEY:-}" ]]; then
    printf '%s\n' "${KASKADOS_SIGNING_KEY}"
    return 0
  fi

  command -v gpg >/dev/null 2>&1 || return 1
  gpg --batch --with-colons --list-secret-keys 'KaskadOS Package Signing' 2>/dev/null \
    | awk -F: '$1 == "sec" { print $5; exit }'
}

publish_desktop() {
  local package key result
  package="$(latest_desktop_package || true)"

  if [[ -z "${package}" || ! -f "${package}" ]]; then
    printf '%sНе найден пакет текущей версии %s.%s\n' \
      "${RED}" "$(current_version)" "${RESET}" >&2
    printf 'Сначала выберите пункт «Собрать пакет обновления DE».\n'
    return 2
  fi

  key="$(signing_key || true)"
  if [[ -z "${key}" ]]; then
    printf '%sНе найден секретный ключ «KaskadOS Package Signing».%s\n' \
      "${RED}" "${RESET}" >&2
    return 2
  fi

  printf '\nБудет опубликован пакет:\n  %s\n' "$(human_file "${package}")"
  printf 'Адрес репозитория:\n  https://repo.kaskados.xyz/x86_64/\n\n'
  confirm 'Опубликовать обновление для пользователей?' || {
    printf 'Публикация отменена.\n'
    return 130
  }

  run_logged 'Публикация обновления MacqueenDE' "${PUBLISH_LOG}" \
    env KASKADOS_SIGNING_KEY="${key}" "${PUBLISH_SCRIPT}" "${package}"
  result=$?

  print_result "${result}" \
    'Обновление DE опубликовано.' \
    "Публикация остановилась. Последние строки находятся в ${PUBLISH_LOG}."
  return "${result}"
}

build_and_publish_desktop() {
  printf '\nПосле успешной сборки пакет будет предложено опубликовать.\n'
  confirm 'Продолжить?' || {
    printf 'Операция отменена.\n'
    return 130
  }

  build_desktop || return $?
  publish_desktop
}

show_status() {
  local version package iso branch commit changes

  version="$(current_version || printf 'неизвестна')"
  package="$(latest_desktop_package || true)"
  iso="$(latest_iso || true)"
  branch="$(git -C "${PROJECT_DIR}" branch --show-current 2>/dev/null || true)"
  commit="$(git -C "${PROJECT_DIR}" log -1 --pretty='%h %s' 2>/dev/null || true)"
  changes="$(git -C "${PROJECT_DIR}" status --porcelain=v1 2>/dev/null | wc -l)"

  printf '\n%sСостояние KaskadOS%s\n\n' "${BOLD}" "${RESET}"
  printf 'Версия DE:       %s\n' "${version}"
  printf 'Ветка Git:       %s\n' "${branch:-неизвестна}"
  printf 'Последний коммит: %s\n' "${commit:-неизвестен}"
  printf 'Локальных правок: %s\n' "${changes}"
  printf 'Пакет DE:        %s\n' "$(human_file "${package}")"
  printf 'Последний ISO:   %s\n' "$(human_file "${iso}")"
  printf 'Репозиторий:     https://repo.kaskados.xyz/x86_64/\n'
}

draw_menu() {
  local version
  version="$(current_version || printf 'неизвестна')"

  if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
    clear
  fi

  printf '%s%sKaskadOS — управление сборками%s\n' "${BOLD}" "${CYAN}" "${RESET}"
  printf 'Проект: %s\n' "${PROJECT_DIR}"
  printf 'Версия MacqueenDE: %s\n\n' "${version}"
  printf '  %s1%s  Собрать ISO\n' "${GREEN}" "${RESET}"
  printf '  %s2%s  Собрать пакет обновления DE\n' "${GREEN}" "${RESET}"
  printf '  %s3%s  Опубликовать собранный пакет DE\n' "${YELLOW}" "${RESET}"
  printf '  %s4%s  Собрать и опубликовать DE\n' "${YELLOW}" "${RESET}"
  printf '  %s5%s  Показать состояние и готовые файлы\n' "${CYAN}" "${RESET}"
  printf '  %s0%s  Выход\n\n' "${RED}" "${RESET}"
}

for required_file in \
  "${ISO_BUILD_SCRIPT}" \
  "${DESKTOP_BUILD_SCRIPT}" \
  "${PUBLISH_SCRIPT}" \
  "${VERSION_FILE}"; do
  [[ -f "${required_file}" ]] || die "не найден файл ${required_file}"
done

while true; do
  draw_menu
  read -r -p 'Выберите действие: ' choice || {
    printf '\n'
    exit 0
  }

  case "${choice}" in
    1)
      build_iso || true
      pause_menu
      ;;
    2)
      build_desktop || true
      pause_menu
      ;;
    3)
      publish_desktop || true
      pause_menu
      ;;
    4)
      build_and_publish_desktop || true
      pause_menu
      ;;
    5)
      show_status
      pause_menu
      ;;
    0)
      exit 0
      ;;
    *)
      printf '\n%sНет такого пункта.%s\n' "${RED}" "${RESET}"
      pause_menu
      ;;
  esac
done
