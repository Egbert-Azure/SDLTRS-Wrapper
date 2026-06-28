# TRS-80 Launcher

A native macOS front-end for **sdltrs / sdl2trs** (Jens Günther's SDL2 fork of
SDLTRS, <https://gitlab.com/jengun/sdltrs>). It gives you a real Cocoa window
with machine presets, four floppy slots, four hard-disk slots, and ROM /
config / character-set controls, then launches the emulator underneath with
the right command line.

It is a **launcher**, not a new emulator. The running emulator window is still
sdltrs. This fixes the disk-loading and configuration friction — not the
in-emulator menus.

Originally built for a Model I with the HRG1-B high-resolution graphics card;
now also covers Model III / 4 / 4P and the TCS Genie IIIs (which runs CP/M,
G-DOS, and NEWDOS). HRG1-B
emulation is automatic in Model I mode, so no extra flag is needed.

**Version 1.1** · GPLv3 · © 2026 Egbert Schröer

---

## What's in here

```
TRS80Launcher/
├── README.md           ← this file
├── CHANGELOG.md        ← version history
├── LICENSE             ← GNU GPL v3.0 (full text)
├── build.sh            ← compiles the app
├── update-sdltrs.sh    ← pulls + rebuilds the sdltrs emulator (optional)
├── Info.plist          ← app bundle metadata
├── .gitignore
└── Sources/
    └── main.swift      ← the entire app (SwiftUI)
```

> **Important layout note:** `main.swift` must live inside the `Sources/`
> subfolder. If it ends up loose next to `build.sh`, the build fails with
> *"error opening input file 'Sources/main.swift'"*. Fix:
> `mkdir -p Sources && mv main.swift Sources/`.

---

## Requirements

- macOS 13 (Ventura) or newer
- Xcode command-line tools (provides the `swiftc` compiler)
- A working macOS build of **sdltrs** — from
  <https://gitlab.com/jengun/sdltrs>. You want the **macOS Unix executable**
  (named `sdltrs` or `sdl2trs64`), *not* the `.exe` Windows file. The included
  `update-sdltrs.sh` can build it for you (see below).

---

## Build the launcher — step by step

Everything happens in the VS Code terminal (**Terminal → New Terminal**).

### Step 0 — Check the Swift compiler

```sh
swiftc --version
```

If it prints a version, continue. If it says *command not found*, install the
tools (click **Install** in the dialog, then wait):

```sh
xcode-select --install
```

If it replies *"Command line tools are already installed"*, you're done.

### Step 1 — Open this folder

In VS Code: **File → Open Folder →** select the project folder. Open a
terminal; it will already point here. Confirm with `ls` that you see
`build.sh`, `Info.plist`, `README.md`, and `Sources`.

### Step 2 — Build

```sh
chmod +x build.sh
./build.sh
```

On success it prints `Done. Launch with:  open TRS80Launcher.app`.

### Step 3 — Run

```sh
open TRS80Launcher.app
```

If macOS blocks it (*"unidentified developer"*), right-click
`TRS80Launcher.app` in Finder → **Open → Open**. Only needed once.

---

## The `@main` build error (and the fix)

Because the source file is named `main.swift`, Swift treats it as top-level
code, which collides with the `@main` attribute:

```
error: 'main' attribute cannot be used in a module that contains top-level code
```

The fix is the `-parse-as-library` flag, **already included in `build.sh`**.
If you compile by hand, use:

```sh
swiftc -O -parse-as-library -framework SwiftUI -framework AppKit \
  -o TRS80Launcher Sources/main.swift
```

Then assemble the bundle (also what `build.sh` does):

```sh
rm -rf TRS80Launcher.app
mkdir -p TRS80Launcher.app/Contents/MacOS TRS80Launcher.app/Contents/Resources
cp Info.plist TRS80Launcher.app/Contents/Info.plist
mv TRS80Launcher TRS80Launcher.app/Contents/MacOS/TRS80Launcher
chmod +x TRS80Launcher.app/Contents/MacOS/TRS80Launcher
codesign --force --deep --sign - TRS80Launcher.app
open TRS80Launcher.app
```

---

## Using the launcher

1. **Machine** — pick a preset (top-right): Model I · HRG1-B, Model III,
   Model 4, Model 4P, or TCS Genie IIIs. The preset sets the model
   number and, for the Genie IIIs, enables the German/Genie character set.
   (The Genie IIIs runs CP/M, G-DOS, and NEWDOS — pick whichever the disk
   you're booting uses.)
2. **Locate sdltrs** — point this at your `sdltrs` (or `sdl2trs64`) binary.
   See the next section if the file appears greyed out. If you built the
   binary with `update-sdltrs.sh`, the installed source version (tag, commit
   hash, and date — e.g. `1.2.35 (e699d607, 2026-06-19)`) is shown next to
   the path. sdltrs has no `--version` flag, so this is read from a
   `sdltrs-version.txt` the build script writes beside the binary; locate a
   binary built another way and the version simply doesn't show.
3. **Floppy drives 0–3** — drag a `.dmk` / `.dsk` onto a slot, or use the
   folder button. Maps to `-disk0`…`-disk3` (0-based).
4. **Hard disks 0–3** — drag a `.hdv` onto a slot. Maps to `-hard0`…`-hard3`.
   When a preset has a known geometry (e.g. the Genie IIIs at
   2460 cyl · 4 heads · 9 sec) it's shown as a label; sdltrs reads the real
   geometry from the `.hdv` itself.
5. **Config (.t8c)** — optional. Passed first so it loads before boot,
   preserving double-density and per-drive geometry.
6. **ROM** — optional. For a standard Model I boot you usually don't need it;
   if the emulator complains, pick your `LEVEL2.ROM`. Required for
   Genie / TCS setups.
7. **German / Genie character set** — adds `-charset1 genie`.
8. **Boot** (or press Return).

All settings persist between launches.

> **No-floppy hang:** if **both** floppy and hard-disk slots are empty, the
> launcher adds `-nofloppy` so the emulator drops into ROM BASIC instead of
> hanging on a black screen. A hard-disk-only boot is not affected.

---

## If "Locate sdltrs" shows the binary greyed out

A bare Unix executable can appear non-selectable in the file dialog. Easiest
fix first:

**A. Set the path from the terminal (most reliable).** Find the binary's full
path (in Finder, right-click → hold **Option** → **Copy "sdltrs" as
Pathname**), then:

```sh
defaults write name.schroeer.trs80launcher sdltrsPath "/full/path/to/sdltrs"
```

Quit the launcher (Cmd+Q) and reopen it. Example:

```sh
defaults write name.schroeer.trs80launcher sdltrsPath \
  "$HOME/Documents/GitHub/TRS80M1/sdltrs"
```

**B. Go-to-folder in the dialog.** Locate… → **Cmd+Shift+G**, paste the full
path, Return, Open.

**C. Rebuild.** The current `main.swift` already removes the file-type filter,
so a fresh `./build.sh` makes the binary directly clickable.

---

## Keeping sdltrs up to date — `update-sdltrs.sh`

An optional helper that pulls the latest sdltrs from GitLab and rebuilds it.
It is **on-demand** (you run it; it is not a background job) and only rebuilds
when the pull actually brings new commits.

**One-time setup:**

```sh
brew install cmake sdl2
```

**Run:**

```sh
chmod +x update-sdltrs.sh
./update-sdltrs.sh          # add --force to rebuild without changes
```

Edit the two paths at the top first:

- `SRC_DIR` — where the emulator source is cloned (a **separate** folder; the
  emulator's source never goes into this repo)
- `INSTALL_DIR` — where the built binary lands (point your launcher here)

Alongside the binary the script writes `sdltrs-version.txt` (the tag, commit
hash, and date of the source it built). The launcher reads this to show the
installed sdltrs version next to its path. It also prints the version when it
runs, and the commit hash lets you crosscheck against GitLab's master to
confirm you're current.

> The script builds **sdltrs the emulator**, which is separate from this
> launcher. Only the script lives in this repo; the cloned source stays
> outside it. Verified working on Apple Silicon with Homebrew SDL2 (the build
> includes hard-disk and Genie/clone support). If a future repo change moves
> the binary or its output path, the script searches for it and reports if it
> can't find it.

---

## Command line it produces

Model I with a config, ROM, and a disk in drive 0:

```sh
sdltrs sdltrsTRS80.t8c -model1 -rom LEVEL2.ROM -disk0 esnd-01.dmk
```

Genie IIIs with two hard-disk volumes:

```sh
sdltrs -model3 -rom genie.rom -charset1 genie \
  -hard0 g3s-hard21-f1.hdv -hard1 g3s-hard21-f2.hdv
```

For a `.app` target, the launcher prefixes `open … --args` automatically.

---

## Troubleshooting

- **`error opening input file 'Sources/main.swift'`** — `main.swift` is in the
  wrong place. `mkdir -p Sources && mv main.swift Sources/`.
- **`'main' attribute cannot be used…`** — missing `-parse-as-library`; use
  `build.sh` or the hand-compile line above.
- **sdltrs greyed out in Locate** — see the section above; `defaults write`
  always works.
- **`.onChange` deprecation warning (macOS 14+)** — harmless; the code uses
  the form that compiles on both macOS 13 and 14+.
- **HRG1-B graphics don't render** — emulator/config matter, not a launcher
  bug. Confirm Model I mode and that the disk drives the HRG1-B.
- **`update-sdltrs.sh` build fails** — almost always a missing dependency;
  run `brew install cmake sdl2`. The build is otherwise verified working on
  Apple Silicon; if a repo change relocates the binary, the script reports
  that it couldn't find it.

---

## License

This launcher is free software under the **GNU General Public License v3.0** —
see [`LICENSE`](LICENSE) for the full text.

    TRS80Launcher — a native macOS front-end for sdltrs
    Copyright (C) 2026 Egbert Schröer

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

sdltrs itself is separate software under its own BSD 2-Clause license by
Jens Günther; this launcher only invokes it and does not include its code.
(BSD-2-Clause is GPL-compatible, so there is no conflict.)