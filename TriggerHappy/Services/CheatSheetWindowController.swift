import AppKit
import SwiftUI

final class CheatSheetWindowController {
    private var window: NSPanel?
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func toggle() {
        if let window, window.isVisible {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        createWindow()

        guard let window else { return }

        if let hostingView = window.contentView {
            let fittingSize = hostingView.fittingSize
            window.setContentSize(fittingSize)
        }

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        if let screen {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY + screenFrame.height * 0.1
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }

    private func createWindow() {
        guard let appDelegate else { return }

        let dismiss: () -> Void = { [weak self] in self?.dismiss() }

        let contentView: AnyView
        switch appDelegate.launcherTheme {
        case .modern:
            contentView = AnyView(CheatSheetPanel(
                bindingStore: appDelegate.bindingStore,
                panelOpacity: appDelegate.panelOpacity,
                onDismiss: dismiss
            ))
        case .bbs:
            contentView = AnyView(BBSCheatSheetPanel(
                bindingStore: appDelegate.bindingStore,
                panelOpacity: appDelegate.panelOpacity,
                onDismiss: dismiss
            ))
        }

        let hostingView = NSHostingView(rootView: contentView)
        let fittingSize = hostingView.fittingSize

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        window = panel
    }
}
