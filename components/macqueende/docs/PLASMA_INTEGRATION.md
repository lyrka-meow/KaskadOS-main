# Plasma integration inventory

This document tracks every Plasma-specific integration inherited from KWin.
Nothing is deleted until its behavior has a replacement, an explicit
deprecation decision, or proof that MacqueenDE does not need it.

## Build-time integration found in KWin 6.7.3

| Area | Upstream dependency | Initial decision |
|---|---|---|
| Activities | PlasmaActivities | Disable after workspace behavior is mapped |
| Shell library | Plasma | Audit and remove from compositor core |
| Wayland protocols | PlasmaWaylandProtocols | Classify protocol by protocol |
| Internal UI | Plasma QML components | Replace with shell-neutral or Quickshell UI |
| Settings | Plasma KCM install namespaces | Move to Macqueen settings API/UI |
| Session service | plasma-kwin_wayland.service | Replace with Macqueen session units |

The legacy Plasma systemd user service is not installed by default. It remains
available temporarily behind `MACQUEEN_INSTALL_LEGACY_PLASMA_SERVICE=ON` for
compatibility investigations only.

## Plasma Wayland protocols inherited by KWin

The following protocols are currently consumed from
`plasma-wayland-protocols`:

- appmenu
- dpms
- fake-input
- idle
- kde-external-brightness-v1
- kde-lockscreen-overlay-v1
- kde-output-device-v2
- kde-output-management-v2
- kde-output-order-v1
- kde-screen-edge-v1
- keystate
- org-kde-plasma-virtual-desktop
- plasma-shell
- plasma-window-management
- server-decoration-palette
- server-decoration
- shadow
- slide
- text-input-unstable-v2
- zkde-screencast-unstable-v1

Each protocol will be classified as one of:

1. Replace with an upstream standard protocol.
2. Keep temporarily for compatibility.
3. Rename and version as a Macqueen protocol.
4. Remove after all consumers are migrated.

## Portal integration found in xdg-desktop-portal-kde 6.7.3

The portal currently links KDE Frameworks, Plasma KWayland client libraries,
and Plasma Wayland protocols. It also consumes private KWin D-Bus interfaces
for tablet mode and the virtual keyboard.

ScreenCast and RemoteDesktop behavior are migration-critical. File chooser and
general desktop dialogs may initially use a fallback backend while native
MolniyaMacqueenShell dialogs are designed.
