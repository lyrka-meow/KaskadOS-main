#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly PROFILE_DIR="${PROFILE_DIR:-${PROJECT_DIR}/build/iso-profile}"
readonly WORK_DIR="${WORK_DIR:-${PROJECT_DIR}/work}"
readonly OUT_DIR="${OUT_DIR:-${PROJECT_DIR}/out}"

die() {
  printf 'Ошибка: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -m)" == 'x86_64' ]] || die 'сборка этого профиля поддерживается только на x86_64'
command -v mkarchiso >/dev/null 2>&1 || die 'mkarchiso не найден; установите пакет archiso'

if [[ -e "${WORK_DIR}" ]]; then
  die "рабочий каталог уже существует: ${WORK_DIR}; после проверки монтирований выполните make clean"
fi

"${SCRIPT_DIR}/prepare-live-profile.sh"
[[ -f "${PROFILE_DIR}/profiledef.sh" ]] || die "не подготовлен профиль: ${PROFILE_DIR}"

mkdir -p -- "${OUT_DIR}"

printf 'Профиль:          %s\n' "${PROFILE_DIR}"
printf 'Рабочий каталог: %s\n' "${WORK_DIR}"
printf 'Готовый ISO:     %s\n' "${OUT_DIR}"

if (( EUID == 0 )); then
  exec mkarchiso -v -r -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"
fi

exec sudo mkarchiso -v -r -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"
