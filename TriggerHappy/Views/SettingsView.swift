import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appDelegate: AppDelegate

    @State private var panelOpacity: Double
    @State private var launcherTheme: LauncherTheme
    @State private var bbsScheme: BBSScheme
    @State private var bbsWordmark: BBSWordmark
    @State private var launcherLayout: LauncherLayout
    @State private var searchCombo: KeyCombination?
    @State private var cheatSheetCombo: KeyCombination?
    @State private var clipboardCombo: KeyCombination?
    @State private var isEditingSearch = false
    @State private var isEditingCheatSheet = false
    @State private var isEditingClipboard = false
    @State private var launchAtLogin = false

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        _panelOpacity = State(initialValue: appDelegate.panelOpacity)
        _launcherTheme = State(initialValue: appDelegate.launcherTheme)
        _bbsScheme = State(initialValue: appDelegate.bbsScheme)
        _bbsWordmark = State(initialValue: appDelegate.bbsWordmark)
        _launcherLayout = State(initialValue: appDelegate.launcherLayout)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Appearance
            sectionHeader("Appearance")

            VStack(spacing: 12) {
                HStack {
                    Text("Overlay Theme")
                        .font(.system(size: 13))

                    Spacer()

                    Picker("", selection: $launcherTheme) {
                        ForEach(LauncherTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 150)
                    .onChange(of: launcherTheme) { _, newValue in
                        appDelegate.launcherTheme = newValue
                    }
                }

                if launcherTheme == .bbs {
                    HStack {
                        Text("Color Scheme")
                            .font(.system(size: 13))

                        Spacer()

                        Picker("", selection: $bbsScheme) {
                            ForEach(BBSScheme.allCases) { scheme in
                                Text(scheme.label).tag(scheme)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: bbsScheme) { _, newValue in
                            appDelegate.bbsScheme = newValue
                        }
                    }

                    HStack {
                        Text("BBS Banner")
                            .font(.system(size: 13))

                        Spacer()

                        Picker("", selection: $bbsWordmark) {
                            ForEach(BBSWordmark.allCases) { mark in
                                Text(mark.label).tag(mark)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: bbsWordmark) { _, newValue in
                            appDelegate.bbsWordmark = newValue
                        }
                    }

                    HStack {
                        Text("Launcher Layout")
                            .font(.system(size: 13))

                        Spacer()

                        Picker("", selection: $launcherLayout) {
                            ForEach(LauncherLayout.allCases) { layout in
                                Text(layout.label).tag(layout)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: launcherLayout) { _, newValue in
                            appDelegate.launcherLayout = newValue
                        }
                    }
                }

                HStack {
                    Text("Panel Transparency")
                        .font(.system(size: 13))

                    Spacer()

                    Text(panelOpacity < 0.05 ? "Transparent" : panelOpacity > 0.95 ? "Frosted" : "\(Int(panelOpacity * 100))%")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .trailing)
                }

                Slider(value: $panelOpacity, in: 0...1, step: 0.05)
                    .onChange(of: panelOpacity) { _, newValue in
                        appDelegate.panelOpacity = newValue
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 16)

            // Hotkeys
            sectionHeader("System Hotkeys")

            VStack(spacing: 6) {
                hotkeyRow(
                    icon: "magnifyingglass",
                    label: "App Launcher",
                    combo: $searchCombo,
                    isEditing: $isEditingSearch,
                    onSave: { appDelegate.searchKeyCombination = $0 }
                )

                hotkeyRow(
                    icon: "list.bullet.rectangle",
                    label: "Cheat Sheet",
                    combo: $cheatSheetCombo,
                    isEditing: $isEditingCheatSheet,
                    onSave: { appDelegate.cheatSheetKeyCombination = $0 }
                )

                hotkeyRow(
                    icon: "clipboard",
                    label: "Clipboard History",
                    combo: $clipboardCombo,
                    isEditing: $isEditingClipboard,
                    onSave: { appDelegate.clipboardKeyCombination = $0 }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 16)

            // General
            sectionHeader("General")

            HStack {
                Text("Launch at Login")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Spacer()
        }
        .frame(width: 380, height: 590)
        .onAppear {
            searchCombo = appDelegate.searchKeyCombination
            cheatSheetCombo = appDelegate.cheatSheetKeyCombination
            clipboardCombo = appDelegate.clipboardKeyCombination
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func hotkeyRow(
        icon: String,
        label: String,
        combo: Binding<KeyCombination?>,
        isEditing: Binding<Bool>,
        onSave: @escaping (KeyCombination) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13))

            Spacer()

            if isEditing.wrappedValue {
                KeyRecorderView(
                    keyCombination: combo,
                    existingBindings: appDelegate.bindingStore.bindings
                )
                .frame(width: 150)
                .onChange(of: combo.wrappedValue) { _, newCombo in
                    if let c = newCombo {
                        onSave(c)
                        isEditing.wrappedValue = false
                    }
                }
            } else if let c = combo.wrappedValue {
                Button {
                    isEditing.wrappedValue = true
                } label: {
                    ShortcutPill(combo: c)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
    }
}
