import AppKit

struct IndexedApp: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    let bundleIdentifier: String?
    let icon: NSImage

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: IndexedApp, rhs: IndexedApp) -> Bool {
        lhs.url == rhs.url
    }
}

struct ScoredApp {
    let app: IndexedApp
    let score: Int
}

@Observable
final class AppIndexer {
    private(set) var apps: [IndexedApp] = []

    init() {
        reindex()
    }

    func reindex() {
        var found: [URL: IndexedApp] = [:]

        let searchDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
            NSHomeDirectory() + "/Applications",
        ]

        let fm = FileManager.default
        for dir in searchDirs {
            scanDirectory(URL(fileURLWithPath: dir), depth: 0, maxDepth: 2, found: &found, fm: fm)
        }

        apps = Array(found.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scanDirectory(_ dirURL: URL, depth: Int, maxDepth: Int, found: inout [URL: IndexedApp], fm: FileManager) {
        guard depth <= maxDepth else { return }

        // NOTE: no .skipsHiddenFiles. macOS flags the /Applications/Safari.app
        // cryptex symlink as BSD `hidden`, and .skipsHiddenFiles keys off that
        // flag — so it would silently drop Safari. We exclude only true dotfiles
        // (".DS_Store", ".localized", …) by name instead.
        guard let items = try? fm.contentsOfDirectory(
            at: dirURL,
            includingPropertiesForKeys: [.localizedNameKey, .isDirectoryKey],
            options: []
        ) else { return }

        for url in items {
            if url.lastPathComponent.hasPrefix(".") { continue }
            if url.pathExtension == "app" {
                if found[url] != nil { continue }
                let name = fm.displayName(atPath: url.path)
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 32, height: 32)
                let bundleID = Bundle(url: url)?.bundleIdentifier
                found[url] = IndexedApp(
                    id: url,
                    name: name,
                    url: url,
                    bundleIdentifier: bundleID,
                    icon: icon
                )
            } else {
                // Recurse into subdirectories (e.g. /Applications/Adobe Photoshop 2025/)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    scanDirectory(url, depth: depth + 1, maxDepth: maxDepth, found: &found, fm: fm)
                }
            }
        }
    }

    func search(query: String) -> [IndexedApp] {
        let q = query.lowercased()
        if q.isEmpty { return apps }

        var scored: [ScoredApp] = []

        for app in apps {
            if let score = fuzzyScore(query: q, target: app.name.lowercased()) {
                scored.append(ScoredApp(app: app, score: score))
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .map(\.app)
    }

    /// Indices of `name` that `query` greedily matches as a (case-insensitive)
    /// subsequence — for highlighting matched characters in results. Empty when
    /// `query` is empty or isn't a full subsequence of `name`.
    static func matchedIndices(query: String, in name: String) -> Set<Int> {
        let q = Array(query.lowercased())
        guard !q.isEmpty else { return [] }
        let chars = Array(name.lowercased())
        var matched = Set<Int>()
        var qi = 0
        for (i, c) in chars.enumerated() where qi < q.count && c == q[qi] {
            matched.insert(i)
            qi += 1
        }
        return qi == q.count ? matched : []
    }

    /// Returns a score if query fuzzy-matches target, nil if no match.
    /// Higher score = better match.
    private func fuzzyScore(query: String, target: String) -> Int? {
        let queryChars = Array(query)
        let targetChars = Array(target)

        var qi = 0
        var score = 0
        var consecutive = 0
        var lastMatchIndex = -1

        for (ti, tc) in targetChars.enumerated() {
            guard qi < queryChars.count else { break }

            if tc == queryChars[qi] {
                qi += 1
                score += 1

                // Bonus for consecutive matches
                if ti == lastMatchIndex + 1 {
                    consecutive += 1
                    score += consecutive * 3
                } else {
                    consecutive = 0
                }

                // Bonus for matching at start of word
                if ti == 0 {
                    score += 10
                } else if targetChars[ti - 1] == " " || targetChars[ti - 1] == "-" || targetChars[ti - 1] == "." {
                    score += 5
                }

                lastMatchIndex = ti
            }
        }

        // All query chars must match
        guard qi == queryChars.count else { return nil }

        // Bonus for exact prefix match
        if target.hasPrefix(query) {
            score += 20
        }

        // Bonus for shorter targets (more relevant)
        score += max(0, 20 - (targetChars.count - queryChars.count))

        return score
    }
}
