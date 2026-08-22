# MacqueenDE architecture

## Design rule

Macqueen is the session-critical process. The shell is replaceable and may
restart without terminating applications or the compositor.

```text
Applications
    |
Wayland / XWayland
    |
Macqueen compositor
    |-- standard Wayland protocols
    |-- versioned Macqueen IPC
    |-- PipeWire capture integration
    |
    +-- Quickshell Macqueen module
    |       |
    |       +-- MolniyaMacqueenShell
    |
    +-- xdg-desktop-portal-macqueen
```

## Components

### Macqueen compositor

The compositor begins as a traceable derivative of KWin 6.7.3. The public
executable is `macqueen`. Initially it keeps working internals intact while
public identity, session ownership, and shell integration are separated from
Plasma.

Subsystems retained as the technical foundation:

- DRM/KMS and virtual output backends
- input and libinput integration
- Wayland protocol server
- window management and focus
- rendering, effects, and color management
- XWayland
- screencast plumbing

### Macqueen IPC

The IPC is a public, versioned API rather than an accidental exposure of
internal compositor objects. Its first stable surface will cover:

- outputs
- workspaces
- toplevel windows
- focus and activation
- window commands
- shortcuts
- layout and tiling state
- effect and overview requests
- event subscriptions

Standard Wayland protocols remain preferred wherever they express the required
semantics. Macqueen IPC is used for compositor-specific features.

### Quickshell integration

The Quickshell module maps Macqueen IPC objects and events to typed QML-facing
objects. MolniyaMacqueenShell consumes the same public API available to other
shell projects.

### Desktop portal

`xdg-desktop-portal-macqueen` begins as a derivative of
`xdg-desktop-portal-kde` 6.7.3. ScreenCast, RemoteDesktop, Screenshot, and
PipeWire behavior are preserved first. KDE-specific compositor calls and user
interfaces are then replaced with Macqueen IPC and shell-owned selection UI.

## Failure boundaries

- A shell crash must not terminate Macqueen or client applications.
- A portal crash must terminate only its active capture sessions.
- IPC clients are untrusted session clients; authorization cannot depend only
  on possession of the Wayland socket.
- Screen capture and remote input require explicit portal-mediated consent.
- Configuration parsing errors must fall back safely and remain diagnosable.

## Initial milestones

1. Reproduce upstream KWin and KDE portal builds.
2. Run the compositor nested without replacing the current desktop.
3. Introduce Macqueen identity and a standalone development session.
4. Launch a minimal Quickshell surface using standard layer-shell.
5. Add versioned IPC and the Quickshell module.
6. Port screen sharing and remote desktop.
7. Build MolniyaMacqueenShell and Arch packages.
