import Foundation

struct HotkeyBinding: Codable, Identifiable, Equatable {
    let id: UUID
    var keyCombination: KeyCombination
    var action: BindingAction
    var isEnabled: Bool

    init(id: UUID = UUID(), keyCombination: KeyCombination, action: BindingAction, isEnabled: Bool = true) {
        self.id = id
        self.keyCombination = keyCombination
        self.action = action
        self.isEnabled = isEnabled
    }
}

enum BindingAction: Codable, Equatable {
    case launchApp(appURL: URL, appName: String, bundleIdentifier: String?)

    var displayName: String {
        switch self {
        case .launchApp(_, let appName, _):
            return appName
        }
    }

    var appURL: URL? {
        switch self {
        case .launchApp(let url, _, _):
            return url
        }
    }
}
