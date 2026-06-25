/// ShortcutMigration.swift
///
/// Pre-populates rawm's shortcut configuration on first launch with:
/// 1. The user's existing Rectangle window action bindings (from their Rectangle plist)
/// 2. The user's skhd app-launcher bindings (cmd+alt+a/f/t/etc.)
/// 3. A clipboard history shortcut (ctrl+cmd+c → showHistory)
///
/// All shortcuts are stored as UserDefaults defaults — users can change or remove
/// them at any time through the rawm Shortcuts preferences pane.

import Foundation
import MASShortcut
import Carbon

// MARK: - ShortcutMigration

enum ShortcutMigration {

    /// The UserDefaults key that tracks whether migration has already run.
    /// v3: fixes persistent-domain check so shortcut defaults actually survive relaunches.
    private static let migrationDoneKey = "rawm.shortcutMigration.v3.done"

    /// Run migration if it has not already been performed.
    /// Call this from AppDelegate.applicationDidFinishLaunching, after ShortcutManager is initialized.
    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationDoneKey) else { return }
        performMigration()
        UserDefaults.standard.set(true, forKey: migrationDoneKey)
    }

    private static func performMigration() {
        migrateWindowShortcuts()
        migrateShellActionShortcuts()
        migrateClipboardShortcuts()
    }

    // MARK: - Window Shortcuts

    /// Pre-populate Rectangle window action shortcuts from the user's Rectangle plist.
    /// Only sets defaults if the user has no existing rawm shortcut for that action.
    private static func migrateWindowShortcuts() {
        let userPlistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.knollsoft.Rectangle.plist")

        var sourceDefaults: [String: Any] = [:]

        if let plistData = try? Data(contentsOf: userPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
            sourceDefaults = plist
        }

        // Mapping from WindowAction name to the user's desired shortcut (from their Rectangle plist + spec)
        // If the key exists in Rectangle's plist, use it; otherwise use the hardcoded default from the epic spec.
        let userWindowShortcuts: [(WindowAction, Int, NSEvent.ModifierFlags)] = [
            // Top Left: cmd+ctrl+u
            (.topLeft, kVK_ANSI_U, [.command, .control]),
            // Top Right: cmd+ctrl+i
            (.topRight, kVK_ANSI_I, [.command, .control]),
            // Bottom Left: cmd+ctrl+j
            (.bottomLeft, kVK_ANSI_J, [.command, .control]),
            // Bottom Right: cmd+ctrl+k
            (.bottomRight, kVK_ANSI_K, [.command, .control]),
            // Maximize: cmd+ctrl+,
            (.maximize, kVK_ANSI_Comma, [.command, .control]),
            // Center Half: cmd+ctrl+c
            (.centerHalf, kVK_ANSI_C, [.command, .control]),
            // Center Two Thirds: cmd+shift+c
            (.centerTwoThirds, kVK_ANSI_C, [.command, .shift]),
            // Left Two Thirds (firstTwoThirds): cmd+shift+left
            (.firstTwoThirds, kVK_LeftArrow, [.command, .shift]),
            // Right Two Thirds (lastTwoThirds): cmd+shift+right
            (.lastTwoThirds, kVK_RightArrow, [.command, .shift]),
            // Previous Display: cmd+ctrl+left
            (.previousDisplay, kVK_LeftArrow, [.command, .control]),
            // Next Display: cmd+ctrl+right
            (.nextDisplay, kVK_RightArrow, [.command, .control]),
        ]

        for (action, keyCode, modifiers) in userWindowShortcuts {
            let defaultsKey = action.name

            // First, check if the Rectangle plist already has a shortcut for this action
            if let rectangleShortcut = sourceDefaults[defaultsKey] as? [String: Any] {
                // Use the existing Rectangle shortcut
                MASShortcutBinder.shared()?.registerDefaultShortcuts([defaultsKey: shortcutFromDict(rectangleShortcut)])
            } else if UserDefaults.standard.dictionary(forKey: defaultsKey) == nil {
                // No existing shortcut — use the spec default
                let shortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifiers)
                MASShortcutBinder.shared()?.registerDefaultShortcuts([defaultsKey: shortcut])
            }
            // If UserDefaults already has the key, leave it unchanged (user has customized it)
        }
    }

    // MARK: - Shell Action Shortcuts

    /// Pre-populate shell app-launcher shortcuts from the user's skhd config.
    private static func migrateShellActionShortcuts() {
        let cmdAlt: NSEvent.ModifierFlags = [.command, .option]

        let shellBindings: [(String, String, Int)] = [
            // (name, command, keyCode)
            ("Open Claude",           "open -a Claude",                kVK_ANSI_A),
            ("Open Finder",           "open -a Finder",                kVK_ANSI_F),
            ("Open WezTerm",          "open -a WezTerm",               kVK_ANSI_T),
            ("Open Microsoft Teams",  "open -a \"Microsoft Teams\"",   kVK_ANSI_E),
            ("Open Messages",         "open -a Messages",              kVK_ANSI_I),
            ("Open Mail",             "open -a Mail",                  kVK_ANSI_M),
            ("Open Safari",           "open -a Safari",                kVK_ANSI_B),
            ("Open Visual Studio Code","open -a \"Visual Studio Code\"",kVK_ANSI_C),
            ("Open Music",            "open -a Music",                 kVK_ANSI_8),
            ("Open Neovide",          "open -a Neovide",               kVK_ANSI_V),
        ]

        for (name, command, keyCode) in shellBindings {
            let action = ShellAction(name: name, command: command)
            // Register the default shortcut binding
            HotkeyEngine.shared.registerDefault(
                defaultsKey: action.defaultsKey,
                keyCode: keyCode,
                modifierFlags: cmdAlt
            )
            // Register the action in the registry (for display and execution)
            HotkeyRegistry.shared.register(action)
        }
    }

    // MARK: - Clipboard Shortcuts

    /// Pre-populate clipboard action shortcuts.
    private static func migrateClipboardShortcuts() {
        let showHistory = ClipboardAction.showHistory
        // ctrl+cmd+c → showHistory
        HotkeyEngine.shared.registerDefault(
            defaultsKey: showHistory.defaultsKey,
            keyCode: kVK_ANSI_C,
            modifierFlags: [.control, .command]
        )
        HotkeyRegistry.shared.register(showHistory)
    }

    // MARK: - Helpers

    private static func shortcutFromDict(_ dict: [String: Any]) -> MASShortcut? {
        guard let dictTransformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName)) else { return nil }
        return dictTransformer.transformedValue(dict) as? MASShortcut
    }
}
