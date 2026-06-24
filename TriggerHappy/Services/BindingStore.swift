import Foundation

@Observable
final class BindingStore {
    private(set) var bindings: [HotkeyBinding] = []
    private let userDefaultsKey = "com.triggerhappy.bindings"

    var onBindingsChanged: (() -> Void)?

    init() {
        load()
    }

    func add(_ binding: HotkeyBinding) {
        bindings.append(binding)
        save()
    }

    func remove(id: UUID) {
        bindings.removeAll { $0.id == id }
        save()
    }

    func update(_ binding: HotkeyBinding) {
        guard let index = bindings.firstIndex(where: { $0.id == binding.id }) else { return }
        bindings[index] = binding
        save()
    }

    func toggleEnabled(id: UUID) {
        guard let index = bindings.firstIndex(where: { $0.id == id }) else { return }
        bindings[index].isEnabled.toggle()
        save()
    }

    func binding(for combo: KeyCombination) -> HotkeyBinding? {
        bindings.first { $0.keyCombination == combo && $0.isEnabled }
    }

    func hasConflict(with combo: KeyCombination, excluding bindingID: UUID? = nil) -> Bool {
        bindings.contains { $0.keyCombination == combo && $0.id != bindingID }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        onBindingsChanged?()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data)
        else { return }
        bindings = decoded
    }
}
