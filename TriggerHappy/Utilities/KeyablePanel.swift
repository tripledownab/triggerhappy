import AppKit

/// NSPanel subclass that can become key even when borderless.
/// Used by all floating panel controllers (search, cheat sheet, clipboard).
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
