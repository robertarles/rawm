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

/// Wraps rawm's existing WindowAction enum so it participates in the unified action system.
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
        case .showHistory: return "rawmClipboardShowHistory"
        case .pasteItem(let i): return "rawmClipboardPasteItem\(i)"
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
        // Build a stable key from the command string itself (hashValue is not stable across launches in Swift)
        let safeKey = command.unicodeScalars.map {
            ($0.value >= 65 && $0.value <= 90)   // A-Z
            || ($0.value >= 97 && $0.value <= 122) // a-z
            || ($0.value >= 48 && $0.value <= 57)  // 0-9
            ? String($0) : "_"
        }.joined().prefix(60)
        self.defaultsKey = defaultsKey ?? "rawmShell_\(safeKey)"
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

    private static let persistenceKey = "rawm.hotkeyRegistry.actions.v1"

    private init() {}

    // MARK: - Registration

    /// Register a ClipboardAction or ShellAction binding and activate it in HotkeyEngine.
    func register(_ action: any RawmActionItem) {
        if nonWindowActions.contains(where: { $0.defaultsKey == action.defaultsKey }) { return }
        nonWindowActions.append(action)
        HotkeyEngine.shared.register(
            defaultsKey: action.defaultsKey,
            displayName: action.name,
            handler: { action.execute() }
        )
        persist()
    }

    /// Unregister a binding by its defaults key.
    func unregister(defaultsKey: String) {
        nonWindowActions.removeAll { $0.defaultsKey == defaultsKey }
        HotkeyEngine.shared.unregister(defaultsKey: defaultsKey)
        persist()
    }

    // MARK: - Persistence

    /// Save the current nonWindowActions list to UserDefaults.
    func persist() {
        let stored = nonWindowActions.compactMap { StoredAction(from: $0) }
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    /// Reload persisted nonWindowActions from UserDefaults and re-register with HotkeyEngine.
    /// Call this at startup (after HotkeyEngine.shared.enable()).
    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let stored = try? JSONDecoder().decode([StoredAction].self, from: data) else { return }
        // Old format used dotted keys (e.g. "rawm.clipboard.showHistory") which crash
        // MASShortcutBinder (it asserts no dots allowed). Detect stale data and wipe it
        // so migration re-runs with the current dot-free key format.
        if stored.contains(where: { $0.defaultsKey.contains(".") || $0.defaultsKey.contains(" ") }) {
            UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
            return
        }
        for s in stored {
            guard let action = s.toAction() else { continue }
            // register without re-persisting to avoid churn
            if nonWindowActions.contains(where: { $0.defaultsKey == action.defaultsKey }) { continue }
            nonWindowActions.append(action)
            HotkeyEngine.shared.register(
                defaultsKey: action.defaultsKey,
                displayName: action.name,
                handler: { action.execute() }
            )
        }
    }

    // MARK: - Display

    var allActionsForDisplay: [any RawmActionItem] {
        let windowItems = WindowAction.active.map { WindowActionItem(windowAction: $0) }
        return (windowItems as [any RawmActionItem]) + nonWindowActions
    }
}

// MARK: - StoredAction (Codable bridge for HotkeyRegistry persistence)

private struct StoredAction: Codable {
    let type: String        // "shell" | "clipboard.showHistory" | "clipboard.pasteItem"
    let name: String
    let defaultsKey: String
    let extra: String?      // command for shell; item index for pasteItem

    init?(from action: any RawmActionItem) {
        if let shell = action as? ShellAction {
            self.type = "shell"
            self.name = shell.name
            self.defaultsKey = shell.defaultsKey
            self.extra = shell.command
        } else if let clipboard = action as? ClipboardAction {
            self.name = action.name
            self.defaultsKey = action.defaultsKey
            switch clipboard {
            case .showHistory:
                self.type = "clipboard.showHistory"
                self.extra = nil
            case .pasteItem(let i):
                self.type = "clipboard.pasteItem"
                self.extra = "\(i)"
            }
        } else {
            return nil
        }
    }

    func toAction() -> (any RawmActionItem)? {
        switch type {
        case "shell":
            guard let command = extra else { return nil }
            return ShellAction(name: name, command: command, defaultsKey: defaultsKey)
        case "clipboard.showHistory":
            return ClipboardAction.showHistory
        case "clipboard.pasteItem":
            let index = Int(extra ?? "0") ?? 0
            return ClipboardAction.pasteItem(index: index)
        default:
            return nil
        }
    }
}
