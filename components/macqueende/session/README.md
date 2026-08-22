# MacqueenDE session

The repository launcher starts a complete development session without Plasma:

```bash
./start-macqueende
```

Run it from a real login TTY after logging out of the current graphical
session. It starts Macqueen on DRM, enables rootless Xwayland, and launches
MolniyaMacqueenShell as the session process. Exiting Molniya also exits
Macqueen.

To add MacqueenDE to SDDM without replacing any existing session:

```bash
./session/install-dev-session.sh
```

The development entry points back to this checkout, so do not move or delete
the repository after installing it. Remove the entry with:

```bash
./session/uninstall-dev-session.sh
```

This is a development session. Distribution packages will install versioned
binaries and QML modules instead of referring to a source checkout.
