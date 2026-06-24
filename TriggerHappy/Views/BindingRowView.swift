import SwiftUI

struct BindingRowView: View {
    let binding: HotkeyBinding
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            if let url = binding.action.appURL {
                Image(nsImage: AppLauncher.appIcon(at: url))
                    .resizable()
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            }

            // Name + shortcut pill
            VStack(alignment: .leading, spacing: 3) {
                Text(binding.action.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                ShortcutPill(combo: binding.keyCombination)
            }

            Spacer(minLength: 4)

            // Controls
            HStack(spacing: 8) {
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(.quaternary)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                Toggle("", isOn: Binding(
                    get: { binding.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .opacity(binding.isEnabled ? 1.0 : 0.5)
    }
}

struct ShortcutPill: View {
    let combo: KeyCombination

    var body: some View {
        HStack(spacing: 2) {
            ForEach(modifierSymbols, id: \.self) { symbol in
                KeyCap(label: symbol)
            }
            KeyCap(label: KeyCodeMapping.displayString(for: combo.keyCode))
        }
    }

    private var modifierSymbols: [String] {
        var symbols: [String] = []
        if combo.modifiers.contains(.control) { symbols.append("\u{2303}") }
        if combo.modifiers.contains(.option)  { symbols.append("\u{2325}") }
        if combo.modifiers.contains(.shift)   { symbols.append("\u{21E7}") }
        if combo.modifiers.contains(.command) { symbols.append("\u{2318}") }
        return symbols
    }
}

struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}
