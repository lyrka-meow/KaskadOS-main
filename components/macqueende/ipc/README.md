# Macqueen IPC

Macqueen IPC is the compositor's public, versioned shell API. Version 1 is
available on the D-Bus session bus:

- service: `org.macqueen.Compositor1`
- object: `/org/macqueen/Compositor1`
- interface: `org.macqueen.Compositor1`

## Version 1

The initial interface is deliberately read-only. A session client can discover
the protocol and compositor versions, list windows, outputs and workspaces, and
subscribe to changes.

Methods:

- `protocolVersion() -> uint`
- `compositorVersion() -> string`
- `activeWindow() -> map`
- `windows() -> list<map>`
- `outputs() -> list<map>`
- `workspaces() -> list<map>`
- `activateWorkspace(id) -> bool`
- `createWorkspace(position, name) -> string`
- `removeWorkspace(id) -> bool`
- `renameWorkspace(id, name) -> bool`
- `activateWindow(id) -> bool`
- `closeWindow(id) -> bool`
- `setWindowMinimized(id, minimized) -> bool`
- `setWindowFullscreen(id, fullscreen) -> bool`
- `moveWindowToWorkspace(windowId, workspaceId) -> bool`

Workspace positions are one-based. Passing position `0` to `createWorkspace`
appends the new workspace.

Signals:

- `windowAdded(id)`
- `windowRemoved(id)`
- `windowChanged(id, fields)`
- `activeWindowChanged(id)`
- `outputsChanged()`
- `workspacesChanged()`

The maps use stable lower-camel-case field names. Consumers must ignore unknown
fields so version 1 can gain optional data without breaking clients.

## Test from a terminal

Within a running Macqueen session:

```bash
qdbus6 org.macqueen.Compositor1 /org/macqueen/Compositor1 \
    org.macqueen.Compositor1.protocolVersion
```

Screen capture and remote input are not part of this interface. They require
portal-mediated authorization. Window and workspace commands are available to
clients in the user's session.
