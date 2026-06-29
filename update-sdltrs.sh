#!/bin/bash
# update-sdltrs.sh — pull the latest sdltrs from GitLab and (re)build it.
# Version 1.0
#
# Copyright (C) 2026 Egbert Schröer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# ----------------------------------------------------------------------------
#
# On-demand updater: run it when you want to check for a new version. It
# clones on first run, pulls on later runs, and rebuilds only if the pull
# actually brought new commits. The freshly built binary is copied to the
# install location your launcher points at.
#
# This builds sdltrs (the emulator) — NOT this launcher. The cloned emulator
# source lives OUTSIDE this repo (see SRC_DIR); only this script belongs in it.
#
# ── Prerequisites (one-time) ────────────────────────────────────────────────
#   1. Homebrew:   https://brew.sh
#   2. Build deps: brew install cmake sdl2
#   3. Git:        already present if you use GitHub Desktop / Xcode tools
#
# ── Usage ───────────────────────────────────────────────────────────────────
#   chmod +x update-sdltrs.sh
#   ./update-sdltrs.sh
#
# Edit the two paths below to match your machine, then run.

set -e

SCRIPT_VERSION="1.0"

# ── Configuration ───────────────────────────────────────────────────────────

# Where the sdltrs source lives (its own folder, separate from the launcher).
SRC_DIR="$HOME/Documents/GitHub/sdltrs-src"

# Where to put the finished binary — the folder your launcher's Locate points
# at. Default matches the TRS80M1 layout seen in this project.
INSTALL_DIR="$HOME/Documents/GitHub/TRS80M1"

# GitLab repository (Jens Günther's actively-maintained SDL2 fork).
REPO="https://gitlab.com/jengun/sdltrs.git"

# ── Helpers ─────────────────────────────────────────────────────────────────

say() { printf "\033[1;36m==>\033[0m %s\n" "$1"; }
die() { printf "\033[1;31mError:\033[0m %s\n" "$1" >&2; exit 1; }

say "update-sdltrs v$SCRIPT_VERSION"

# ── Prerequisite checks ─────────────────────────────────────────────────────

command -v git   >/dev/null 2>&1 || die "git not found."
command -v cmake >/dev/null 2>&1 || die "cmake not found. Run: brew install cmake"
# SDL2 presence is checked indirectly by the build; brew install sdl2 if it fails.

# ── Clone or update ─────────────────────────────────────────────────────────

# Build the SDL2 branch, NOT master. Per Jens Günther: the sdl2 branch has
# hardware (texture) rendering and a mouse-resizable window; master uses the
# software renderer and a fixed window size. The binary on this branch is
# named "sdl2trs".
BRANCH="sdl2"

NEED_BUILD=0

if [ ! -d "$SRC_DIR/.git" ]; then
    say "First run — cloning sdltrs ($BRANCH branch) into $SRC_DIR"
    git clone --branch "$BRANCH" "$REPO" "$SRC_DIR"
    NEED_BUILD=1
else
    say "Checking for updates on $BRANCH branch…"
    cd "$SRC_DIR"
    # Make sure we're on the sdl2 branch even if an earlier run used master.
    git checkout "$BRANCH" 2>/dev/null || die "Could not switch to $BRANCH branch."
    BEFORE=$(git rev-parse HEAD)
    git pull --ff-only
    AFTER=$(git rev-parse HEAD)
    if [ "$BEFORE" != "$AFTER" ]; then
        say "New version pulled ($BEFORE → $AFTER)."
        NEED_BUILD=1
    else
        say "Already up to date."
    fi
fi

# Allow a forced rebuild with: ./update-sdltrs.sh --force
[ "$1" = "--force" ] && NEED_BUILD=1

if [ "$NEED_BUILD" -eq 0 ]; then
    say "Nothing to build. Use --force to rebuild anyway."
    exit 0
fi

# ── Build ───────────────────────────────────────────────────────────────────

cd "$SRC_DIR"
say "Building (Release)…"
rm -rf build
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j"$(sysctl -n hw.ncpu)"

# ── Locate the built binary ─────────────────────────────────────────────────
# The binary name varies (sdltrs / sdl2trs / sdl2trs64). Find it rather than
# assume.
say "Locating built binary…"
BIN=$(find "$SRC_DIR/build" -type f -perm -111 \
        \( -name "sdltrs" -o -name "sdl2trs*" \) \
        ! -name "*.dylib" 2>/dev/null | head -n1)

[ -z "$BIN" ] && die "Build finished but no sdltrs binary found in build/. \
Check the build output above; the binary name or output path may differ."

# ── Install ─────────────────────────────────────────────────────────────────

mkdir -p "$INSTALL_DIR"
DEST="$INSTALL_DIR/$(basename "$BIN")"
cp "$BIN" "$DEST"
chmod +x "$DEST"

# Record the exact source version next to the binary so the launcher can
# display it. Format: a short, human-readable string.
cd "$SRC_DIR"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_DATE=$(git show -s --format=%cd --date=short HEAD 2>/dev/null || echo "")
GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
VERSION_FILE="$INSTALL_DIR/sdltrs-version.txt"
{
    [ -n "$GIT_TAG" ] && printf "%s " "$GIT_TAG"
    printf "(%s" "$GIT_HASH"
    [ -n "$GIT_DATE" ] && printf ", %s" "$GIT_DATE"
    printf ")\n"
} > "$VERSION_FILE"

say "Installed: $DEST"
say "Version:   $(cat "$VERSION_FILE")"
say "Point the launcher's 'Locate sdltrs' here if you haven't already."
say "Done."