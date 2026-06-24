import AppKit
import SwiftUI

final class SettingsWindowController: NSObject {
    private var window: NSWindow?
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func show() {
        if window == nil {
            createWindow()
        }
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    private func createWindow() {
        guard let appDelegate else { return }

        let settingsView = SettingsView(appDelegate: appDelegate)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 590),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: settingsView)
        window.title = "Trigger Happy Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self

        self.window = window
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
