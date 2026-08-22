# Installer

The public installer opens a numeric terminal menu and can either compile the
current `main` branch or download a checksummed binary artifact. Both modes
install into `/opt/macqueende` and add one `MacqueenDE` Wayland session to
SDDM. Existing display-manager configuration is not replaced.

Normal pacman, CMake, Ninja, and download output is kept in
`~/.local/state/macqueende/install-*.log`. Only progress stages and the tail of
the log on failure are shown in the terminal.

The installed `macqueende-manager` command displays the installation method,
version, source commit, and runtime state of the compositor, Quickshell, DMS
backend, and portal. Its numeric menu supports updates through either method
and complete system-file removal while preserving user configuration.

MacqueenDE uses one permanent GitHub release tagged `macqueende-rolling`.
After committing and building the current sources, maintainers replace its
assets with:

```bash
./packaging/github/publish-rolling-release.sh VERSION
```

The publisher refuses to create a missing release, uploads the new archive
before deleting old assets, and moves the rolling tag to the published commit.
