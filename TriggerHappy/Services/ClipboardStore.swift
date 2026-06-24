import AppKit

@Observable
final class ClipboardStore {
    private(set) var entries: [ClipboardEntry] = []
    private(set) var savedClips: [ClipboardEntry] = []
    private var pollTimer: Timer?
    private var lastChangeCount: Int
    private let maxEntries = 50
    private let maxContentLength = 10_000
    private let userDefaultsKey = "com.triggerhappy.clipboardHistory"
    private let savedClipsKey = "com.triggerhappy.savedClips"

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        load()
        loadSaved()
        startMonitoring()
    }

    func startMonitoring() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func search(query: String) -> [ClipboardEntry] {
        if query.isEmpty { return entries }
        let q = query.lowercased()
        return entries.filter { $0.content.lowercased().contains(q) }
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    func isSaved(_ entry: ClipboardEntry) -> Bool {
        savedClips.contains { $0.content == entry.content }
    }

    func toggleSaved(_ entry: ClipboardEntry) {
        if let index = savedClips.firstIndex(where: { $0.content == entry.content }) {
            savedClips.remove(at: index)
        } else {
            savedClips.insert(entry, at: 0)
        }
        saveSavedClips()
    }

    func removeSaved(id: UUID) {
        savedClips.removeAll { $0.id == id }
        saveSavedClips()
    }

    func searchSaved(query: String) -> [ClipboardEntry] {
        if query.isEmpty { return savedClips }
        let q = query.lowercased()
        return savedClips.filter { $0.content.lowercased().contains(q) }
    }

    func copyToClipboard(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.content, forType: .string)
        // Update change count so we don't re-add this as a new entry
        lastChangeCount = pasteboard.changeCount
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Skip password manager entries
        if let types = pasteboard.types,
           types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) {
            return
        }

        guard let content = pasteboard.string(forType: .string),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Deduplicate: skip if identical to most recent
        if entries.first?.content == content {
            return
        }

        // Cap content length
        let trimmedContent = content.count > maxContentLength
            ? String(content.prefix(maxContentLength))
            : content

        // Get source app info
        let frontApp = NSWorkspace.shared.frontmostApplication
        let entry = ClipboardEntry(
            id: UUID(),
            content: trimmedContent,
            timestamp: Date(),
            sourceAppName: frontApp?.localizedName,
            sourceAppBundleID: frontApp?.bundleIdentifier
        )

        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func saveSavedClips() {
        if let data = try? JSONEncoder().encode(savedClips) {
            UserDefaults.standard.set(data, forKey: savedClipsKey)
        }
    }

    private func loadSaved() {
        guard let data = UserDefaults.standard.data(forKey: savedClipsKey),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        savedClips = decoded
    }
}
