import SwiftUI
import AppKit
import Carbon.HIToolbox

struct KeyRecorderView: View {
    @Binding var keyCombination: KeyCombination?
    @State private var isRecording = false
    @State private var validationMessage: String?
    @State private var isWarning = false
    @State private var eventMonitor: Any?

    var existingBindings: [HotkeyBinding] = []
    var editingBindingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .modifier(PulseEffect())

                    Text("Press shortcut...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else if let combo = keyCombination {
                    ShortcutPill(combo: combo)
                } else {
                    Image(systemName: "record.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Text("Click to record")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if keyCombination != nil && !isRecording {
                    Button {
                        keyCombination = nil
                        validationMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRecording
                          ? Color.accentColor.opacity(0.06)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecording
                            ? Color.accentColor.opacity(0.5)
                            : Color(nsColor: .separatorColor).opacity(0.5),
                            lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isRecording {
                    startRecording()
                }
            }

            if let message = validationMessage {
                HStack(spacing: 4) {
                    Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(message)
                        .font(.system(size: 11))
                }
                .foregroundStyle(isWarning ? .orange : .red)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: validationMessage != nil)
    }

    private func startRecording() {
        validationMessage = nil
        isWarning = false
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }

            let modSet = KeyCombination.ModifierSet(from: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
            let combo = KeyCombination(keyCode: event.keyCode, modifiers: modSet)

            if !modSet.hasNonShiftModifier {
                self.isWarning = false
                self.validationMessage = "Must include \u{2318}, \u{2325}, or \u{2303}"
                return nil
            }

            if combo.isHardReserved {
                self.isWarning = false
                self.validationMessage = "\(combo.displayString) cannot be overridden"
                return nil
            }

            let hasConflict = self.existingBindings.contains {
                $0.keyCombination == combo && $0.id != self.editingBindingID
            }
            if hasConflict {
                self.isWarning = false
                self.validationMessage = "\(combo.displayString) is already assigned"
                return nil
            }

            self.keyCombination = combo
            if let conflict = combo.knownConflictDescription {
                self.isWarning = true
                self.validationMessage = "May conflict with: \(conflict)"
            } else {
                self.isWarning = false
                self.validationMessage = nil
            }
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
