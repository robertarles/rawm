/// ClipboardBootstrap.swift
///
/// Wires the clipboard subsystem into rawm's app lifecycle.
/// All clipboard types (Clipboard, History, AppState, FloatingPanel, etc.)
/// must be accessible since they are all compiled into the rawm module.

import AppKit
import Defaults
import SwiftUI

// MARK: - Clipboard bootstrap (called from AppDelegate.applicationDidFinishLaunching)

extension AppDelegate {
    /// Start the clipboard history subsystem. Call from applicationDidFinishLaunching.
    @MainActor
    func startClipboardSubsystem() {
        // Wire history: every new copy gets added to History.
        Clipboard.shared.onNewCopy { item in
            Task { @MainActor in
                _ = History.shared.add(item)
            }
        }

        // Create the floating popup panel that shows clipboard history.
        let size = Defaults[.windowSize]
        let identifier = "\(Bundle.main.bundleIdentifier ?? "com.robertarles.rawm").clipboard"
        clipboardPopupPanel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            identifier: identifier,
            statusBarButton: nil,
            onClose: { AppState.shared.popup.reset() }
        ) {
            AnyView(ContentView()
                .modelContainer(Storage.shared.container))
        }

        // Give the Popup the ability to open/close/resize the panel via AppState.appDelegate.
        AppState.shared.appDelegate = self

        // Wire the showHistory notification from HotkeyEngine to open the popup.
        NotificationCenter.default.addObserver(
            forName: .showClipboardHistory,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                let popup = AppState.shared.popup
                popup.open(height: popup.height)
            }
        }

        // Start polling the NSPasteboard for changes.
        Clipboard.shared.start()
    }
}

// MARK: - Panel property on AppDelegate (accessed by Popup, SlideoutController, etc.)

extension AppDelegate {
    /// Storage key for the clipboard popup panel, held in an associated object.
    private static var clipboardPanelKey = "clipboardPanel"

    /// The clipboard history popup panel. Accessed by the clipboard subsystem's Popup and SlideoutController.
    var clipboardHistoryPanel: FloatingPanel<AnyView>? {
        get {
            return objc_getAssociatedObject(self, &AppDelegate.clipboardPanelKey) as? FloatingPanel<AnyView>
        }
    }

    fileprivate var clipboardPopupPanel: FloatingPanel<AnyView>? {
        get {
            return objc_getAssociatedObject(self, &AppDelegate.clipboardPanelKey) as? FloatingPanel<AnyView>
        }
        set {
            objc_setAssociatedObject(self, &AppDelegate.clipboardPanelKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
