// TRS80Launcher — a native macOS front-end for sdltrs
//
// Copyright (C) 2026 Egbert Schröer
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// ---------------------------------------------------------------------------
//
// Gives you a real Cocoa window: four drag-and-drop floppy slots, a model
// picker, optional .t8c config and ROM selection, then launches sdltrs
// underneath with the right command line.
//
// Build (in a VS Code terminal on macOS):
//   ./build.sh
// Then double-click TRS80Launcher.app, or `open TRS80Launcher.app`.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Persistent settings

final class Settings: ObservableObject {
    // Path to the sdl2trs binary or .app. The SDL2 fork's binary is
    // typically named "sdl2trs64"; adjust via the Locate… button.
    @AppStorage("sdltrsPath") var sdltrsPath: String =
        "/Applications/sdltrs/sdltrs.app"
    @AppStorage("configPath") var configPath: String = ""
    @AppStorage("romPath") var romPath: String = ""
    @AppStorage("model") var model: Int = 1
    @AppStorage("genieCharset") var genieCharset: Bool = false
    // Disk slots persisted as newline-joined paths.
    @AppStorage("disksJoined") var disksJoined: String = "\n\n\n"

    var disks: [String] {
        get {
            var parts = disksJoined.components(separatedBy: "\n")
            while parts.count < 4 { parts.append("") }
            return Array(parts.prefix(4))
        }
        set { disksJoined = newValue.prefix(4).joined(separator: "\n") }
    }
}

// MARK: - One floppy slot

struct DiskSlot: View {
    let index: Int
    @Binding var path: String
    @State private var hovering = false

    private var filename: String {
        path.isEmpty ? "— empty —"
                     : (path as NSString).lastPathComponent
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: path.isEmpty ? "opticaldiscdrive"
                                           : "opticaldiscdrive.fill")
                .font(.system(size: 22))
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Drive \(index)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(filename)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()

            Button { choose() } label: { Image(systemName: "folder") }
                .buttonStyle(.borderless).help("Choose a disk image…")

            Button { path = "" } label: { Image(systemName: "eject") }
                .buttonStyle(.borderless).help("Eject")
                .disabled(path.isEmpty)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovering ? Color.accentColor.opacity(0.15)
                               : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(hovering ? Color.accentColor : Color.clear,
                              lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $hovering) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { DispatchQueue.main.async { path = url.path } }
            }
            return true
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "dmk"),
            UTType(filenameExtension: "dsk"),
            UTType(filenameExtension: "jv1"),
            UTType(filenameExtension: "jv3"),
        ].compactMap { $0 }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

// MARK: - Main window

struct ContentView: View {
    @StateObject private var s = Settings()
    @State private var disks: [String] = ["", "", "", ""]
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 26))
                VStack(alignment: .leading) {
                    Text("TRS-80 Launcher").font(.title2.bold())
                    Text("Model I · HRG1-B graphics")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Model", selection: $s.model) {
                    Text("Model I").tag(1)
                    Text("Model III").tag(3)
                    Text("Model 4").tag(4)
                    Text("Model 4P").tag(5)
                }
                .pickerStyle(.menu).frame(width: 140)
            }

            Divider()

            Text("Floppy drives").font(.headline)
            ForEach(0..<4, id: \.self) { i in
                DiskSlot(index: i, path: Binding(
                    get: { disks[i] },
                    set: { disks[i] = $0; s.disks = disks }
                ))
            }

            Divider()

            // Config + sdltrs path
            HStack {
                Text("Config (.t8c)").frame(width: 90, alignment: .leading)
                Text(s.configPath.isEmpty ? "none"
                     : (s.configPath as NSString).lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Choose…") { pickConfig() }
                Button("Clear") { s.configPath = "" }
                    .disabled(s.configPath.isEmpty)
            }

            HStack {
                Text("ROM").frame(width: 90, alignment: .leading)
                Text(s.romPath.isEmpty ? "default"
                     : (s.romPath as NSString).lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Choose…") { pickRom() }
                Button("Clear") { s.romPath = "" }
                    .disabled(s.romPath.isEmpty)
            }

            Toggle("German / Genie character set (-charset1 genie)",
                   isOn: $s.genieCharset)
                .font(.caption)

            HStack {
                Text("sdltrs").frame(width: 90, alignment: .leading)
                Text((s.sdltrsPath as NSString).lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Locate…") { pickSdltrs() }
            }

            Divider()

            HStack {
                Text(status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    launch()
                } label: {
                    Label("Boot", systemImage: "play.fill")
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { disks = s.disks }
    }

    private func pickConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "t8c")].compactMap { $0 }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { s.configPath = url.path }
    }

    private func pickRom() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "bin"),
            UTType(filenameExtension: "rom"),
            UTType(filenameExtension: "hex"),
        ].compactMap { $0 }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { s.romPath = url.path }
    }

    private func pickSdltrs() {
        let panel = NSOpenPanel()
        // Allow both .app bundles and bare Unix executables (e.g. sdltrs /
        // sdl2trs64). No content-type filter, so nothing is greyed out.
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK, let url = panel.url { s.sdltrsPath = url.path }
    }

    // Build the command line and launch sdltrs via `open --args`.
    private func launch() {
        var args = ["--args"]

        // Config file first if present (loaded before startup).
        if !s.configPath.isEmpty { args.append(s.configPath) }

        args.append("-model\(s.model)")

        if !s.romPath.isEmpty {
            args.append("-rom")
            args.append(s.romPath)
        }

        if s.genieCharset {
            args.append("-charset1")
            args.append("genie")
        }

        var anyDisk = false
        for (i, disk) in disks.enumerated() where !disk.isEmpty {
            args.append("-disk\(i)")
            args.append(disk)
            anyDisk = true
        }

        // No boot disk in any slot → sdl2trs hangs on a black screen
        // waiting for a nonexistent floppy. -nofloppy drops to ROM BASIC.
        if !anyDisk { args.append("-nofloppy") }

        let proc = Process()
        let app = s.sdltrsPath

        if app.hasSuffix(".app") {
            // Use macOS `open` to launch the bundle with args.
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = [app] + args
        } else {
            // Direct binary (e.g. sdl2trs64): drop the leading "--args".
            proc.executableURL = URL(fileURLWithPath: app)
            proc.arguments = Array(args.dropFirst())
        }

        do {
            try proc.run()
            status = "Launched."
        } catch {
            status = "Launch failed: \(error.localizedDescription)"
            NSSound.beep()
        }
    }
}

// MARK: - App entry

@main
struct TRS80LauncherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}