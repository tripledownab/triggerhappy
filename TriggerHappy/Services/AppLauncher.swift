import AppKit

enum AppLauncher {
    static func launch(appURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Failed to launch application"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    static func appName(at url: URL) -> String {
        FileManager.default.displayName(atPath: url.path)
    }

    static func appIcon(at url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func bundleIdentifier(at url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }
}
