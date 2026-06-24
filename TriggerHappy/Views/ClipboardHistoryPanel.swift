import SwiftUI
import Carbon.HIToolbox

struct ClipboardHistoryPanel: View {
    let clipboardStore: ClipboardStore
    let panelOpacity: Double
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var results: [ClipboardEntry] = []
    @State private var savedResults: [ClipboardEntry] = []
    @State private var timeStrings: [UUID: String] = [:]
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFocused: Bool

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "clipboard")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)

                TextField("Search clipboard...", text: $query)
                    .font(.system(size: 16, weight: .light))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { pasteSelected() }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .padding(.horizontal, 12)

            // Two-column layout
            HStack(alignment: .top, spacing: 0) {
                // Left: History
                historyColumn

                // Divider between columns
                if !savedResults.isEmpty {
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 1)
                        .padding(.vertical, 8)

                    // Right: Saved clips
                    savedColumn
                }
            }

            // Footer
            HStack {
                Text("\(results.count) item\(results.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                if !savedResults.isEmpty {
                    Text("\u{00b7} \(savedResults.count) saved")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("Clear History") {
                    clipboardStore.clearAll()
                    results = []
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .padding(.top, 4)
        }
        .frame(width: savedResults.isEmpty ? 520 : 740)
        .background(.regularMaterial.opacity(panelOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
        .onChange(of: query) { _, newQuery in
            results = clipboardStore.search(query: newQuery)
            savedResults = clipboardStore.searchSaved(query: newQuery)
            selectedIndex = 0
            cacheTimeStrings()
        }
        .onAppear {
            results = clipboardStore.search(query: "")
            savedResults = clipboardStore.searchSaved(query: "")
            cacheTimeStrings()
            installKeyMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    // MARK: - History Column

    private var historyColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if results.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Text(query.isEmpty ? "Clipboard empty" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(minHeight: 100)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, entry in
                                ClipboardEntryRow(
                                    entry: entry,
                                    isSelected: index == selectedIndex,
                                    isSaved: clipboardStore.isSaved(entry),
                                    timeString: timeString(for: entry),
                                    onSelect: { pasteEntry(entry) },
                                    onToggleSave: {
                                        clipboardStore.toggleSaved(entry)
                                        refreshResults()
                                    },
                                    onDelete: {
                                        clipboardStore.delete(id: entry.id)
                                        refreshResults()
                                        if selectedIndex >= results.count {
                                            selectedIndex = max(0, results.count - 1)
                                        }
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 200, maxHeight: 400)
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Saved Column

    private var savedColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Saved")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(savedResults) { entry in
                        ClipboardEntryRow(
                            entry: entry,
                            isSelected: false,
                            isSaved: true,
                            timeString: timeString(for: entry),
                            onSelect: { pasteEntry(entry) },
                            onToggleSave: {
                                clipboardStore.toggleSaved(entry)
                                refreshResults()
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(minHeight: 200, maxHeight: 400)
        }
        .frame(width: 220)
    }

    // MARK: - Actions

    private func refreshResults() {
        results = clipboardStore.search(query: query)
        savedResults = clipboardStore.searchSaved(query: query)
        cacheTimeStrings()
    }

    private func cacheTimeStrings() {
        let now = Date()
        var cached: [UUID: String] = [:]
        for entry in results + savedResults {
            cached[entry.id] = Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: now)
        }
        timeStrings = cached
    }

    private func timeString(for entry: ClipboardEntry) -> String {
        timeStrings[entry.id] ?? ""
    }

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                onDismiss()
                return nil
            case kVK_DownArrow:
                if selectedIndex < results.count - 1 { selectedIndex += 1 }
                return nil
            case kVK_UpArrow:
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case kVK_Return:
                pasteSelected()
                return nil
            case kVK_Delete:
                return event
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func pasteSelected() {
        guard selectedIndex < results.count else { return }
        pasteEntry(results[selectedIndex])
    }

    private func pasteEntry(_ entry: ClipboardEntry) {
        clipboardStore.copyToClipboard(entry)
        onDismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            simulatePaste()
        }
    }

}

private func simulatePaste() {
    let source = CGEventSource(stateID: .combinedSessionState)

    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
    keyDown?.flags = CGEventFlags.maskCommand
    keyDown?.post(tap: .cgSessionEventTap)

    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
    keyUp?.flags = CGEventFlags.maskCommand
    keyUp?.post(tap: .cgSessionEventTap)
}

struct ClipboardEntryRow: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let isSaved: Bool
    let timeString: String
    let onSelect: () -> Void
    let onToggleSave: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.preview)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(timeString)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if let appName = entry.sourceAppName {
                        Text(appName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            if isHovered || isSaved {
                if isHovered, let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 11))
                        .foregroundStyle(isSaved ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            if isSelected {
                KeyCap(label: "\u{21A9}")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.15)
                      : (isHovered ? Color.primary.opacity(0.04) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = hovering }
        }
    }
}

// MARK: - BBS Clipboard overlay
//
// The PCBoard-flavored sibling of ClipboardHistoryPanel. Where the modern panel
// puts saved clips in a second column, the BBS skin stacks them as a second
// "message area" so the whole thing stays a single monospaced grid. Hover
// buttons (save / delete) don't fit a text grid, so those actions move to
// keyboard commands surfaced in the footer: ⌘S saves, ⌘⌫ deletes the selection.

struct BBSClipboardPanel: View {
    let clipboardStore: ClipboardStore
    let panelOpacity: Double
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var results: [ClipboardEntry] = []
    @State private var savedResults: [ClipboardEntry] = []
    @State private var timeStrings: [UUID: String] = [:]
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFocused: Bool

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    @State private var historyStart = 0
    @State private var savedStart = 0
    @State private var hoverArea = 0      // 0 = none, 1 = history, 2 = saved
    @State private var wheelAccum = 0.0
    @State private var scrollMonitor: Any?

    private let panelWidth: CGFloat = 580
    private let hInset: CGFloat = 18
    private let maxHistoryRows = 8
    private let maxSavedRows = 4
    private var contentWidth: CGFloat { panelWidth - hInset * 2 }
    private var cols: Int { max(40, Int(contentWidth / BBS.charWidth)) }
    // Rows give up a 2-cell gutter on the right for the scrollbar, so the grid
    // stays put whether or not the bar is currently drawn.
    private var rowCols: Int { max(20, cols - 2) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BBSBanner(subtitle: "paste buffer")

            HStack(spacing: 6) {
                Text("\u{203A}")
                    .font(BBS.font(.bold))
                    .foregroundColor(BBS.cyan)
                TextField("", text: $query)
                    .textFieldStyle(.plain)
                    .font(BBS.font())
                    .foregroundColor(BBS.green)
                    .tint(BBS.green)
                    .focused($isSearchFocused)
                    .onSubmit { pasteSelected() }
                    .overlay(alignment: .leading) {
                        if query.isEmpty {
                            Text(BBS.flavor("filter the buffer\u{2026}"))
                                .font(BBS.font())
                                .foregroundColor(BBS.gray)
                                .allowsHitTesting(false)
                        }
                    }
            }

            BBS.divider("history", cols: cols).font(BBS.font())
            historyList

            if !savedResults.isEmpty {
                BBS.divider("saved", cols: cols).font(BBS.font())
                savedList
            }

            footer
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.horizontal, hInset)
        .padding(.vertical, 14)
        .modifier(BBSFrame(opacity: panelOpacity))
        .onChange(of: query) { _, newQuery in
            results = clipboardStore.search(query: newQuery)
            savedResults = clipboardStore.searchSaved(query: newQuery)
            selectedIndex = 0
            historyStart = 0
            savedStart = 0
            cacheTimeStrings()
        }
        .onAppear {
            results = clipboardStore.search(query: "")
            savedResults = clipboardStore.searchSaved(query: "")
            historyStart = 0
            savedStart = 0
            cacheTimeStrings()
            installKeyMonitor()
            installScrollMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear { removeKeyMonitor() }
    }

    // ---- lists ----

    private var historyList: some View {
        Group {
            if results.isEmpty {
                Text("  " + BBS.flavor(query.isEmpty ? "buffer empty" : "no matches"))
                    .font(BBS.font())
                    .foregroundColor(BBS.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                let total = results.count
                let start = clampedStart(historyStart, total: total, window: maxHistoryRows)
                let end = min(start + maxHistoryRows, total)
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(start..<end), id: \.self) { index in
                            let entry = results[index]
                            BBSClipRow(
                                entry: entry,
                                isSelected: index == selectedIndex,
                                isSaved: clipboardStore.isSaved(entry),
                                meta: metaString(for: entry),
                                cols: rowCols,
                                onSelect: { pasteEntry(entry) }
                            )
                        }
                        ForEach(Array(0..<max(0, maxHistoryRows - (end - start))), id: \.self) { _ in
                            Text(" ").font(BBS.font()).padding(.vertical, 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    BBSScrollbar(total: total, window: maxHistoryRows, start: start)
                }
                .contentShape(Rectangle())
                .onHover { hoverArea = $0 ? 1 : 0 }
            }
        }
    }

    private var savedList: some View {
        let total = savedResults.count
        let start = clampedStart(savedStart, total: total, window: maxSavedRows)
        let end = min(start + maxSavedRows, total)
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(start..<end), id: \.self) { index in
                    let entry = savedResults[index]
                    BBSClipRow(
                        entry: entry,
                        isSelected: false,
                        isSaved: true,
                        meta: metaString(for: entry),
                        cols: rowCols,
                        onSelect: { pasteEntry(entry) }
                    )
                }
                ForEach(Array(0..<max(0, maxSavedRows - (end - start))), id: \.self) { _ in
                    Text(" ").font(BBS.font()).padding(.vertical, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            BBSScrollbar(total: total, window: maxSavedRows, start: start)
        }
        .contentShape(Rectangle())
        .onHover { hoverArea = $0 ? 2 : 0 }
    }

    private func clampedStart(_ s: Int, total: Int, window: Int) -> Int {
        max(0, min(s, max(0, total - window)))
    }

    private var footer: some View {
        let key: (String) -> Text = { Text($0).foregroundColor(BBS.amber) }
        let dim: (String) -> Text = { Text($0).foregroundColor(BBS.gray) }
        let hint = key("[\u{2191}\u{2193}]") + dim(" " + BBS.leet("scroll") + "  ")
            + key("[\u{21B5}]") + dim(" " + BBS.leet("paste") + "  ")
            + key("[\u{2318}S]") + dim(" " + BBS.leet("save") + "  ")
            + key("[\u{2318}\u{232B}]") + dim(" " + BBS.leet("del"))
        var tally = "\(results.count) " + BBS.leet("clips")
        if !savedResults.isEmpty {
            tally += " \u{00B7} \(savedResults.count) " + BBS.leet("saved")
        }
        return HStack(spacing: 0) {
            hint
            Spacer(minLength: 8)
            Text(tally).foregroundColor(BBS.cyan)
        }
        .font(BBS.font())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ---- helpers ----

    private func metaString(for entry: ClipboardEntry) -> String {
        var s = timeStrings[entry.id] ?? ""
        if let app = entry.sourceAppName, !app.isEmpty {
            s += (s.isEmpty ? "" : " \u{00B7} ") + app
        }
        return s
    }

    private func cacheTimeStrings() {
        let now = Date()
        var cached: [UUID: String] = [:]
        for entry in results + savedResults {
            cached[entry.id] = Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: now)
        }
        timeStrings = cached
    }

    private func refreshResults() {
        results = clipboardStore.search(query: query)
        savedResults = clipboardStore.searchSaved(query: query)
        cacheTimeStrings()
    }

    // ---- key handling ----

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let cmd = event.modifierFlags.contains(.command)
            switch Int(event.keyCode) {
            case kVK_Escape:
                onDismiss()
                return nil
            case kVK_DownArrow:
                if selectedIndex < results.count - 1 { selectedIndex += 1; followSelection() }
                return nil
            case kVK_UpArrow:
                if selectedIndex > 0 { selectedIndex -= 1; followSelection() }
                return nil
            case kVK_Return:
                pasteSelected()
                return nil
            case kVK_ANSI_S where cmd:
                toggleSaveSelected()
                return nil
            case kVK_Delete where cmd:
                deleteSelected()
                return nil
            default:
                return event
            }
        }
    }

    /// Mouse-wheel support: scroll the saved area when the cursor is over it,
    /// otherwise move the history selection (the window follows). Deltas are
    /// accumulated so a trackpad doesn't fly through the list.
    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let dy = event.scrollingDeltaY
            if dy == 0 { return event }
            wheelAccum += dy
            let threshold = 6.0
            if wheelAccum <= -threshold {
                wheelAccum = 0
                scrollStep(down: true)
            } else if wheelAccum >= threshold {
                wheelAccum = 0
                scrollStep(down: false)
            }
            return event
        }
    }

    private func scrollStep(down: Bool) {
        if hoverArea == 2 {
            let maxStart = max(0, savedResults.count - maxSavedRows)
            savedStart = max(0, min(savedStart + (down ? 1 : -1), maxStart))
        } else if down {
            if selectedIndex < results.count - 1 { selectedIndex += 1; followSelection() }
        } else {
            if selectedIndex > 0 { selectedIndex -= 1; followSelection() }
        }
    }

    /// Slide the history window just enough to keep the selection visible.
    private func followSelection() {
        if selectedIndex < historyStart {
            historyStart = selectedIndex
        } else if selectedIndex >= historyStart + maxHistoryRows {
            historyStart = selectedIndex - maxHistoryRows + 1
        }
    }

    private func removeKeyMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    private func pasteSelected() {
        guard selectedIndex < results.count else { return }
        pasteEntry(results[selectedIndex])
    }

    private func toggleSaveSelected() {
        guard selectedIndex < results.count else { return }
        clipboardStore.toggleSaved(results[selectedIndex])
        refreshResults()
    }

    private func deleteSelected() {
        guard selectedIndex < results.count else { return }
        clipboardStore.delete(id: results[selectedIndex].id)
        refreshResults()
        if selectedIndex >= results.count {
            selectedIndex = max(0, results.count - 1)
        }
    }

    private func pasteEntry(_ entry: ClipboardEntry) {
        clipboardStore.copyToClipboard(entry)
        onDismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            simulatePaste()
        }
    }
}

