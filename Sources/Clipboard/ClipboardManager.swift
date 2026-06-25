/// ClipboardManager.swift
///
/// Thin wrapper that delegates clipboard startup to AppDelegate's startClipboardSubsystem().
/// This allows AppDelegate.applicationDidFinishLaunching to call ClipboardManager.shared.start().

import AppKit

/// ClipboardManager bridges the Maccy clipboard subsystem into rawm.
/// Call start() from AppDelegate.applicationDidFinishLaunching on the main thread.
final class ClipboardManager {
    static let shared = ClipboardManager()
    private init() {}

    /// Initialize and start the clipboard subsystem.
    /// Delegates to AppDelegate.startClipboardSubsystem() which creates the
    /// FloatingPanel and starts NSPasteboard polling.
    @MainActor
    func start() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.startClipboardSubsystem()
    }
}
