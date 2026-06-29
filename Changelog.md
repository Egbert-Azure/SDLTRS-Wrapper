# Changelog

All notable changes to TRS-80 Launcher are documented here. This project
follows [Semantic Versioning](https://semver.org/): MAJOR.MINOR.PATCH.

## [1.1] — 2026

### Added
- Machine presets: Model I · HRG1-B, Model III, Model 4, Model 4P, and
  TCS Genie IIIs. Selecting a preset sets the model and, for the
  Genie IIIs, enables the German/Genie character set automatically.
  (The Genie IIIs runs CP/M, G-DOS, and NEWDOS — the OS is whichever
  disk you boot.)
- Four hard-disk slots (`-hard0`–`-hard3`), with drag-and-drop, file
  picker, and eject — alongside the existing four floppy slots.
- Hard-disk geometry label shown per preset (e.g. 2460 cyl · 4 heads ·
  9 sec for the Genie IIIs); display-only, as sdltrs reads real geometry
  from the `.hdv`.
- App version now shown in the window header.
- Installed sdltrs version shown next to the sdltrs path, read from a
  `sdltrs-version.txt` that `update-sdltrs.sh` writes at install time
  (the source commit hash + date, since sdltrs has no `--version` flag).
- `update-sdltrs.sh` — on-demand script to pull and rebuild sdltrs from
  GitLab and install the binary where the launcher expects it (GPLv3).
  Verified building cleanly on Apple Silicon with Homebrew SDL2. Builds the
  `sdl2` branch (hardware rendering, resizable window; binary `sdl2trs`)
  per Jens Günther's recommendation.

### Changed
- `-nofloppy` is now appended only when both floppy and hard-disk slots are
  empty, so a hard-disk-only boot is no longer sabotaged.
- Window now scrolls to accommodate the additional slots.

## [1.0] — 2026

### Added
- Initial release: native macOS front-end for sdltrs / sdl2trs.
- Four drag-and-drop floppy slots (`-disk0`–`-disk3`).
- Model picker, `.t8c` config selection, ROM selection.
- German/Genie character set toggle (`-charset1 genie`).
- Automatic `-nofloppy` when no disk is loaded.
- GNU GPL v3.0 license.