/// One monospaced clip row built to exactly `cols` cells:
///   `▶ ★ some copied text ········· 2m · Safari`
/// Selected rows render as a full-width white-on-magenta lightbar; a ★ marks
/// saved clips. The preview is user content, so it is never l33t-ified.
struct BBSClipRow: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let isSaved: Bool
    let meta: String
    let cols: Int
    let onSelect: () -> Void

    var body: some View {
        let marker = isSelected ? "\u{25B6} " : "  "
        let star = isSaved ? "\u{2605} " : "  "
        let metaW = min(22, max(8, cols / 3))
        let metaText = BBS.trunc(meta, metaW)
        let metaPad = String(repeating: " ", count: max(0, metaW - metaText.count))
        let previewMax = max(1, cols - 7 - metaW)
        let preview = BBS.trunc(entry.preview, previewMax)
        let dotCount = max(1, cols - 6 - preview.count - metaW)
        let dots = String(repeating: "\u{00B7}", count: dotCount)

        let line: Text = {
            if isSelected {
                return Text(marker + star + preview + " " + dots + " " + metaPad + metaText)
                    .foregroundColor(BBS.onMagenta)
                    .bold()
            }
            return Text(marker).foregroundColor(BBS.cyan)
                + Text(star).foregroundColor(BBS.amber)
                + Text(preview).foregroundColor(BBS.white)
                + Text(" " + dots + " ").foregroundColor(BBS.gray)
                + Text(metaPad + metaText).foregroundColor(BBS.gray)
        }()

        return line
            .font(BBS.font())
            .lineLimit(1)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? BBS.magenta : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }
}

