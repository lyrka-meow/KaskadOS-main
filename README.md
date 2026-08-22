# KaskadOS

KaskadOS — дистрибутив на базе Arch Linux со своим live-установщиком Calamares.

ISO запускает отдельный минимальный Wayland-композитор `kaskad-installer`,
полученный из MacqueenDE. После готовности Wayland композитор сразу запускает
Calamares. Главное окно установщика принудительно остаётся полноэкранным, без
возможности свернуть или закрыть его средствами оконного менеджера.

Полный исходный код MacqueenDE хранится в этом же репозитории. Во время сборки
ISO рабочий стол собирается отдельно от live-композитора и добавляется в
устанавливаемую систему как основной графический сеанс SDDM.

## Сборка ISO

Сборка поддерживается на Arch Linux x86_64.

1. Обновить систему и установить инструменты и заголовки, необходимые для
   сборки компонентов:

   ```bash
   sudo pacman -Syu --needed archiso base-devel boost cmake extra-cmake-modules \
     git go kpmcore kwin libpwquality ninja plasma-wayland-protocols pybind11 \
     qt6-declarative vulkan-headers wayland-protocols \
     xdg-desktop-portal-kde yaml-cpp
   ```

2. Проверить профиль:

   ```bash
   make check
   ```

3. Собрать компоненты и ISO:

   ```bash
   make iso
   ```

Готовый файл появится в `out/` и будет называться примерно так:
`kaskados-YYYY.MM.DD-x86_64.iso`.

Для сборки напрямую, без `make`:

```bash
./scripts/build-iso.sh
```

Каталоги работы archiso и результата можно переопределить переменными
окружения:

```bash
WORK_DIR=/tmp/kaskados-work OUT_DIR="$PWD/out" ./scripts/build-iso.sh
```

## Если сборка прервалась

После неудачной или прерванной сборки каталог `work/` сохраняется. Перед его
удалением нужно убедиться, что внутри не осталось bind-mount. Скрипт очистки
делает эту проверку и откажется удалять каталог, если найдёт монтирования:

```bash
make clean
```

Каталог `out/` команда очистки не трогает.

## Как устроена сборка live-среды

`scripts/prepare-live-profile.sh` отдельно собирает Calamares,
`kaskad-installer` и полный MacqueenDE, затем создаёт генерируемый профиль
`build/iso-profile/`. Исходный `profile/` не засоряется бинарными файлами.
Calamares устанавливается в `/usr`, live-композитор — в
`/opt/kaskados-installer`, а установленный рабочий стол — в `/opt/macqueende`.

После этого `scripts/build-iso.sh` передаёт подготовленный профиль в
`mkarchiso`. Только этот последний этап запускается через `sudo`; исходники и
бинарные компоненты собираются от обычного пользователя.

Установка выполняется без сети: Calamares копирует готовую live-систему из
ISO, включая MacqueenDE и все его пакеты времени выполнения, создаёт обычный
initramfs, устанавливает GRUB и включает SDDM. В SDDM заранее регистрируется
сеанс `MacqueenDE`, который выбирается установщиком как основной.

## Разработка Calamares

Исходники установщика находятся в [`components/calamares`](components/calamares).
Это обычные файлы внутри репозитория, поэтому будущий форк можно менять и
коммитить вместе с остальными компонентами KaskadOS.

Собрать Calamares:

```bash
make calamares-build
```

Собрать и открыть тестовый интерфейс без прав root:

```bash
make calamares-run
```

По умолчанию сборка создаётся в `build/calamares/` и не попадает в Git. Путь и
число параллельных задач можно переопределить:

```bash
CALAMARES_BUILD_DIR=/tmp/kaskados-calamares-build CALAMARES_JOBS=8 make calamares-build
```

Источник и точный upstream-коммит указаны в
[`components/README.md`](components/README.md).

## Основные каталоги

- `profile/packages.x86_64` — пакеты live-среды;
- `profile/airootfs/` — файлы, которые попадут в корень live-системы;
- `profile/profiledef.sh` — имя, метка, издатель и режимы загрузки ISO;
- `components/calamares/` — код и конфигурация установщика;
- `components/macqueende/` — полный исходный код рабочего стола MacqueenDE;
- `components/kaskad-installer-compositor/` — отдельная копия MacqueenDE для
  live-установщика;
- `profile/airootfs/usr/local/bin/kaskados-installer-session` — запуск
  Wayland-сессии;
- `profile/airootfs/usr/share/kaskados-installer/config/` — правила окна
  Calamares и конфигурация композитора.

Профиль зафиксирован из официального `archiso` v89. Точный источник указан в
[`UPSTREAM.md`](UPSTREAM.md). Это осознанная копия профиля, а не «весь Arch»:
пакеты Linux скачиваются из официальных репозиториев во время сборки.
