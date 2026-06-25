/// ClipboardStartup.swift
///
/// Provides the clipboardPanel property for use by Popup, SlideoutController, etc.
/// Actual startup is called from ClipboardManager.start() (in ClipboardManager.swift).

import AppKit
import Defaults
import SwiftUI

// MARK: - Panel storage

/// Stores the clipboard FloatingPanel so Popup/SlideoutController can access it
/// without going through AppDelegate.
final class ClipboardPanelStore {
    static let shared = ClipboardPanelStore()
    var panel: FloatingPanel<ContentView>?
    private init() {}
}