/// A CP437 scrollbar sized to a `window`-row list. The thumb (\u{2588}, magenta)
/// covers the visible fraction and slides with `start`; the track is \u{2592} in
/// dim gray. When the list fits its window the column renders as blank cells, so
/// it just reserves the gutter and the row grid never shifts. Cell metrics match
/// BBSClipRow (same font, same vertical padding, same VStack spacing) so the bar
/// lines up row-for-row.
struct BBSScrollbar: View {
    let total: Int
    let window: Int
    let start: Int

    var body: some View {
        let cells = max(1, window)
        let overflow = total > window

        var thumb = overflow
            ? max(1, Int((Double(cells) * Double(window) / Double(total)).rounded()))
            : cells
        if thumb > cells { thumb = cells }

        let maxStart = max(1, total - window)
        let posFrac = (overflow && maxStart > 0) ? Double(min(start, maxStart)) / Double(maxStart) : 0
        var thumbStart = Int((Double(cells - thumb) * posFrac).rounded())
        if thumbStart < 0 { thumbStart = 0 }
        if thumbStart + thumb > cells { thumbStart = cells - thumb }

        return VStack(spacing: 1) {
            ForEach(Array(0..<cells), id: \.self) { i in
                let isThumb = overflow && i >= thumbStart && i < thumbStart + thumb
                Text(overflow ? (isThumb ? "\u{2588}" : "\u{2592}") : " ")
                    .font(BBS.font())
                    .foregroundColor(isThumb ? BBS.magenta : BBS.gray.opacity(0.5))
                    .padding(.vertical, 1)
            }
        }
        .padding(.leading, 5)
    }
}
