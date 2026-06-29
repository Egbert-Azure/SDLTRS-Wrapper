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
// Gives you a real Cocoa window: machine presets, four drag-and-drop floppy
// slots, four hard-disk slots, model / ROM / config / charset controls, then
// launches sdltrs underneath with the right command line.
//
// Build (in a VS Code terminal on macOS):
//   ./build.sh
// Then double-click TRS80Launcher.app, or `open TRS80Launcher.app`.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Version

// Single source of truth for the app version. Keep in sync with the
// CFBundleShortVersionString in Info.plist.
let appVersion = "1.1"

// MARK: - Machine presets

// A preset bundles the model number, an optional ROM hint, whether the
// Genie/German character set applies, and the expected hard-disk geometry
// (display-only — sdltrs reads real geometry from the .hdv itself).
struct Machine: Identifiable, Hashable {
    let id: String
    let label: String
    let model: Int
    let usesGenieCharset: Bool
    let geometry: String?   // e.g. "2460 cyl · 4 heads · 9 sec", or nil

    static let all: [Machine] = [
        Machine(id: "model1",  label: "Model I · HRG-1B",
                model: 1, usesGenieCharset: false, geometry: nil),
        Machine(id: "model3",  label: "Model III",
                model: 3, usesGenieCharset: false, geometry: nil),
        Machine(id: "model4",  label: "Model 4",
                model: 4, usesGenieCharset: false, geometry: nil),
        Machine(id: "model4p", label: "Model 4P",
                model: 5, usesGenieCharset: false, geometry: nil),
        Machine(id: "genie3s", label: "TCS Genie IIIs",
                model: 3, usesGenieCharset: true,
                geometry: "2460 cyl · 4 heads · 9 sec"),
    ]

    static func by(id: String) -> Machine {
        all.first { $0.id == id } ?? all[0]
    }
}

// MARK: - Persistent settings

final class Settings: ObservableObject {
    // Path to the sdltrs / sdl2trs binary or .app. Adjust via Locate….
    @AppStorage("sdltrsPath") var sdltrsPath: String =
        "/Applications/sdltrs/sdltrs.app"
    @AppStorage("configPath") var configPath: String = ""
    @AppStorage("romPath") var romPath: String = ""
    @AppStorage("machineID") var machineID: String = "model1"
    @AppStorage("genieCharset") var genieCharset: Bool = false
    // Drive slots persisted as newline-joined paths (4 each).
    @AppStorage("disksJoined") var disksJoined: String = "\n\n\n"
    @AppStorage("hardsJoined") var hardsJoined: String = "\n\n\n"

    private func four(_ joined: String) -> [String] {
        var parts = joined.components(separatedBy: "\n")
        while parts.count < 4 { parts.append("") }
        return Array(parts.prefix(4))
    }

    var disks: [String] {
        get { four(disksJoined) }
        set { disksJoined = newValue.prefix(4).joined(separator: "\n") }
    }
    var hards: [String] {
        get { four(hardsJoined) }
        set { hardsJoined = newValue.prefix(4).joined(separator: "\n") }
    }

    var machine: Machine { Machine.by(id: machineID) }
}

// MARK: - One drive slot (floppy or hard disk)

enum DriveKind {
    case floppy, hard
    var label: String { self == .floppy ? "Drive" : "Hard" }
    var emptyIcon: String {
        self == .floppy ? "opticaldiscdrive" : "internaldrive"
    }
    var filledIcon: String {
        self == .floppy ? "opticaldiscdrive.fill" : "internaldrive.fill"
    }
    var fileTypes: [String] {
        self == .floppy ? ["dmk", "dsk", "jv1", "jv3"] : ["hdv", "dsk"]
    }
}

struct DriveSlot: View {
    let kind: DriveKind
    let index: Int
    @Binding var path: String
    @State private var hovering = false

    private var filename: String {
        path.isEmpty ? "— empty —" : (path as NSString).lastPathComponent
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: path.isEmpty ? kind.emptyIcon : kind.filledIcon)
                .font(.system(size: 22))
                .foregroundStyle(path.isEmpty ? .secondary : .primary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(kind.label) \(index)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(filename)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()

            Button { choose() } label: { Image(systemName: "folder") }
                .buttonStyle(.borderless).help("Choose an image…")

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
        panel.allowedContentTypes = kind.fileTypes
            .compactMap { UTType(filenameExtension: $0) }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { path = url.path }
    }
}

// MARK: - Main window

struct ContentView: View {
    @StateObject private var s = Settings()
    @State private var disks: [String] = ["", "", "", ""]
    @State private var hards: [String] = ["", "", "", ""]
    @State private var status = ""

    private var machine: Machine { s.machine }

