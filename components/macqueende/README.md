# MacqueenDE

MacqueenDE is the Wayland desktop environment of KaskadOS, built around
**Macqueen**, a compositor derived from KWin and designed for first-class
integration with Quickshell. Its authoritative source now lives in
`components/macqueende/` of the KaskadOS-main repository.

The project is an alpha preview. It installs as a separate desktop session and
does not replace the system KWin package. Keep another working session
available while testing it.

## Installation in KaskadOS

MacqueenDE is built by `scripts/prepare-live-profile.sh` from the KaskadOS-main
repository. The resulting runtime is included in the ISO and copied by
Calamares without downloading the desktop during installation. SDDM receives a
ready `MacqueenDE` Wayland session and selects it as the default desktop.

The scripts in `installer/` and `packaging/` are retained as development and
release tooling, but they are not used by the KaskadOS installer.

## Project goals

- Keep the mature rendering, input, display, XWayland, and effects foundations
  inherited from KWin.
- Run independently from Plasma Shell.
- Provide a documented, versioned Macqueen IPC.
- Make Quickshell a first-class shell platform through a dedicated integration
  module.
- Ship MolniyaMacqueenShell as the reference desktop shell.
- Provide native screen sharing and remote desktop through
  `xdg-desktop-portal-macqueen`.
- Package and test the complete session reproducibly on Arch Linux.

## Repository layout

```text
compositor/                 Macqueen compositor sources
ipc/                        Public protocol and client libraries
quickshell/macqueen-module/ Quickshell integration module
shell/MolniyaMacqueenShell/ Reference shell
portal/                     xdg-desktop-portal-macqueen
session/                    Session startup and service definitions
packaging/arch/             Arch Linux packaging
installer/                  Release bootstrap installers
docs/                       Architecture and development documentation
```

## Development policy

The first milestone is a reproducible, nested development session. Macqueen
must not replace the system compositor during early development. Changes are
tested nested first, then in a separate TTY/session, and only later packaged as
a system session.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[docs/UPSTREAM.md](docs/UPSTREAM.md). Local configuration and build
instructions are in [docs/BUILDING.md](docs/BUILDING.md).

## Test in a window

From an existing KDE Wayland or Hyprland session, run:

```bash
./scripts/run-nested.sh
```

This opens a 1280x720 nested MacqueenDE session without replacing the host
desktop portal. Override the size with `MACQUEEN_NESTED_WIDTH` and
`MACQUEEN_NESTED_HEIGHT`.

## Start a direct development session

After building the compositor, Quickshell module, and Molniya backend, log out
of the current graphical desktop, enter a TTY, and run:

```bash
./start-macqueende
```

To add a separate `MacqueenDE` entry to SDDM:

```bash
./session/install-dev-session.sh
```

## Licensing

MacqueenDE contains components derived from upstream projects with their own
license sets and copyright notices. The license files imported with each
component are authoritative for that component. New project-level work is
licensed under GPL-3.0 unless a component requires a compatible alternative.
