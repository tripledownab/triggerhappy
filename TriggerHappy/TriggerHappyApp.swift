import SwiftUI
import Carbon.HIToolbox

@main
struct TriggerHappyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let bindingStore = BindingStore()
    let appIndexer = AppIndexer()
    let clipboardStore = ClipboardStore()
    lazy var hotkeyManager = HotkeyManager(bindingStore: bindingStore)
    lazy var searchWindowController = SearchWindowController(appDelegate: self)
    lazy var cheatSheetWindowController = CheatSheetWindowController(appDelegate: self)
    lazy var clipboardWindowController = ClipboardWindowController(appDelegate: self)
    lazy var settingsWindowController = SettingsWindowController(appDelegate: self)

    // System hotkeys (stored separately from user bindings)
    private var systemHandlerRef: EventHandlerRef?
    private var searchHotKeyRef: EventHotKeyRef?
    private var cheatSheetHotKeyRef: EventHotKeyRef?
    private var clipboardHotKeyRef: EventHotKeyRef?

    private let searchHotKeyID: UInt32 = 9999
    private let cheatSheetHotKeyID: UInt32 = 9998
    private let clipboardHotKeyID: UInt32 = 9997

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var clickMonitor: Any?

    // MARK: - Appearance

    var panelOpacity: Double {
        get { UserDefaults.standard.object(forKey: "com.triggerhappy.panelOpacity") as? Double ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: "com.triggerhappy.panelOpacity") }
    }

    var launcherTheme: LauncherTheme {
        get { LauncherTheme(rawValue: UserDefaults.standard.string(forKey: "com.triggerhappy.launcherTheme") ?? "") ?? .modern }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "com.triggerhappy.launcherTheme") }
    }

    var bbsWordmark: BBSWordmark {
        get { BBSWordmark(rawValue: UserDefaults.standard.string(forKey: "com.triggerhappy.bbsWordmark") ?? "") ?? .theme }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "com.triggerhappy.bbsWordmark") }
    }

    var launcherLayout: LauncherLayout {
        get { LauncherLayout(rawValue: UserDefaults.standard.string(forKey: "com.triggerhappy.launcherLayout") ?? "") ?? .center }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "com.triggerhappy.launcherLayout") }
    }

    var bbsScheme: BBSScheme {
        get { BBSScheme(rawValue: UserDefaults.standard.string(forKey: "com.triggerhappy.bbsScheme") ?? "") ?? .classic }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "com.triggerhappy.bbsScheme") }
    }

    // MARK: - Hotkey Preferences

    var searchKeyCombination: KeyCombination {
        get { loadCombo(key: "com.triggerhappy.searchHotkey") ?? KeyCombination(keyCode: UInt16(kVK_Space), modifiers: .option) }
        set { saveCombo(newValue, key: "com.triggerhappy.searchHotkey"); registerSystemHotKeys() }
    }

    var cheatSheetKeyCombination: KeyCombination {
        get { loadCombo(key: "com.triggerhappy.cheatSheetHotkey") ?? KeyCombination(keyCode: UInt16(kVK_ANSI_Slash), modifiers: .option) }
        set { saveCombo(newValue, key: "com.triggerhappy.cheatSheetHotkey"); registerSystemHotKeys() }
    }

    var clipboardKeyCombination: KeyCombination {
        get { loadCombo(key: "com.triggerhappy.clipboardHotkey") ?? KeyCombination(keyCode: UInt16(kVK_ANSI_V), modifiers: .option) }
        set { saveCombo(newValue, key: "com.triggerhappy.clipboardHotkey"); registerSystemHotKeys() }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupPopover()
        setupStatusItem()
        hotkeyManager.start()
        installSystemHotKeyHandler()
        registerSystemHotKeys()
    }

    // MARK: - System Hotkey Handler (shared for search, cheat sheet, clipboard)

    private func installSystemHotKeyHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            systemHotKeyCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &systemHandlerRef
        )
    }

    func registerSystemHotKeys() {
        // Unregister all
        if let ref = searchHotKeyRef { UnregisterEventHotKey(ref); searchHotKeyRef = nil }
        if let ref = cheatSheetHotKeyRef { UnregisterEventHotKey(ref); cheatSheetHotKeyRef = nil }
        if let ref = clipboardHotKeyRef { UnregisterEventHotKey(ref); clipboardHotKeyRef = nil }

        // Register each
        searchHotKeyRef = registerOneHotKey(combo: searchKeyCombination, id: searchHotKeyID)
        cheatSheetHotKeyRef = registerOneHotKey(combo: cheatSheetKeyCombination, id: cheatSheetHotKeyID)
        clipboardHotKeyRef = registerOneHotKey(combo: clipboardKeyCombination, id: clipboardHotKeyID)
    }

    private func registerOneHotKey(combo: KeyCombination, id: UInt32) -> EventHotKeyRef? {
        var hotKeyID = EventHotKeyID(signature: OSType(0x5448_5359), id: id) // "THSY"
        var ref: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(combo.keyCode),
            carbonModifiers(from: combo.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        return ref
    }

    fileprivate func handleSystemHotKey(id: UInt32) {
        DispatchQueue.main.async {
            switch id {
            case self.searchHotKeyID:
                self.searchWindowController.toggle()
            case self.cheatSheetHotKeyID:
                self.cheatSheetWindowController.toggle()
            case self.clipboardHotKeyID:
                self.clipboardWindowController.toggle()
            default:
                break
            }
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        let contentView = MenuBarPanel(
            bindingStore: bindingStore,
            hotkeyManager: hotkeyManager,
            appDelegate: self
        )

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: "Trigger Happy")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return }
            if let window = event.window, window is NSOpenPanel { return }
            self.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Helpers

    private func carbonModifiers(from modifiers: KeyCombination.ModifierSet) -> UInt32 {
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    private func loadCombo(key: String) -> KeyCombination? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KeyCombination.self, from: data)
    }

    private func saveCombo(_ combo: KeyCombination, key: String) {
        if let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Carbon Callback

private func systemHotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    // Only handle our system hotkey IDs; pass others through to HotkeyManager
    let knownIDs: Set<UInt32> = [9999, 9998, 9997]
    guard knownIDs.contains(hotKeyID.id) else {
        return CallNextEventHandler(nextHandler, event)
    }

    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    delegate.handleSystemHotKey(id: hotKeyID.id)
    return noErr
}
