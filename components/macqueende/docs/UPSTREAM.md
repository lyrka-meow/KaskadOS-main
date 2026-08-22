# Upstream provenance

The initial source baseline matches the packages installed on the development
Arch Linux system.

## KWin

- Repository: `https://invent.kde.org/plasma/kwin.git`
- Tag: `v6.7.3`
- Tag object: `ace9edf5e53744fa55e383a8230cb9113272b016`
- Source commit: `45ec9a6d0ed312a803ff5658a2a3e61f221566c6`
- Destination: `compositor/`

## xdg-desktop-portal-kde

- Repository: `https://invent.kde.org/plasma/xdg-desktop-portal-kde.git`
- Tag: `v6.7.3`
- Tag object: `d06eeac60eb3e45e7079c7734ea9307a822dc4b8`
- Source commit: `662e677c616f241f77f21beb3075eff56dcd7d99`
- Destination: `portal/`

## Update policy

Upstream updates are reviewed and imported deliberately. Macqueen-specific
changes must not be mixed with provenance commits. Every import records the
upstream commit, reviews license changes, and passes nested-session tests
before release.

