/// RawmActionTypes.swift
///
/// Defines the RawmActionItem protocol and concrete action types for rawm's
/// unified hotkey/action dispatch system.
///
/// Note: The name `RawmAction` is already used in WindowManager.swift as a window-history
/// struct. The protocol here is named `RawmActionItem` to avoid collision.

import Foundation
import Cocoa

// MARK: - Protocol

/// A named, executable action that can be bound to a hotkey.
protocol RawmActionItem {
    /// Human-readable name shown in Shortcuts preferences.
    var name: String { get }
    /// Unique identifier used as NSUserDefaults key for persisting the shortcut binding.
    var defaultsKey: String { get }
    /// Execute the action.
    func execute()
}

// MARK: - WindowActionItem

/// Wraps Rectangle's existing WindowAction enum so it participates in the unified action system.
/// Window actions continue to be dispatched via ShortcutManager/MASShortcut;
/// this wrapper is used for display and persistence in the unified Shortcuts UI.
struct WindowActionItem: RawmActionItem {
    let windowAction: WindowAction

    var name: String { windowAction.displayName ?? windowAction.name }
    var defaultsKey: String { windowAction.name }

    func execute() {
        windowAction.post()
    }
}

// MARK: - ClipboardAction

/// Actions related to the clipboard history subsystem.
enum ClipboardAction: RawmActionItem {
    case showHistory
    case pasteItem(index: Int)

    var name: String {
        switch self {
        case .showHistory: return "Show Clipboard History"
        case .pasteItem(let i): return "Paste Clipboard Item \(i + 1)"
        }
    }

    var defaultsKey: String {
        switch self {
        case .showHistory: return "rawm.clipboard.showHistory"
        case .pasteItem(let i): return "rawm.clipboard.pasteItem.\(i)"
        }
    }

    func execute() {
        switch self {
        case .showHistory:
            Notification.Name.showClipboardHistory.post()
        case .pasteItem(let index):
            Notification.Name.pasteClipboardItem.post(object: index)
        }
    }
}

// Notification names for clipboard actions
extension Notification.Name {
    static let showClipboardHistory = Notification.Name("rawm.showClipboardHistory")
    static let pasteClipboardItem = Notification.Name("rawm.pasteClipboardItem")
}

// MARK: - ShellAction

/// Runs an arbitrary shell command, like skhd's `cmd + alt - t : open -a WezTerm`.
struct ShellAction: RawmActionItem {
    let name: String
    let command: String
    let defaultsKey: String

    /// - Parameters:
    ///   - name: Human-readable label (e.g. "Open WezTerm").
    ///   - command: The shell command to run (e.g. "open -a WezTerm").
    ///   - defaultsKey: Unique NSUserDefaults key for persisting this shortcut.
    init(name: String, command: String, defaultsKey: String? = nil) {
        self.name = name
        self.command = command
        // Derive a stable key from the command if none provided
        self.defaultsKey = defaultsKey ?? "rawm.shell.\(command.hashValue)"
    }

    func execute() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.qualityOfService = .userInitiated
        do {
            try process.run()
        } catch {
            NSLog("[rawm] ShellAction failed to run '\(command)': \(error)")
        }
    }
}

// MARK: - HotkeyRegistry

/// Persists the mapping from defaultsKey → RawmActionItem and registers bindings
/// with HotkeyEngine (for non-window actions) or ShortcutManager (for window actions).
///
/// Window actions are managed directly by ShortcutManager/MASShortcut — this registry
/// stores them for display in the unified Shortcuts UI but does not re-bind them.
class HotkeyRegistry {

    static let shared = HotkeyRegistry()

    /// All registered non-window-action items (ClipboardAction, ShellAction).
    /// Window actions are tracked separately via WindowAction.active.
    private(set) var nonWindowActions: [any RawmActionItem] = []

    private init() {}

    /// Register a ClipboardAction or ShellAction binding and activate it in HotkeyEngine.
    func register(_ action: any RawmActionItem) {
        // Don't double-register
        if nonWindowActions.contains(where: { $0.defaultsKey == action.defaultsKey }) { return }
        nonWindowActions.append(action)
        HotkeyEngine.shared.register(
            defaultsKey: action.defaultsKey,
            displayName: action.name,
            handler: { action.execute() }
        )
    }

    /// Unregister a binding by its defaults key.
    func unregister(defaultsKey: String) {
        nonWindowActions.removeAll { $0.defaultsKey == defaultsKey }
        HotkeyEngine.shared.unregister(defaultsKey: defaultsKey)
    }

    /// All displayed actions for the Shortcuts preferences pane:
    /// window actions + non-window actions, combined.
    var allActionsForDisplay: [any RawmActionItem] {
        let windowItems = WindowAction.active.map { WindowActionItem(windowAction: $0) }
        return (windowItems as [any RawmActionItem]) + nonWindowActions
    }
}
