import KeyboardShortcuts
import Sauce
import SwiftUI

extension KeyboardShortcuts.Shortcut {
    /// Convert to SwiftUI KeyEquivalent for use in Button/Menu shortcuts.
    func toKeyEquivalent() -> KeyEquivalent? {
        // Use Sauce to convert the carbon key code to a character
        guard let character = Sauce.shared.character(for: Int(carbonKeyCode), carbonModifiers: Int(carbonModifiers)) else {
            return nil
        }
        guard let scalar = character.unicodeScalars.first else { return nil }
        return KeyEquivalent(Character(scalar))
    }

    /// Convert NSEvent.ModifierFlags to SwiftUI EventModifiers.
    func toEventModifiers() -> EventModifiers {
        var result: EventModifiers = []
        if modifiers.contains(.command) { result.insert(.command) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.control) { result.insert(.control) }
        if modifiers.contains(.option) { result.insert(.option) }
        return result
    }
}
