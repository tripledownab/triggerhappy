import SwiftUI

struct PermissionPromptView: View {
    let permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Permission Required")
                .font(.headline)

            Text("Trigger Happy needs **Input Monitoring** access to listen for global keyboard shortcuts.\n\nIf you already enabled Accessibility, you may also need to enable Input Monitoring separately.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            VStack(spacing: 8) {
                Button("Open Input Monitoring") {
                    PermissionManager.openInputMonitoringSettings()
                    permissionManager.startPolling()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Accessibility") {
                    permissionManager.requestPermission()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Check Again") {
                    _ = permissionManager.checkPermission()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .controlSize(.small)
            }

            Text("Add Trigger Happy in System Settings, then click \"Check Again\".")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }
}
