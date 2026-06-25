/// ClipboardPreferencesView.swift
///
/// A SwiftUI view for clipboard preferences, embedded in rawm's preferences window
/// as the "Clipboard" tab via ClipboardPreferencesViewController.

import AppKit
import Defaults
import SwiftUI

// MARK: - SwiftUI content

struct ClipboardPreferencesView: View {
    @Default(.size) private var historySize
    @Default(.ignoredApps) private var ignoredApps
    @Default(.enabledPasteboardTypes) private var enabledPasteboardTypes

    // Pasteboard type groups
    private let textTypes: [NSPasteboard.PasteboardType] = StorageType.text.types
    private let imageTypes: [NSPasteboard.PasteboardType] = StorageType.images.types
    private let fileTypes: [NSPasteboard.PasteboardType] = StorageType.files.types

    @State private var newIgnoredApp: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: History size
                GroupBox(label: Text("History").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Maximum history size:")
                            Spacer()
                            TextField("", value: $historySize, format: .number)
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                            Stepper("", value: $historySize, in: 1...10000)
                                .labelsHidden()
                        }
                        Text("Number of items to keep in clipboard history.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }

                // MARK: Pasteboard types
                GroupBox(label: Text("Track Pasteboard Types").font(.headline)) {
                    VStack(alignment: .leading, spacing: 6) {
                        typeToggleRow(label: "Text (plain text, RTF, HTML)", types: textTypes)
                        typeToggleRow(label: "Images (PNG, TIFF)", types: imageTypes)
                        typeToggleRow(label: "Files (file URLs)", types: fileTypes)
                        Text("Only content matching selected types will be recorded.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(8)
                }

                // MARK: Ignored applications
                GroupBox(label: Text("Ignored Applications").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        if ignoredApps.isEmpty {
                            Text("No applications are ignored.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(ignoredApps, id: \.self) { bundleId in
                                HStack {
                                    Text(bundleId)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Button {
                                        ignoredApps.removeAll { $0 == bundleId }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Divider()

                        HStack {
                            TextField("Bundle ID (e.g. com.1password.1password)", text: $newIgnoredApp)
                                .textFieldStyle(.roundedBorder)
                            Button("Add") {
                                let trimmed = newIgnoredApp.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty, !ignoredApps.contains(trimmed) else { return }
                                ignoredApps.append(trimmed)
                                newIgnoredApp = ""
                            }
                            .disabled(newIgnoredApp.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        Text("Clipboard changes from ignored applications will not be recorded.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 460, minHeight: 360)
    }

    // MARK: - Helpers

    /// Returns true when ALL types in the group are currently enabled.
    private func allEnabled(_ types: [NSPasteboard.PasteboardType]) -> Bool {
        types.allSatisfy { enabledPasteboardTypes.contains($0) }
    }

    @ViewBuilder
    private func typeToggleRow(label: String, types: [NSPasteboard.PasteboardType]) -> some View {
        Toggle(label, isOn: Binding(
            get: { allEnabled(types) },
            set: { enabled in
                if enabled {
                    types.forEach { enabledPasteboardTypes.insert($0) }
                } else {
                    types.forEach { enabledPasteboardTypes.remove($0) }
                }
            }
        ))
    }
}

// MARK: - NSViewController wrapper for prefs tab injection

/// A thin NSViewController that hosts the ClipboardPreferencesView SwiftUI view.
/// Inject via AppDelegate.injectClipboardPrefsTab().
final class ClipboardPreferencesViewController: NSViewController {

    override func loadView() {
        let hosting = NSHostingView(rootView: ClipboardPreferencesView())
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        self.view = hosting
    }

    static func freshController() -> ClipboardPreferencesViewController {
        return ClipboardPreferencesViewController()
    }
}
