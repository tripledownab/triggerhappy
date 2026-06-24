import SwiftUI

struct MenuBarPanel: View {
    let bindingStore: BindingStore
    let hotkeyManager: HotkeyManager
    let appDelegate: AppDelegate

    @State private var editingBinding: HotkeyBinding?
    @State private var isAdding = false

    private var isShowingEditor: Bool { isAdding || editingBinding != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if isShowingEditor {
                EditBindingView(
                    bindingStore: bindingStore,
                    appIndexer: appDelegate.appIndexer,
                    existing: editingBinding
                ) { binding in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if editingBinding != nil {
                            bindingStore.update(binding)
                        } else {
                            bindingStore.add(binding)
                        }
                        editingBinding = nil
                        isAdding = false
                    }
                } onCancel: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editingBinding = nil
                        isAdding = false
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if bindingStore.bindings.isEmpty {
                emptyState
                    .transition(.opacity)
            } else {
                bindingList
                    .transition(.opacity)
            }

            footer
        }
        .frame(width: 360)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.primary)

            Text("Trigger Happy")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Button {
                appDelegate.settingsWindowController.show()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(hotkeyManager.isActive ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(hotkeyManager.isActive ? "Active" : "Inactive")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.quaternary))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 56, height: 56)
                Image(systemName: "keyboard")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("No hotkeys yet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Add a shortcut to launch apps instantly")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(minHeight: 140)
    }

    // MARK: - Binding List

    private var bindingList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(bindingStore.bindings) { binding in
                    BindingRowView(
                        binding: binding,
                        onToggle: { withAnimation(.easeInOut(duration: 0.15)) { bindingStore.toggleEnabled(id: binding.id) } },
                        onEdit: { withAnimation(.easeInOut(duration: 0.2)) { editingBinding = binding } },
                        onDelete: { withAnimation(.easeInOut(duration: 0.2)) { bindingStore.remove(id: binding.id) } }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(minHeight: 80, maxHeight: 280)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if !isShowingEditor {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isAdding = true }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Hotkey")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
