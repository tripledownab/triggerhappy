import SwiftUI
import Carbon.HIToolbox

struct CheatSheetPanel: View {
    let bindingStore: BindingStore
    let panelOpacity: Double
    let onDismiss: () -> Void

    @State private var eventMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("Keyboard Shortcuts")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("ESC to close")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 12)

            if bindingStore.bindings.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No hotkeys configured")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 80)
            } else {
                VStack(spacing: 1) {
                    ForEach(bindingStore.bindings) { binding in
                        HStack(spacing: 10) {
                            if let url = binding.action.appURL {
                                Image(nsImage: AppLauncher.appIcon(at: url))
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }

                            Text(binding.action.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            ShortcutPill(combo: binding.keyCombination)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .opacity(binding.isEnabled ? 1.0 : 0.4)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial.opacity(panelOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                onDismiss()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - BBS Cheat Sheet overlay
//
// The PCBoard-flavored reference card. A static, read-only list — no search, no
// selection — so it just renders every binding as a monospaced menu line with a
// dotted leader and the key combo right-aligned. Disabled bindings dim out and
// trade their filled ▪ bullet for a hollow ▫.

struct BBSCheatSheetPanel: View {
    let bindingStore: BindingStore
    let panelOpacity: Double
    let onDismiss: () -> Void

    @State private var eventMonitor: Any?

    private let panelWidth: CGFloat = 460
    private let hInset: CGFloat = 18
    private var contentWidth: CGFloat { panelWidth - hInset * 2 }
    private var cols: Int { max(30, Int(contentWidth / BBS.charWidth)) }

    var body: some View {
        let bindings = bindingStore.bindings
        let enabled = bindings.filter { $0.isEnabled }.count

        VStack(alignment: .leading, spacing: 8) {
            BBSBanner(subtitle: "cheat sheet")

            BBS.divider("hotkeys", cols: cols).font(BBS.font())

            if bindings.isEmpty {
                Text("  " + BBS.flavor("no hotkeys configured"))
                    .font(BBS.font())
                    .foregroundColor(BBS.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(bindings) { binding in
                        BBSCheatRow(
                            name: binding.action.displayName,
                            combo: binding.keyCombination.displayString,
                            isEnabled: binding.isEnabled,
                            cols: cols
                        )
                    }
                }
            }

            footer(total: bindings.count, enabled: enabled)
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.horizontal, hInset)
        .padding(.vertical, 14)
        .modifier(BBSFrame(opacity: panelOpacity))
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    private func footer(total: Int, enabled: Int) -> some View {
        let key: (String) -> Text = { Text($0).foregroundColor(BBS.amber) }
        let dim: (String) -> Text = { Text($0).foregroundColor(BBS.gray) }
        let hint = key("[esc]") + dim(" " + BBS.leet("hangup"))
        var tally = "\(total) " + BBS.leet("keys")
        if enabled < total { tally += " \u{00B7} \(total - enabled) " + BBS.leet("off") }
        return HStack(spacing: 0) {
            hint
            Spacer(minLength: 8)
            Text(tally).foregroundColor(BBS.cyan)
        }
        .font(BBS.font())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                onDismiss()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

/// One cheat-sheet line built to ~`cols` cells:
///   `▪ Firefox ················· ⌃⇧F`
/// All combos right-align to the same column because every row targets the same
/// width with the combo at the tail. App names are user content, so un-l33t'd.
struct BBSCheatRow: View {
    let name: String
    let combo: String
    let isEnabled: Bool
    let cols: Int

    var body: some View {
        // Leave a 2-cell right margin so a slightly-wide modifier glyph can't
        // overflow the frame and get truncation-ellipsised.
        let target = max(20, cols - 2)
        let marker = isEnabled ? "\u{25AA} " : "\u{25AB} "   // ▪ filled / ▫ hollow
        let nameMax = max(1, target - 6 - combo.count)
        let shownName = BBS.trunc(name, nameMax)
        let dotCount = max(1, target - 4 - shownName.count - combo.count)
        let dots = String(repeating: "\u{00B7}", count: dotCount)

        let line = Text(marker).foregroundColor(BBS.cyan)
            + Text(shownName).foregroundColor(BBS.white)
            + Text(" " + dots + " ").foregroundColor(BBS.gray)
            + Text(combo).foregroundColor(BBS.amber).bold()

        return line
            .font(BBS.font())
            .lineLimit(1)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isEnabled ? 1.0 : 0.45)
    }
}