    // Reads sdltrs-version.txt sitting next to the binary (written by
    // update-sdltrs.sh). Returns nil if absent.
    private var sdltrsVersion: String? {
        let dir = (s.sdltrsPath as NSString).deletingLastPathComponent
        let vfile = (dir as NSString).appendingPathComponent("sdltrs-version.txt")
        guard let text = try? String(contentsOfFile: vfile, encoding: .utf8)
        else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                floppySection
                Divider()
                hardSection
                Divider()
                settingsSection
                Divider()
                footer
            }
            .padding(20)
            .frame(width: 480)
        }
        .frame(width: 480, height: 760)
        .onAppear {
            disks = s.disks
            hards = s.hards
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "desktopcomputer").font(.system(size: 26))
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("TRS-80 Launcher").font(.title2.bold())
                    Text("v\(appVersion)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text(machine.label)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Machine", selection: $s.machineID) {
                ForEach(Machine.all) { m in
                    Text(m.label).tag(m.id)
                }
            }
            .pickerStyle(.menu).frame(width: 180)
            .onChange(of: s.machineID) { applyPreset() }
        }
    }

    private var floppySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Floppy drives").font(.headline)
            ForEach(0..<4, id: \.self) { i in
                DriveSlot(kind: .floppy, index: i, path: Binding(
                    get: { disks[i] },
                    set: { disks[i] = $0; s.disks = disks }
                ))
            }
        }
    }

    private var hardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hard disks").font(.headline)
                Spacer()
                if let g = machine.geometry {
                    Text(g)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(0..<2, id: \.self) { i in
                DriveSlot(kind: .hard, index: i, path: Binding(
                    get: { hards[i] },
                    set: { hards[i] = $0; s.hards = hards }
                ))
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(label: "Config (.t8c)",
                value: s.configPath.isEmpty ? "none"
                    : (s.configPath as NSString).lastPathComponent,
                choose: pickConfig,
                clear: { s.configPath = "" },
                clearDisabled: s.configPath.isEmpty)

            row(label: "ROM",
                value: s.romPath.isEmpty ? "default"
                    : (s.romPath as NSString).lastPathComponent,
                choose: pickRom,
                clear: { s.romPath = "" },
                clearDisabled: s.romPath.isEmpty)

            Toggle("German / Genie character set (-charset1 genie)",
                   isOn: $s.genieCharset)
                .font(.caption)

            HStack {
                Text("sdltrs").frame(width: 90, alignment: .leading)
                Text((s.sdltrsPath as NSString).lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                if let v = sdltrsVersion {
                    Text(v)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .opacity(0.7)
                        .lineLimit(1)
                }
                Spacer()
                Button("Locate…") { pickSdltrs() }
            }
        }
    }

    private func row(label: String, value: String,
                     choose: @escaping () -> Void,
                     clear: @escaping () -> Void,
                     clearDisabled: Bool) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("Choose…", action: choose)
            Button("Clear", action: clear).disabled(clearDisabled)
        }
    }

    private var footer: some View {
        HStack {
            Text(status).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { launch() } label: {
                Label("Boot", systemImage: "play.fill").frame(minWidth: 80)
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
        }
    }

    // Picking a preset sets the charset default. Model is derived from the
    // preset at launch time; ROM is left alone (user-specific file path).
    private func applyPreset() {
        s.genieCharset = machine.usesGenieCharset
    }

    private func pickConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "t8c")].compactMap { $0 }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { s.configPath = url.path }
    }

    private func pickRom() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["bin", "rom", "hex"]
            .compactMap { UTType(filenameExtension: $0) }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { s.romPath = url.path }
    }

    private func pickSdltrs() {
        let panel = NSOpenPanel()
        // Allow both .app bundles and bare Unix executables (sdltrs /
        // sdl2trs64). No content-type filter, so nothing is greyed out.
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK, let url = panel.url { s.sdltrsPath = url.path }
    }

    // Build the command line and launch sdltrs.
    private func launch() {
        var args = ["--args"]

        // Config file first if present (loaded before startup).
        if !s.configPath.isEmpty { args.append(s.configPath) }

        args.append("-model\(machine.model)")

        if !s.romPath.isEmpty {
            args.append("-rom"); args.append(s.romPath)
        }
        if s.genieCharset {
            args.append("-charset1"); args.append("genie")
        }

        var anyFloppy = false
        for (i, disk) in disks.enumerated() where !disk.isEmpty {
            args.append("-disk\(i)"); args.append(disk)
            anyFloppy = true
        }
        for (i, hd) in hards.enumerated() where !hd.isEmpty {
            args.append("-hard\(i)"); args.append(hd)
        }

        // No boot floppy → drop to ROM BASIC instead of hanging on a black
        // screen. (Hard-disk-only boot still works via the emulator itself.)
        if !anyFloppy && hards.allSatisfy({ $0.isEmpty }) {
            args.append("-nofloppy")
        }

        let proc = Process()
        let app = s.sdltrsPath
        if app.hasSuffix(".app") {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = [app] + args
        } else {
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