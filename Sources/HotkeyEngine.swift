/// HotkeyEngine.swift
///
/// A supplemental hotkey engine for rawm that handles non-window action bindings
/// (ClipboardAction, ShellAction). Window actions continue to be handled by
/// ShortcutManager/MASShortcut as before.
///
/// Design: MASShortcut is sufficient for all hotkey needs since it wraps CGEventTap
/// and supports arbitrary closures via MASShortcutBinder. This engine manages the
/// lifecycle and registry for rawm-specific (non-window) action bindings.

import Foundation
import MASShortcut

/// Represents a hotkey binding: a defaults key, an optional display name, and a closure.
struct HotkeyBinding {
    let defaultsKey: String
    let displayName: String
    let handler: () -> Void
}

/// HotkeyEngine manages non-window-action hotkey bindings using MASShortcut.
/// It mirrors ShortcutManager's lifecycle (enabled/disabled, suspend for recording).
class HotkeyEngine {

    static let shared = HotkeyEngine()

    private var bindings: [String: HotkeyBinding] = [:]
    private var isEnabled: Bool = false
    private var isSuspendedForRecording: Bool = false
    private var isDeactivatedForShortcutsDisabled: Bool = false

    private init() {
        // Observe shortcut recording state so we can suspend during recording
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutRecordingChanged),
            name: .shortcutRecording,
            object: nil
        )
        // Suspend when shortcuts are globally disabled (ApplicationToggle)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appShortcutsDisabledChanged),
            name: .frontAppChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Binding Registration

    /// Register a hotkey binding. The binding is stored and activated if the engine is enabled.
    /// - Parameters:
    ///   - defaultsKey: The NSUserDefaults key used to persist this shortcut (must be unique).
    ///   - displayName: Human-readable name shown in the Shortcuts preferences pane.
    ///   - handler: The closure to invoke when this hotkey fires.
    func register(defaultsKey: String, displayName: String, handler: @escaping () -> Void) {
        let binding = HotkeyBinding(defaultsKey: defaultsKey, displayName: displayName, handler: handler)
        bindings[defaultsKey] = binding
        if isEnabled && !isSuspendedForRecording {
            activateBinding(binding)
        }
    }

    /// Unregister and unbind a hotkey by its defaults key.
    func unregister(defaultsKey: String) {
        MASShortcutBinder.shared()?.breakBinding(withDefaultsKey: defaultsKey)
        bindings.removeValue(forKey: defaultsKey)
    }

    /// Remove all bindings.
    func unregisterAll() {
        for key in bindings.keys {
            MASShortcutBinder.shared()?.breakBinding(withDefaultsKey: key)
        }
        bindings.removeAll()
    }

    // MARK: - Lifecycle

    /// Enable the engine and activate all registered bindings.
    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        if !isSuspendedForRecording {
            activateAllBindings()
        }
    }

    /// Disable the engine and deactivate all bindings.
    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        deactivateAllBindings()
    }

    // MARK: - Default Shortcut Registration

    /// Register a default shortcut for a defaults key.
    /// Writes to persistent UserDefaults so the binding survives subsequent launches.
    /// Only writes if no value is already in the persistent domain (preserves user customizations).
    func registerDefault(defaultsKey: String, keyCode: Int, modifierFlags: NSEvent.ModifierFlags) {
        let shortcut = MASShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
        // Check the persistent domain only — registration domain values from registerDefaultShortcuts
        // also appear via object(forKey:), so we must check persistence directly.
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let persisted = UserDefaults.standard.persistentDomain(forName: bundleID)
        if persisted?[defaultsKey] == nil {
            if let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName)),
               let dict = transformer.reverseTransformedValue(shortcut) as? [String: Any] {
                UserDefaults.standard.set(dict, forKey: defaultsKey)
            }
        }
        // Also register in-memory default (belt-and-suspenders for MASShortcut internals)
        MASShortcutBinder.shared()?.registerDefaultShortcuts([defaultsKey: shortcut])
    }

    // MARK: - Private Helpers

    private func activateBinding(_ binding: HotkeyBinding) {
        MASShortcutBinder.shared()?.bindShortcut(withDefaultsKey: binding.defaultsKey, toAction: binding.handler)
    }

    private func activateAllBindings() {
        for binding in bindings.values {
            activateBinding(binding)
        }
    }

    private func deactivateAllBindings() {
        for key in bindings.keys {
            MASShortcutBinder.shared()?.breakBinding(withDefaultsKey: key)
        }
    }

    // MARK: - Notification Handlers

    @objc private func shortcutRecordingChanged(_ notification: Notification) {
        guard let isRecording = notification.object as? Bool else { return }
        if isRecording {
            guard !isSuspendedForRecording else { return }
            isSuspendedForRecording = true
            deactivateAllBindings()
        } else {
            guard isSuspendedForRecording else { return }
            isSuspendedForRecording = false
            if isEnabled && !ApplicationToggle.shortcutsDisabled {
                activateAllBindings()
            }
        }
    }

    @objc private func appShortcutsDisabledChanged(_ notification: Notification) {
        if ApplicationToggle.shortcutsDisabled {
            if !isDeactivatedForShortcutsDisabled {
                deactivateAllBindings()
                isDeactivatedForShortcutsDisabled = true
            }
        } else if isDeactivatedForShortcutsDisabled {
            // Only re-activate when recovering from a disabled state — not on every front-app change.
            // Calling activateAllBindings() redundantly causes MASShortcutBinder to crash when
            // it tries to re-bind an already-bound key.
            isDeactivatedForShortcutsDisabled = false
            if isEnabled && !isSuspendedForRecording {
                activateAllBindings()
            }
        }
    }
}
