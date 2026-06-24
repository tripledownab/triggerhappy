import SwiftUI

struct EditBindingView: View {
    let bindingStore: BindingStore
    let appIndexer: AppIndexer
    let existing: HotkeyBinding?
    let onSave: (HotkeyBinding) -> Void
    let onCancel: () -> Void

    @State private var keyCombination: KeyCombination?
    @State private var appURL: URL?
    @State private var appName: String = ""
    @State private var bundleID: String?

    private var isEditing: Bool { existing != nil }
    private var isValid: Bool { keyCombination != nil && appURL != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isEditing ? "Edit Hotkey" : "New Hotkey")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .hidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 12)

            // Form
            VStack(spacing: 18) {
                // App section (first — pick app, then shortcut)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Application", systemImage: "app")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    AppSearchPicker(
                        appIndexer: appIndexer,
                        selectedAppURL: $appURL,
                        selectedAppName: $appName,
                        selectedBundleID: $bundleID
                    )
                }

                // Shortcut section
                VStack(alignment: .leading, spacing: 6) {
                    Label("Shortcut", systemImage: "command")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    KeyRecorderView(
                        keyCombination: $keyCombination,
                        existingBindings: bindingStore.bindings,
                        editingBindingID: existing?.id
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Spacer(minLength: 0)

            // Save button
            Button {
                guard let combo = keyCombination, let url = appURL else { return }
                let binding = HotkeyBinding(
                    id: existing?.id ?? UUID(),
                    keyCombination: combo,
                    action: .launchApp(appURL: url, appName: appName, bundleIdentifier: bundleID),
                    isEnabled: existing?.isEnabled ?? true
                )
                onSave(binding)
            } label: {
                Text(isEditing ? "Save Changes" : "Add Hotkey")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isValid)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .onAppear {
            if let existing {
                keyCombination = existing.keyCombination
                if case .launchApp(let url, let name, let bid) = existing.action {
                    appURL = url
                    appName = name
                    bundleID = bid
                }
            }
        }
    }
}
