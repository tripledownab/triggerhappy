import SwiftUI

struct AppSearchPicker: View {
    let appIndexer: AppIndexer
    @Binding var selectedAppURL: URL?
    @Binding var selectedAppName: String
    @Binding var selectedBundleID: String?

    @State private var query = ""
    @State private var results: [IndexedApp] = []
    @State private var isSearching = false
    @State private var selectedIndex = 0
    @State private var eventMonitor: Any?
    @FocusState private var isFocused: Bool

    private var showResults: Bool {
        isSearching && !results.isEmpty
    }

    var body: some View {
        VStack(spacing: 4) {
            if let url = selectedAppURL, !isSearching {
                // Selected app display
                HStack(spacing: 8) {
                    Image(nsImage: AppLauncher.appIcon(at: url))
                        .resizable()
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                    Text(selectedAppName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        startSearching()
                    } label: {
                        Text("Change")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                )
            } else {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("Type to search apps...", text: $query)
                        .font(.system(size: 13))
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit { selectCurrent() }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )

                // Results list
                if showResults {
                    VStack(spacing: 1) {
                        ForEach(Array(results.prefix(4).enumerated()), id: \.element.id) { index, app in
                            HStack(spacing: 8) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(app.name)
                                    .font(.system(size: 12, weight: index == selectedIndex ? .semibold : .regular))
                                    .lineLimit(1)
                                Spacer()
                                if index == selectedIndex {
                                    KeyCap(label: "\u{21A9}")
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(index == selectedIndex
                                          ? Color.accentColor.opacity(0.12)
                                          : .clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selectApp(app) }
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .onChange(of: query) { _, newQuery in
            results = appIndexer.search(query: newQuery)
            selectedIndex = 0
        }
        .onAppear {
            if selectedAppURL == nil {
                startSearching()
            }
        }
        .onDisappear {
            removeMonitor()
        }
    }

    private func startSearching() {
        isSearching = true
        query = ""
        results = appIndexer.search(query: "")
        selectedIndex = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }

        installMonitor()
    }

    private func installMonitor() {
        removeMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 125: // down
                let count = min(results.count, 4)
                if selectedIndex < count - 1 { selectedIndex += 1 }
                return nil
            case 126: // up
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 36: // return
                return event // let onSubmit handle
            case 53: // escape
                cancelSearching()
                return nil
            default:
                return event
            }
        }
    }

    private func cancelSearching() {
        isSearching = selectedAppURL == nil // stay in search mode if nothing selected
        removeMonitor()
    }

    private func selectCurrent() {
        let visible = Array(results.prefix(4))
        guard selectedIndex < visible.count else { return }
        selectApp(visible[selectedIndex])
    }

    private func selectApp(_ app: IndexedApp) {
        selectedAppURL = app.url
        selectedAppName = app.name
        selectedBundleID = app.bundleIdentifier
        isSearching = false
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
