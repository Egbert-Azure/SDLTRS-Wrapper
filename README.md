# TRS-80 Launcher

A small native macOS front-end for **sdltrs / sdl2trs** (Jens Günther's SDL2
fork of SDLTRS, <https://gitlab.com/jengun/sdltrs>). It gives you a real Cocoa
window with four drag-and-drop floppy slots, a model picker, and ROM / config /
character-set controls, then launches the emulator underneath with the right
command line.

It is a **launcher**, not a new emulator. The running emulator window is still
sdltrs. This fixes the disk-loading and configuration friction — not the
in-emulator menus.

Built for a Model I with the HRG1-B high-resolution graphics card. HRG1-B
emulation is automatic in Model I mode, so no extra flag is needed.

---

## What's in here

```
TRS80Launcher/
├── README.md          ← this file
├── LICENSE            ← GNU GPL v3.0 (full text)
├── build.sh           ← compiles the app
├── Info.plist         ← app bundle metadata
├── .gitignore
└── Sources/
    └── main.swift     ← the entire app (SwiftUI)
```

> **Important layout note:** `main.swift` must live inside the `Sources/`
> subfolder. If it ends up loose next to `build.sh`, the build fails with
> *"error opening input file 'Sources/main.swift'"*. Fix:
> `mkdir -p Sources && mv main.swift Sources/`.

---

## Requirements

- macOS 13 (Ventura) or newer
- Xcode command-line tools (provides the `swiftc` compiler)
- A working macOS build of **sdltrs** — download from
  <https://gitlab.com/jengun/sdltrs>. You want the **macOS Unix executable**
  (named `sdltrs` or `sdl2trs64`), *not* the `.exe` Windows file.

---

## Build it — step by step

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

If it replies *"Command line tools are already installed"*, you're done — that
note means there's nothing to install.

### Step 1 — Open this folder

In VS Code: **File → Open Folder →** select the project folder. Open a
terminal; it will already point here. Confirm:

```sh
ls
```

You should see `build.sh`, `Info.plist`, `README.md`, and `Sources`.

### Step 2 — Build

```sh
chmod +x build.sh
./build.sh
```

`chmod` makes the script runnable (needed only once). On success it prints:

```
Done. Launch with:  open TRS80Launcher.app
```

### Step 3 — Run

```sh
open TRS80Launcher.app
```

If macOS blocks it (*"unidentified developer"*), right-click
`TRS80Launcher.app` in Finder → **Open → Open**. Only needed once.

---

## The `@main` build error (and the fix)

Because the source file is named `main.swift`, Swift treats it as top-level
code, which collides with the `@main` attribute. If you compile without the fix
you get:

```
error: 'main' attribute cannot be used in a module that contains top-level code
```

The fix is the `-parse-as-library` flag, which is **already included in
`build.sh`**. If you ever compile by hand, use:

```sh
swiftc -O -parse-as-library -framework SwiftUI -framework AppKit \
  -o TRS80Launcher Sources/main.swift
```

Then assemble the bundle (this is also what `build.sh` does):

```sh
rm -rf TRS80Launcher.app
mkdir -p TRS80Launcher.app/Contents/MacOS
mkdir -p TRS80Launcher.app/Contents/Resources
cp Info.plist TRS80Launcher.app/Contents/Info.plist
mv TRS80Launcher TRS80Launcher.app/Contents/MacOS/TRS80Launcher
chmod +x TRS80Launcher.app/Contents/MacOS/TRS80Launcher
codesign --force --deep --sign - TRS80Launcher.app
open TRS80Launcher.app
```

---

## Using the launcher

1. **Locate sdltrs** — point this at your `sdltrs` (or `sdl2trs64`) binary. See
   the next section if the file appears greyed out.
2. **Model** — defaults to Model I (HRG1-B active automatically).
3. **Floppy drives 0–3** — drag a `.dmk` / `.dsk` straight onto a slot, or use
   the folder button. The eject button clears a slot. Drive numbering is
   0-based.
4. **Config (.t8c)** — optional. Passed as the first argument so it loads
   before boot, preserving double-density and per-drive geometry.
5. **ROM** — optional. For a standard Model I boot you usually don't need it; if
   the emulator complains, pick your `LEVEL2.ROM`. Needed explicitly for
   Genie / TCS / Schmidtke setups (e.g. `vg1-TCS-rom.bin`).
6. **German / Genie character set** — adds `-charset1 genie`, useful for G-DOS
   disks.
7. **Boot** (or press Return) — launches the emulator.

All settings persist between launches.

> **No-floppy hang:** if no slot has a disk, the launcher adds `-nofloppy`
> automatically so the emulator drops into ROM BASIC instead of hanging on a
> black screen.

---

## If "Locate sdltrs" shows the binary greyed out

A bare Unix executable can appear non-selectable in the file dialog. Three ways
around it, easiest first:

**A. Set the path from the terminal (most reliable).** Find the binary's full
path (in Finder, right-click it → hold **Option** → **Copy "sdltrs" as
Pathname**), then:

```sh
defaults write name.schroeer.trs80launcher sdltrsPath "/full/path/to/sdltrs"
```

Quit the launcher (Cmd+Q) and reopen it; the field will show the binary.

Example with a typical path:

```sh
defaults write name.schroeer.trs80launcher sdltrsPath \
  "/Users/egbert/Documents/GitHub/TRS80M1/sdltrs"
```

**B. Go-to-folder in the dialog.** Click **Locate… → Cmd+Shift+G**, paste the
full path, press Return, then Open.

**C. Rebuild with the loosened picker.** The current `main.swift` already
removes the file-type filter, so a fresh `./build.sh` makes the binary directly
clickable. (Older builds had `allowedContentTypes = [.application]`, which
caused the grey-out.)

---

## Command line it produces

For Model I with a config, a ROM, and a disk in drive 0:

```sh
sdltrs sdltrsTRS80.t8c -model1 -rom LEVEL2.ROM -disk0 esnd-01.dmk
```

With the Genie charset toggle on, `-charset1 genie` is added. For a `.app`
target, the launcher prefixes `open … --args` automatically.

---

## Troubleshooting

- **`error opening input file 'Sources/main.swift'`** — `main.swift` is in the
  wrong place. `mkdir -p Sources && mv main.swift Sources/`.
- **`'main' attribute cannot be used…`** — missing `-parse-as-library`; use
  `build.sh` or the hand-compile line above.
- **sdltrs greyed out in Locate** — see the section above; the `defaults write`
  route always works.
- **HRG1-B graphics don't render** — emulator/config matter, not a launcher
  bug. Confirm Model I mode and that the disk drives the HRG1-B.
- **`$BIN` empty when compiling by hand** — that variable only exists inside
  `build.sh`. Use a literal output name: `-o TRS80Launcher`.

---

## License

This launcher is free software, licensed under the **GNU General Public
License v3.0** — see the [`LICENSE`](LICENSE) file for the full text.

    TRS80Launcher — a native macOS front-end for sdltrs
    Copyright (C) 2026 Egbert Schröer

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

sdltrs itself is separate software under its own BSD 2-Clause license by
Jens Günther; this launcher only invokes it and does not include its code.
(BSD-2-Clause is GPL-compatible, so there is no conflict.)