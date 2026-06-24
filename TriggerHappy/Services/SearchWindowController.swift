import AppKit
import SwiftUI

final class SearchWindowController {
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

    private var useQuake: Bool {
        guard let appDelegate else { return false }
        return appDelegate.launcherTheme == .bbs && appDelegate.launcherLayout == .quake
    }

    func show() {
        // Always recreate so theme / layout / opacity are current.
        createWindow()
        guard let window else { return }

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let vf = screen.visibleFrame

        if useQuake {
            // Full-width, one-line console pinned under the top edge. The drop-down
            // is animated inside the SwiftUI view (QuakeSearchPanel slides its
            // content down and the window clips the overflow), so the window itself
            // just snaps to its resting frame.
            let stripHeight: CGFloat = 46
            let resting = NSRect(x: vf.minX, y: vf.maxY - stripHeight, width: vf.width, height: stripHeight)
            window.setFrame(resting, display: true)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        } else {
            if let hostingView = window.contentView {
                window.setContentSize(hostingView.fittingSize)
            }
            let size = window.frame.size
            let x = vf.midX - size.width / 2
            let y = vf.midY + vf.height * 0.1
            window.setFrameOrigin(NSPoint(x: x, y: y))
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            window.makeFirstResponder(window.contentView)
        }
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }

    private func createWindow() {
        guard let appDelegate else { return }

        let dismiss: () -> Void = { [weak self] in self?.dismiss() }

        let contentView: AnyView
        if useQuake {
            contentView = AnyView(QuakeSearchPanel(
                appIndexer: appDelegate.appIndexer,
                panelOpacity: appDelegate.panelOpacity,
                onDismiss: dismiss
            ))
        } else {
            switch appDelegate.launcherTheme {
            case .modern:
                contentView = AnyView(SearchPanel(
                    appIndexer: appDelegate.appIndexer,
                    panelOpacity: appDelegate.panelOpacity,
                    onDismiss: dismiss
                ))
            case .bbs:
                contentView = AnyView(BBSSearchPanel(
                    appIndexer: appDelegate.appIndexer,
                    panelOpacity: appDelegate.panelOpacity,
                    onDismiss: dismiss
                ))
            }
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
        panel.isMovableByWindowBackground = !useQuake
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        window = panel
    }
}
