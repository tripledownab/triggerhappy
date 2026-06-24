import AppKit
import Carbon.HIToolbox

@Observable
final class HotkeyManager {
    private var hotKeyRefs: [UUID: EventHotKeyRef] = [:]
    private var idToBinding: [UInt32: HotkeyBinding] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var handlerRef: EventHandlerRef?

    private let bindingStore: BindingStore
    private(set) var isActive: Bool = false

    init(bindingStore: BindingStore) {
        self.bindingStore = bindingStore
        bindingStore.onBindingsChanged = { [weak self] in
            self?.reregisterAll()
        }
    }

    func start() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard status == noErr else {
            isActive = false
            return
        }

        isActive = true
        reregisterAll()
    }

    func stop() {
        unregisterAll()
        if let handler = handlerRef {
            RemoveEventHandler(handler)
            handlerRef = nil
        }
        isActive = false
    }

    func reregisterAll() {
        unregisterAll()
        guard handlerRef != nil else { return }

        for binding in bindingStore.bindings where binding.isEnabled {
            register(binding)
        }
    }

    private func register(_ binding: HotkeyBinding) {
        let id = nextHotKeyID
        nextHotKeyID += 1

        var hotKeyID = EventHotKeyID(signature: OSType(0x5448_4B59), id: id) // "THKY"
        let modifiers = carbonModifiers(from: binding.keyCombination.modifiers)

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(binding.keyCombination.keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[binding.id] = ref
            idToBinding[id] = binding
        }
    }

    private func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        idToBinding.removeAll()
        nextHotKeyID = 1
    }

    fileprivate func handleHotKey(event: EventRef) {
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

        guard status == noErr, let binding = idToBinding[hotKeyID.id] else { return }

        DispatchQueue.main.async {
            self.executeAction(binding.action)
        }
    }

    private func executeAction(_ action: BindingAction) {
        switch action {
        case .launchApp(let appURL, _, _):
            AppLauncher.launch(appURL: appURL)
        }
    }

    private func carbonModifiers(from modifiers: KeyCombination.ModifierSet) -> UInt32 {
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    deinit {
        stop()
    }
}

private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKey(event: event)
    return noErr
}
