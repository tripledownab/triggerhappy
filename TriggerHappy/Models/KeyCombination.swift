import AppKit
import Carbon.HIToolbox

struct KeyCombination: Codable, Hashable, Equatable {
    let keyCode: UInt16
    let modifiers: ModifierSet

    struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
        let rawValue: UInt

        static let command = ModifierSet(rawValue: 1 << 0)
        static let option  = ModifierSet(rawValue: 1 << 1)
        static let control = ModifierSet(rawValue: 1 << 2)
        static let shift   = ModifierSet(rawValue: 1 << 3)

        init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        init(from nsFlags: NSEvent.ModifierFlags) {
            var raw: UInt = 0
            if nsFlags.contains(.command) { raw |= ModifierSet.command.rawValue }
            if nsFlags.contains(.option)  { raw |= ModifierSet.option.rawValue }
            if nsFlags.contains(.control) { raw |= ModifierSet.control.rawValue }
            if nsFlags.contains(.shift)   { raw |= ModifierSet.shift.rawValue }
            self.rawValue = raw
        }

        var displayString: String {
            var parts: [String] = []
            if contains(.control) { parts.append("\u{2303}") }
            if contains(.option)  { parts.append("\u{2325}") }
            if contains(.shift)   { parts.append("\u{21E7}") }
            if contains(.command) { parts.append("\u{2318}") }
            return parts.joined()
        }

        var hasNonShiftModifier: Bool {
            !intersection([.command, .option, .control]).isEmpty
        }
    }

    init(keyCode: UInt16, modifiers: ModifierSet) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(from event: NSEvent) {
        self.keyCode = event.keyCode
        self.modifiers = ModifierSet(from: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
    }

    var displayString: String {
        "\(modifiers.displayString)\(KeyCodeMapping.displayString(for: keyCode))"
    }

    /// Combos that macOS handles at the WindowServer level — RegisterEventHotKey cannot override these.
    static let hardReserved: Set<KeyCombination> = [
        KeyCombination(keyCode: UInt16(kVK_Tab), modifiers: .command),       // App switcher
        KeyCombination(keyCode: UInt16(kVK_Tab), modifiers: [.command, .shift]), // Reverse app switcher
    ]

    /// Combos commonly used by the system or popular apps. Can be overridden but worth warning about.
    static let knownConflicts: [KeyCombination: String] = [
        KeyCombination(keyCode: UInt16(kVK_Space), modifiers: .command): "Spotlight",
        KeyCombination(keyCode: UInt16(kVK_Space), modifiers: [.command, .option]): "Finder search / Raycast / Alfred",
        KeyCombination(keyCode: UInt16(kVK_ANSI_Q), modifiers: .command): "Quit frontmost app",
        KeyCombination(keyCode: UInt16(kVK_ANSI_H), modifiers: .command): "Hide frontmost app",
        KeyCombination(keyCode: UInt16(kVK_ANSI_M), modifiers: .command): "Minimize window",
        KeyCombination(keyCode: UInt16(kVK_ANSI_W), modifiers: .command): "Close window",
        KeyCombination(keyCode: UInt16(kVK_ANSI_C), modifiers: .command): "Copy",
        KeyCombination(keyCode: UInt16(kVK_ANSI_V), modifiers: .command): "Paste",
        KeyCombination(keyCode: UInt16(kVK_ANSI_X), modifiers: .command): "Cut",
        KeyCombination(keyCode: UInt16(kVK_ANSI_Z), modifiers: .command): "Undo",
        KeyCombination(keyCode: UInt16(kVK_ANSI_A), modifiers: .command): "Select All",
    ]

    var isHardReserved: Bool {
        Self.hardReserved.contains(self)
    }

    var knownConflictDescription: String? {
        Self.knownConflicts[self]
    }
}
