import AppKit
import ApplicationServices

@Observable
final class PermissionManager {
    var hasPermission: Bool = false
    private var pollTimer: Timer?

    init() {
        hasPermission = canCreateEventTap()
    }

    /// The real check: can we actually create a CGEventTap?
    /// This tests Input Monitoring permission, which is what we need.
    func canCreateEventTap() -> Bool {
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        if let tap {
            // Clean up the test tap immediately
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
            return true
        }
        return false
    }

    func checkPermission() -> Bool {
        hasPermission = canCreateEventTap()
        return hasPermission
    }

    func requestPermission() {
        // This prompts for Accessibility (which often also covers Input Monitoring)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.canCreateEventTap() {
                self.hasPermission = true
                timer.invalidate()
                self.pollTimer = nil
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
