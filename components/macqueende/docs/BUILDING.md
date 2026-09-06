# Building MacqueenDE

MacqueenDE currently targets Arch Linux for its first reproducible development
environment.

## Safety

Development builds install to `/opt/macqueen-dev` only when explicitly
requested. Configuring or compiling the project does not replace the active
KWin process. Do not run `ninja install` against `/usr`.

## Current baseline dependency

The Plasma 6.7.3 source baseline requires Plasma Wayland protocol definitions:

```bash
sudo pacman -S --needed plasma-wayland-protocols
```

This dependency is intentionally retained during the reproducibility milestone.
The protocols are inventoried in `PLASMA_INTEGRATION.md` and will later be
replaced, retained for compatibility, or moved into the versioned Macqueen
protocol set.

## Configure

```bash
cmake -S compositor -B build/compositor -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueen-dev \
  -DBUILD_TESTING=OFF

cmake -S portal -B build/portal -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueen-dev \
  -DBUILD_TESTING=OFF

cmake -S quickshell/macqueen-module -B build/quickshell-macqueen -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX=/opt/macqueen-dev
```

The build directories are ignored by Git.

## Build the verified baseline

The first development target is the Wayland compositor rather than every
upstream settings module:

```bash
cmake --build build/compositor --target macqueen --parallel 8
cmake --build build/compositor --target screenshot --parallel 8
cmake --build build/compositor --target screencast --parallel 8
cmake --build build/compositor --target nightlight --parallel 8
cmake --build build/portal --parallel 8
cmake --build build/quickshell-macqueen --parallel 8
```

Reduce the parallel count on systems with less than 16 GiB of RAM.

The desktop session uses the Arch `flameshot` package for interactive
screenshots:

```bash
sudo pacman -S --needed flameshot
```

The compositor screenshot and screencast plugins and Macqueen portal remain
part of the build because they provide the Wayland capture paths used by
Flameshot, browsers and communication applications.

## Virtual smoke test

Run the compositor without taking control of a display, input device, or the
current Wayland session:

```bash
./scripts/smoke-virtual.sh
./scripts/smoke-ipc.sh
./scripts/smoke-quickshell.sh
./scripts/smoke-window-ipc.sh
```

The script creates isolated runtime, configuration, cache, and data
directories. It starts a 1280x720 virtual output, disables screen locking,
global shortcuts, and activities, then exits with a trivial child session.

The imported 6.7.3 baseline was successfully configured, compiled, and tested
this way on Arch Linux with:

- Linux 7.1.4
- GCC 16.1.1
- Qt 6.11.1
- KDE Frameworks 6.28.0
- Plasma Wayland Protocols 1.21.0

## Development sequence

1. Configure and compile the unmodified source baselines.
2. Create a nested compositor smoke-test command.
3. Add Macqueen identity without installing a system session.
4. Only after nested tests pass, add a separate display-manager session.
