#!/bin/bash
# Build TRS80Launcher.app from source.
# Run in a macOS terminal (VS Code terminal is fine). Requires Xcode
# command-line tools (`xcode-select --install` if `swiftc` is missing).

set -e

APP="TRS80Launcher.app"
BIN="TRS80Launcher"

echo "Compiling…"
swiftc -O -parse-as-library \
    -framework SwiftUI -framework AppKit \
    -o "$BIN" \
    Sources/main.swift

echo "Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
mv "$BIN" "$APP/Contents/MacOS/$BIN"
chmod +x "$APP/Contents/MacOS/$BIN"

# Ad-hoc codesign so Gatekeeper lets it launch locally.
codesign --force --deep --sign - "$APP" 2>/dev/null || \
    echo "(codesign skipped — app will still run locally)"

echo "Done. Launch with:  open $APP"
