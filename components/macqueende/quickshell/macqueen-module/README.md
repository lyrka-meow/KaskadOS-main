# Quickshell Macqueen module

This QML module exposes Macqueen IPC as typed, reactive properties. It is a
regular external Qt module, so using it does not require a Quickshell fork.

```qml
import Macqueen.Ipc 1.0

Text {
    text: Macqueen.available && Macqueen.activeWindow.title
        ? Macqueen.activeWindow.title
        : "Desktop"
}
```

The singleton provides:

- `available`
- `protocolVersion`
- `compositorVersion`
- `activeWindow`
- `windows`
- `outputs`
- `workspaces`

All state properties emit change notifications when the compositor sends an
IPC event. The module also reconnects when Macqueen is restarted.

## Build

```bash
cmake -S quickshell/macqueen-module -B build/quickshell-macqueen \
  -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build/quickshell-macqueen
```

During development, add the build directory to the QML import path:

```bash
QML2_IMPORT_PATH="$PWD/build/quickshell-macqueen" quickshell
```
