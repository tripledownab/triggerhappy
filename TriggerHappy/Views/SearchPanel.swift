import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SearchPanel: View {
    let appIndexer: AppIndexer
    let panelOpacity: Double
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var results: [IndexedApp] = []
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFocused: Bool

    private let maxVisible = 6

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.tertiary)

                TextField("Search apps...", text: $query)
                    .font(.system(size: 18, weight: .light))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { launchSelected() }

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

            // Always show results
            let visible = Array(results.prefix(maxVisible))
            if !visible.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                VStack(spacing: 1) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, app in
                        SearchResultRow(
                            app: app,
                            isSelected: index == selectedIndex,
                            onSelect: { launchApp(app) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                if results.count > maxVisible {
                    Text("\(results.count - maxVisible) more...")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 6)
                }
            }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial.opacity(panelOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
        .onChange(of: query) { _, newQuery in
            results = appIndexer.search(query: newQuery)
            selectedIndex = 0
        }
        .onAppear {
            results = appIndexer.search(query: "")
            installKeyMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                onDismiss()
                return nil
            case kVK_DownArrow:
                let count = min(results.count, maxVisible)
                if selectedIndex < count - 1 {
                    selectedIndex += 1
                }
                return nil
            case kVK_UpArrow:
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return nil
            case kVK_Return:
                launchSelected()
                return nil
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

    private func launchSelected() {
        let visible = Array(results.prefix(maxVisible))
        guard selectedIndex < visible.count else { return }
        launchApp(visible[selectedIndex])
    }

    private func launchApp(_ app: IndexedApp) {
        AppLauncher.launch(appURL: app.url)
        onDismiss()
    }
}

struct SearchResultRow: View {
    let app: IndexedApp
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.08), radius: 1, y: 0.5)

            Text(app.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)

            Spacer()

            if isSelected {
                KeyCap(label: "\u{21A9}")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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

// MARK: - Launcher Theme
//
// The App Launcher overlay can wear one of two skins, chosen in Settings.
// `.modern` is the frosted SwiftUI panel above; `.bbs` is the ANSI / PCBoard
// throwback below — inspired by the sister project "Doorway". The enum is the
// single knob the rest of the app branches on.

enum LauncherTheme: String, CaseIterable, Identifiable {
    case modern
    case bbs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .modern: return "Modern"
        case .bbs:    return "BBS"
        }
    }
}

// MARK: - BBS banner wordmark style
//
// The animated header wordmark is either a full-spectrum `rainbow` or a
// monochromatic shimmer locked to one hue (a "single-color rainbow"). Chosen in
// Settings; persisted under the key below and read fresh each time a banner
// mounts. Hues come from the screenshot-sampled palette so the mono modes sit in
// the same family as the rest of the chrome.

enum BBSWordmark: String, CaseIterable, Identifiable {
    case theme, rainbow, cyan, magenta, amber, green, blue, red

    var id: String { rawValue }

    var label: String {
        switch self {
        case .theme:   return "Theme"
        case .rainbow: return "Rainbow"
        case .cyan:    return "Cyan"
        case .magenta: return "Magenta"
        case .amber:   return "Amber"
        case .green:   return "Green"
        case .blue:    return "Blue"
        case .red:     return "Coral"
        }
    }

    /// Base hue (0…1) for the monochromatic shimmer. Unused for `.rainbow`.
    var hue: Double {
        switch self {
        case .theme, .rainbow, .cyan: return 0.500
        case .magenta:        return 0.897
        case .amber:          return 0.117
        case .green:          return 0.344
        case .blue:           return 0.550
        case .red:            return 0.000
        }
    }

    /// Solid swatch used for the shaded blocks flanking the wordmark.
    var swatch: Color {
        switch self {
        case .theme, .rainbow, .cyan: return BBS.cyan
        case .magenta:        return BBS.magenta
        case .amber:          return BBS.amber
        case .green:          return BBS.green
        case .blue:           return BBS.blue
        case .red:            return BBS.red
        }
    }

    static var current: BBSWordmark {
        BBSWordmark(rawValue: UserDefaults.standard.string(forKey: "com.triggerhappy.bbsWordmark") ?? "") ?? .theme
    }
}

// MARK: - BBS color schemes
//
// A full palette swap for the BBS overlays, chosen in Settings. `.classic` is
// the screenshot-sampled pastel-on-slate; the others are recognizable terminal
// looks. Every BBS.* color resolves through the selected scheme (cached below),
// so changing this one knob reskins all three overlays at once.

struct BBSPalette {
    let slate, cyan, magenta, yellow, white, green, red, gray, amber, blue: Color
}

enum BBSScheme: String, CaseIterable, Identifiable {
    case classic, midnight, amber, green, synthwave
    case dracula, nord, solarized, tokyoNight, gruvbox
    case oneDark, monokai, catppuccin, githubDark, rosePine

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic:    return "Classic"
        case .midnight:   return "Midnight"
        case .amber:      return "Amber"
        case .green:      return "Green"
        case .synthwave:  return "Synthwave"
        case .dracula:    return "Dracula"
        case .nord:       return "Nord"
        case .solarized:  return "Solarized"
        case .tokyoNight: return "Tokyo Night"
        case .gruvbox:    return "Gruvbox"
        case .oneDark:    return "One Dark"
        case .monokai:    return "Monokai"
        case .catppuccin: return "Catppuccin"
        case .githubDark: return "GitHub Dark"
        case .rosePine:   return "Rosé Pine"
        }
    }

    var palette: BBSPalette {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch self {
        case .classic: // muted pastel on slate (sampled from Doorway)
            return BBSPalette(
                slate:   c(0.220, 0.220, 0.282), cyan:  c(0.596, 0.847, 0.847),
                magenta: c(0.878, 0.424, 0.706), yellow: c(0.988, 0.894, 0.706),
                white:   c(0.847, 0.847, 0.847), green: c(0.612, 0.863, 0.627),
                red:     c(0.988, 0.424, 0.424), gray:  c(0.408, 0.471, 0.533),
                amber:   c(0.988, 0.706, 0.047), blue:  c(0.047, 0.706, 0.988))
        case .midnight: // high-intensity ANSI on black
            return BBSPalette(
                slate:   c(0.039, 0.039, 0.063), cyan:  c(0.235, 0.949, 0.949),
                magenta: c(1.000, 0.280, 0.851), yellow: c(1.000, 0.949, 0.302),
                white:   c(0.961, 0.980, 1.000), green: c(0.380, 1.000, 0.471),
                red:     c(1.000, 0.361, 0.361), gray:  c(0.460, 0.520, 0.580),
                amber:   c(1.000, 0.690, 0.000), blue:  c(0.400, 0.553, 1.000))
        case .amber: // amber phosphor monochrome
            return BBSPalette(
                slate:   c(0.086, 0.059, 0.020), cyan:  c(0.851, 0.584, 0.169),
                magenta: c(0.722, 0.361, 0.071), yellow: c(1.000, 0.878, 0.541),
                white:   c(1.000, 0.890, 0.659), green: c(1.000, 0.690, 0.180),
                red:     c(1.000, 0.478, 0.180), gray:  c(0.604, 0.471, 0.220),
                amber:   c(1.000, 0.824, 0.290), blue:  c(0.851, 0.584, 0.169))
        case .green: // green phosphor monochrome
            return BBSPalette(
                slate:   c(0.008, 0.078, 0.039), cyan:  c(0.180, 0.851, 0.541),
                magenta: c(0.118, 0.478, 0.227), yellow: c(0.812, 1.000, 0.541),
                white:   c(0.784, 1.000, 0.784), green: c(0.200, 1.000, 0.400),
                red:     c(0.784, 1.000, 0.302), gray:  c(0.247, 0.541, 0.310),
                amber:   c(0.612, 1.000, 0.235), blue:  c(0.180, 0.851, 0.624))
        case .synthwave: // neon pink/cyan on deep indigo
            return BBSPalette(
                slate:   c(0.106, 0.063, 0.200), cyan:  c(0.300, 0.878, 1.000),
                magenta: c(1.000, 0.302, 0.651), yellow: c(1.000, 0.847, 0.420),
                white:   c(0.941, 0.902, 1.000), green: c(0.463, 0.961, 0.753),
                red:     c(1.000, 0.361, 0.541), gray:  c(0.541, 0.478, 0.690),
                amber:   c(1.000, 0.722, 0.302), blue:  c(0.424, 0.482, 1.000))
        case .dracula:
            return BBSPalette(
                slate:   c(0.157, 0.165, 0.212), cyan:  c(0.545, 0.914, 0.992),
                magenta: c(1.000, 0.475, 0.776), yellow: c(0.945, 0.980, 0.549),
                white:   c(0.973, 0.973, 0.949), green: c(0.314, 0.980, 0.482),
                red:     c(1.000, 0.333, 0.333), gray:  c(0.384, 0.447, 0.643),
                amber:   c(1.000, 0.722, 0.424), blue:  c(0.741, 0.576, 0.976))
        case .nord:
            return BBSPalette(
                slate:   c(0.180, 0.204, 0.251), cyan:  c(0.533, 0.753, 0.816),
                magenta: c(0.706, 0.557, 0.678), yellow: c(0.922, 0.796, 0.545),
                white:   c(0.925, 0.937, 0.957), green: c(0.639, 0.745, 0.549),
                red:     c(0.749, 0.380, 0.416), gray:  c(0.298, 0.337, 0.416),
                amber:   c(0.816, 0.529, 0.439), blue:  c(0.506, 0.631, 0.757))
        case .solarized:
            return BBSPalette(
                slate:   c(0.000, 0.169, 0.212), cyan:  c(0.165, 0.631, 0.596),
                magenta: c(0.827, 0.212, 0.510), yellow: c(0.710, 0.537, 0.000),
                white:   c(0.576, 0.631, 0.631), green: c(0.522, 0.600, 0.000),
                red:     c(0.863, 0.196, 0.184), gray:  c(0.345, 0.431, 0.459),
                amber:   c(0.796, 0.294, 0.086), blue:  c(0.149, 0.545, 0.824))
        case .tokyoNight:
            return BBSPalette(
                slate:   c(0.102, 0.106, 0.149), cyan:  c(0.490, 0.812, 1.000),
                magenta: c(0.616, 0.486, 0.847), yellow: c(0.878, 0.686, 0.408),
                white:   c(0.753, 0.792, 0.961), green: c(0.620, 0.808, 0.416),
                red:     c(0.969, 0.463, 0.557), gray:  c(0.337, 0.373, 0.537),
                amber:   c(1.000, 0.620, 0.392), blue:  c(0.478, 0.635, 0.969))
        case .gruvbox:
            return BBSPalette(
                slate:   c(0.157, 0.157, 0.157), cyan:  c(0.557, 0.753, 0.486),
                magenta: c(0.827, 0.525, 0.608), yellow: c(0.980, 0.741, 0.184),
                white:   c(0.922, 0.859, 0.698), green: c(0.722, 0.733, 0.149),
                red:     c(0.984, 0.286, 0.204), gray:  c(0.573, 0.514, 0.455),
                amber:   c(0.996, 0.502, 0.098), blue:  c(0.514, 0.647, 0.596))
        case .oneDark:
            return BBSPalette(
                slate:   c(0.157, 0.173, 0.204), cyan:  c(0.337, 0.714, 0.761),
                magenta: c(0.776, 0.471, 0.867), yellow: c(0.898, 0.753, 0.482),
                white:   c(0.671, 0.698, 0.749), green: c(0.596, 0.765, 0.475),
                red:     c(0.878, 0.424, 0.459), gray:  c(0.361, 0.388, 0.439),
                amber:   c(0.820, 0.604, 0.400), blue:  c(0.380, 0.686, 0.937))
        case .monokai:
            return BBSPalette(
                slate:   c(0.153, 0.157, 0.133), cyan:  c(0.400, 0.851, 0.937),
                magenta: c(0.976, 0.149, 0.447), yellow: c(0.902, 0.859, 0.455),
                white:   c(0.973, 0.973, 0.949), green: c(0.651, 0.886, 0.180),
                red:     c(1.000, 0.380, 0.533), gray:  c(0.459, 0.443, 0.369),
                amber:   c(0.992, 0.592, 0.122), blue:  c(0.682, 0.506, 1.000))
        case .catppuccin:
            return BBSPalette(
                slate:   c(0.118, 0.118, 0.180), cyan:  c(0.580, 0.886, 0.835),
                magenta: c(0.796, 0.651, 0.969), yellow: c(0.976, 0.886, 0.686),
                white:   c(0.804, 0.839, 0.957), green: c(0.651, 0.890, 0.631),
                red:     c(0.953, 0.545, 0.659), gray:  c(0.424, 0.439, 0.525),
                amber:   c(0.980, 0.702, 0.529), blue:  c(0.537, 0.706, 0.980))
        case .githubDark:
            return BBSPalette(
                slate:   c(0.051, 0.067, 0.090), cyan:  c(0.463, 0.890, 0.918),
                magenta: c(0.737, 0.549, 1.000), yellow: c(0.824, 0.600, 0.133),
                white:   c(0.902, 0.929, 0.953), green: c(0.337, 0.827, 0.392),
                red:     c(1.000, 0.482, 0.447), gray:  c(0.545, 0.580, 0.620),
                amber:   c(1.000, 0.651, 0.341), blue:  c(0.345, 0.651, 1.000))
        case .rosePine:
            return BBSPalette(
                slate:   c(0.098, 0.090, 0.141), cyan:  c(0.612, 0.812, 0.847),
                magenta: c(0.769, 0.655, 0.906), yellow: c(0.965, 0.757, 0.467),
                white:   c(0.878, 0.871, 0.957), green: c(0.490, 0.710, 0.659),
                red:     c(0.922, 0.435, 0.573), gray:  c(0.431, 0.416, 0.525),
                amber:   c(0.965, 0.757, 0.467), blue:  c(0.192, 0.455, 0.561))
        }
    }

    static var current: BBSScheme {
        BBSScheme(rawValue: UserDefaults.standard.string(forKey: "com.triggerhappy.bbsScheme") ?? "") ?? .classic
    }
}

// MARK: - BBS / CP437 aesthetic toolkit
//
// A small vocabulary lifted from Doorway's 90s ANSI-art look: high-intensity
// base-16 colors on black, a monospaced grid, l33t/StUdLy chrome text, scene
// dividers, and a white-on-magenta "lightbar" for the selected row. Everything
// here is presentation-only chrome — it never touches app names the user has to
// read, only the surrounding decoration.

enum BBS {
    // ---- palette (resolves through the selected BBSScheme) ----
    static var slate: Color   { palette.slate }
    static var cyan: Color    { palette.cyan }
    static var magenta: Color { palette.magenta }
    static var yellow: Color  { palette.yellow }
    static var white: Color   { palette.white }
    static var green: Color   { palette.green }
    static var red: Color     { palette.red }
    static var gray: Color    { palette.gray }
    static var amber: Color   { palette.amber }
    static var blue: Color    { palette.blue }

    // Cache the resolved palette and rebuild only when the scheme changes, so the
    // hot paths (per-character rainbow, every row) don't re-read UserDefaults.
    private static var cachedKey = ""
    private static var cachedPalette = BBSScheme.classic.palette
    static var palette: BBSPalette {
        let key = BBSScheme.current.rawValue
        if key != cachedKey {
            cachedKey = key
            cachedPalette = BBSScheme.current.palette
        }
        return cachedPalette
    }

    /// Relative luminance (0…1) of a color, via its RGB components.
    static func luminance(of color: Color) -> Double {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        return 0.2126 * Double(ns.redComponent) + 0.7152 * Double(ns.greenComponent) + 0.0722 * Double(ns.blueComponent)
    }

    /// HSB components of a color.
    static func hsb(of color: Color) -> (h: Double, s: Double, b: Double) {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        return (Double(ns.hueComponent), Double(ns.saturationComponent), Double(ns.brightnessComponent))
    }

    /// Readable text color for the selection lightbar: dark on a light accent,
    /// white otherwise — keeps pastel schemes (Catppuccin, etc.) legible without
    /// per-scheme tuning.
    static var onMagenta: Color {
        luminance(of: magenta) > 0.60 ? slate : white
    }

    // ---- monospaced grid ----
    static let fontSize: CGFloat = 13

    static func font(_ weight: Font.Weight = .regular) -> Font {
        .system(size: fontSize, weight: weight, design: .monospaced)
    }

    /// Advance width of one monospaced cell at `fontSize`. Lets us build fixed
    /// CP437 lines (dividers, dotted leaders) that fill exactly to the frame.
    static let charWidth: CGFloat = {
        let f = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return ("M" as NSString).size(withAttributes: [.font: f]).width
    }()

    // ---- l33t / StUdLy text (chrome only) ----
    static func leet(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "a", "A": out += "4"
            case "e", "E": out += "3"
            case "o", "O": out += "0"
            case "i", "I": out += "1"
            case "s", "S": out += "5"
            case "t", "T": out += "7"
            default:       out.append(ch)
            }
        }
        return out
    }

    static func studly(_ s: String) -> String {
        var out = ""
        var up = true
        for ch in s {
            if ch.isLetter {
                out += up ? ch.uppercased() : ch.lowercased()
                up.toggle()
            } else {
                out.append(ch)
            }
        }
        return out
    }

    /// Full scene treatment: l33t numerals + StUdLy caps.
    static func flavor(_ s: String) -> String { studly(leet(s)) }

    /// Per-character hue sweep for the header wordmark. `phase` is seconds; the
    /// band drifts ~110°/s and spans ~26°/char, so a red→cyan arc rides the
    /// letters and cycles fully every few seconds.
    static func rainbow(_ s: String, phase: Double) -> Text {
        var result = Text("")
        for (i, ch) in s.enumerated() {
            let deg = phase * 110 + Double(i) * 26
            let hue = (deg.truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360) / 360
            result = result
                + Text(String(ch))
                    .foregroundColor(Color(hue: hue, saturation: 1, brightness: 1))
        }
        return result
    }

    /// Animated wordmark. `.rainbow` is the full-spectrum cycle; `.theme` tracks
    /// the scheme's main color (the same hue the flanking ornaments use),
    /// shimmering through nearby hues; an explicit color locks to that hue. In the
    /// last two a brightness wave drifts along the letters, cresting toward white.
    static func wordmark(_ s: String, phase: Double, style: BBSWordmark) -> Text {
        if style == .rainbow { return rainbow(s, phase: phase) }
        let base: (h: Double, s: Double, b: Double)
        let hueBand: Double
        if style == .theme {
            let m = hsb(of: cyan)
            base = (m.h, max(m.s, 0.45), min(1.0, m.b + 0.12))
            hueBand = 0.06
        } else {
            base = (style.hue, 1.0, 1.0)
            hueBand = 0.0
        }
        var result = Text("")
        for (i, ch) in s.enumerated() {
            let deg = phase * 110 + Double(i) * 26
            let wave = sin(deg * .pi / 180)          // -1…1
            let t = (wave + 1) / 2                    // 0…1
            let hue = (base.h + hueBand * wave).truncatingRemainder(dividingBy: 1)
            let bright = base.b * (0.55 + 0.45 * t)
            let sat = base.s * (1.0 - 0.45 * t)       // crest desaturates toward white
            result = result
                + Text(String(ch))
                    .foregroundColor(Color(hue: hue < 0 ? hue + 1 : hue, saturation: sat, brightness: bright)).bold()
        }
        return result
    }

    /// NFO-style separator:  ··──┼──[ TAG ]──┼──··  filling exactly `cols` cells.
    static func divider(_ label: String, cols: Int) -> Text {
        let lab = leet(label)
        let tagLen = 2 + lab.count + 2          // "[ " + lab + " ]"
        let fixed = 2 + 1 + tagLen + 1 + 2      // ·· ┼ tag ┼ ··
        let rails = max(2, cols - fixed)
        let left = rails / 2
        let right = rails - left
        let dashL = String(repeating: "─", count: left)
        let dashR = String(repeating: "─", count: right)
        return Text("··" + dashL + "┼[ ").foregroundColor(cyan)
            + Text(lab).foregroundColor(amber).bold()
            + Text(" ]┼" + dashR + "··").foregroundColor(cyan)
    }
}

extension BBS {
    /// Truncate to `n` cells with a trailing ellipsis. Used for chrome and for
    /// user content alike (the latter stays un-l33t'd so it reads cleanly).
    static func trunc(_ s: String, _ n: Int) -> String {
        if s.count <= n { return s }
        if n <= 1 { return "\u{2026}" }
        return String(s.prefix(n - 1)) + "\u{2026}"
    }

    /// Render `name` with its query-matched characters in `matched` and the rest
    /// in `dim`; the whole name in `base` when there's no query (or no match).
    static func matchedName(_ name: String, query: String, base: Color, matched: Color, dim: Color) -> Text {
        let idx = AppIndexer.matchedIndices(query: query, in: name)
        if idx.isEmpty { return Text(name).foregroundColor(base) }
        var result = Text("")
        for (i, ch) in name.enumerated() {
            result = result + Text(String(ch)).foregroundColor(idx.contains(i) ? matched : dim)
        }
        return result
    }
}

/// Shared CP437 banner: shaded blocks framing an animated rainbow wordmark over
/// a l33t/StUdLy subtitle. Both BBS overlays mount this so they read as one app.
struct BBSBanner: View {
    let subtitle: String

    var body: some View {
        let style = BBSWordmark.current
        return VStack(spacing: 2) {
            TimelineView(.animation) { ctx in
                let phase = ctx.date.timeIntervalSinceReferenceDate
                HStack(spacing: 0) {
                    Text("\u{2591}\u{2592}\u{2593}\u{2588} ").foregroundColor(style.swatch)
                    BBS.wordmark(BBS.leet("TRIGGER\u{00B7}HAPPY"), phase: phase, style: style)
                    Text(" \u{2588}\u{2593}\u{2592}\u{2591}").foregroundColor(style.swatch)
                }
                .font(BBS.font(.bold))
            }
            (Text("\u{00B7}\u{00B0}\u{00B7} ").foregroundColor(BBS.gray)
                + Text(BBS.flavor(subtitle)).foregroundColor(BBS.white)
                + Text(" \u{00B7}\u{00B0}\u{00B7}").foregroundColor(BBS.gray))
                .font(BBS.font())
        }
        .frame(maxWidth: .infinity)
    }
}

/// A CP437 double-line frame: two concentric square strokes on black, plus a
/// soft cyan phosphor glow. Square corners (not rounded) sell the terminal feel.
struct BBSFrame: ViewModifier {
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .background(BBS.slate.opacity(max(0.6, opacity)))
            .overlay(Rectangle().strokeBorder(BBS.cyan, lineWidth: 1))
            .overlay(Rectangle().inset(by: 3).strokeBorder(BBS.cyan.opacity(0.55), lineWidth: 1))
            .shadow(color: BBS.cyan.opacity(0.35), radius: 14)
            .shadow(color: .black.opacity(0.55), radius: 24, y: 10)
    }
}

// MARK: - BBS App Launcher overlay

struct BBSSearchPanel: View {
    let appIndexer: AppIndexer
    let panelOpacity: Double
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var results: [IndexedApp] = []
    @State private var eventMonitor: Any?
    @FocusState private var isSearchFocused: Bool

    private let maxVisible = 8
    private let panelWidth: CGFloat = 500
    private let hInset: CGFloat = 18

    private var contentWidth: CGFloat { panelWidth - hInset * 2 }
    private var cols: Int { max(24, Int(contentWidth / BBS.charWidth)) }

    var body: some View {
        let visible = Array(results.prefix(maxVisible))
        let more = max(0, results.count - visible.count)

        VStack(alignment: .leading, spacing: 8) {
            BBSBanner(subtitle: "app launcher")

            // Logon prompt + live query
            HStack(spacing: 6) {
                Text("›")
                    .font(BBS.font(.bold))
                    .foregroundColor(BBS.cyan)
                TextField("", text: $query)
                    .textFieldStyle(.plain)
                    .font(BBS.font())
                    .foregroundColor(BBS.green)
                    .tint(BBS.green)
                    .focused($isSearchFocused)
                    .onSubmit { launchSelected() }
                    .overlay(alignment: .leading) {
                        if query.isEmpty {
                            Text(BBS.flavor("type to dial a program…"))
                                .font(BBS.font())
                                .foregroundColor(BBS.gray)
                                .allowsHitTesting(false)
                        }
                    }
            }

            BBS.divider("programs", cols: cols)
                .font(BBS.font())

            // Result lightbar list
            VStack(alignment: .leading, spacing: 1) {
                if visible.isEmpty {
                    Text("  " + BBS.flavor("no carrier — 0 matches"))
                        .font(BBS.font())
                        .foregroundColor(BBS.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, app in
                        BBSResultRow(
                            app: app,
                            query: query,
                            index: index,
                            isSelected: index == selectedIndex,
                            cols: cols,
                            onSelect: { launchApp(app) }
                        )
                    }
                }
            }

            footer(count: results.count, more: more)
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.horizontal, hInset)
        .padding(.vertical, 14)
        .modifier(BBSFrame(opacity: panelOpacity))
        .onChange(of: query) { _, newQuery in
            results = appIndexer.search(query: newQuery)
            selectedIndex = 0
        }
        .onAppear {
            results = appIndexer.search(query: "")
            installKeyMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onDisappear { removeKeyMonitor() }
    }

    // ---- chrome ----

    private func footer(count: Int, more: Int) -> some View {
        let key: (String) -> Text = { Text($0).foregroundColor(BBS.amber) }
        let dim: (String) -> Text = { Text($0).foregroundColor(BBS.gray) }
        let hint = key("[↑↓]") + dim(" " + BBS.leet("move") + "  ")
            + key("[↵]") + dim(" " + BBS.leet("run") + "  ")
            + key("[esc]") + dim(" " + BBS.leet("hangup"))
        var tally = "\(count) " + BBS.leet("programs")
        if more > 0 { tally += " · \(more) " + BBS.leet("more") }

        return HStack(spacing: 0) {
            hint
            Spacer(minLength: 8)
            Text(tally).foregroundColor(BBS.cyan)
        }
        .font(BBS.font())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ---- key handling (mirrors SearchPanel) ----

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                onDismiss()
                return nil
            case kVK_DownArrow:
                let count = min(results.count, maxVisible)
                if selectedIndex < count - 1 { selectedIndex += 1 }
                return nil
            case kVK_UpArrow:
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case kVK_Return:
                launchSelected()
                return nil
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

    private func launchSelected() {
        let visible = Array(results.prefix(maxVisible))
        guard selectedIndex < visible.count else { return }
        launchApp(visible[selectedIndex])
    }

    private func launchApp(_ app: IndexedApp) {
        AppLauncher.launch(appURL: app.url)
        onDismiss()
    }
}

/// One monospaced menu row built to exactly `cols` cells:
///   `▶ Firefox ········· 1`
/// Selected rows render as a full-width white-on-magenta lightbar.
struct BBSResultRow: View {
    let app: IndexedApp
    let query: String
    let index: Int
    let isSelected: Bool
    let cols: Int
    let onSelect: () -> Void

    var body: some View {
        // marker(2) + name + " " + dots + " " + num(2) == cols
        let marker = isSelected ? "▶ " : "  "
        let num = String(format: "%2d", index + 1)
        let nameMax = max(1, cols - 8)
        let name = truncate(app.name, nameMax)
        let dotCount = max(1, cols - 6 - name.count)
        let dots = String(repeating: "·", count: dotCount)

        let nameText: Text = isSelected
            ? BBS.matchedName(name, query: query, base: BBS.onMagenta, matched: BBS.onMagenta, dim: BBS.onMagenta.opacity(0.55)).bold()
            : BBS.matchedName(name, query: query, base: BBS.green, matched: BBS.amber, dim: BBS.green.opacity(0.5))

        let line: Text = {
            if isSelected {
                return Text(marker).foregroundColor(BBS.onMagenta).bold()
                    + nameText
                    + Text(" " + dots + " " + num).foregroundColor(BBS.onMagenta).bold()
            }
            return Text(marker).foregroundColor(BBS.cyan)
                + nameText
                + Text(" " + dots + " ").foregroundColor(BBS.gray)
                + Text(num).foregroundColor(BBS.gray)
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

    private func truncate(_ s: String, _ n: Int) -> String {
        if s.count <= n { return s }
        if n <= 1 { return "…" }
        return String(s.prefix(n - 1)) + "…"
    }
}


// MARK: - Launcher layout

enum LauncherLayout: String, CaseIterable, Identifiable {
    case center
    case quake

    var id: String { rawValue }

    var label: String {
        switch self {
        case .center: return "Center"
        case .quake:  return "Quake"
        }
    }
}

// MARK: - Quake drop-down launcher (BBS-styled)
//
// A full-width, one-line console that folds down from the top of the screen.
// The left ~20% is the query; the rest is the result set laid out horizontally,
// auto-scrolling to keep the selection in view. Arrow keys navigate.

struct QuakeSearchPanel: View {
    let appIndexer: AppIndexer
    let panelOpacity: Double
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var results: [IndexedApp] = []
    @State private var eventMonitor: Any?
    @State private var dropped = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                inputRegion
                    .frame(width: geo.size.width * 0.2, alignment: .leading)

                Rectangle()
                    .fill(BBS.cyan.opacity(0.45))
                    .frame(width: 1)
                    .padding(.vertical, 10)

                resultsRow
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(BBS.slate.opacity(max(0.7, panelOpacity)))
            .overlay(alignment: .bottom) {
                Rectangle().fill(BBS.cyan).frame(height: 1)
            }
            .shadow(color: BBS.cyan.opacity(0.30), radius: 10, y: 5)
            .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
            // Fold-down: the strip starts pulled up above the window and slides
            // into place. Window-frame animation was unreliable with the hosting
            // view, so we drive it in SwiftUI and let the window clip the overflow.
            .offset(y: dropped ? 0 : -geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: query) { _, newQuery in
            results = appIndexer.search(query: newQuery)
            selectedIndex = 0
        }
        .onAppear {
            results = appIndexer.search(query: "")
            installKeyMonitor()
            // Slide the strip in next runloop tick so the first frame renders
            // pulled-up (dropped == false), giving SwiftUI a change to animate.
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.18)) { dropped = true }
            }
            for delay in [0.05, 0.2] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { isSearchFocused = true }
            }
        }
        .onDisappear { removeKeyMonitor() }
    }

    private var inputRegion: some View {
        HStack(spacing: 8) {
            Text("\u{203A}")
                .font(BBS.font(.bold))
                .foregroundColor(BBS.cyan)
            TextField("", text: $query)
                .textFieldStyle(.plain)
                .font(BBS.font())
                .foregroundColor(BBS.green)
                .tint(BBS.green)
                .focused($isSearchFocused)
                .onSubmit { launchSelected() }
                .overlay(alignment: .leading) {
                    if query.isEmpty {
                        Text(BBS.flavor("run a program\u{2026}"))
                            .font(BBS.font())
                            .foregroundColor(BBS.gray)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.horizontal, 16)
    }

    private var resultsRow: some View {
        GeometryReader { geo in
            HStack(spacing: 6) {
                if results.isEmpty {
                    Text(BBS.flavor(query.isEmpty ? "type to run a program" : "no carrier"))
                        .font(BBS.font())
                        .foregroundColor(query.isEmpty ? BBS.gray : BBS.red)
                        .padding(.leading, 6)
                } else {
                    ForEach(Array(results.enumerated()), id: \.element.id) { i, app in
                        QuakeChip(app: app, query: query, isSelected: i == selectedIndex, onSelect: { launchApp(app) })
                    }
                }
            }
            // Lay out at natural width so chips aren't squeezed/truncated to the
            // viewport; the offset + clip provides the horizontal scroll instead.
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .frame(height: geo.size.height, alignment: .leading)
            .offset(x: resultsOffset(viewport: geo.size.width))
            .animation(.easeOut(duration: 0.14), value: selectedIndex)
        }
        .clipped()
    }

    // Manual horizontal scroll: keep the selected chip centered, clamped to the
    // ends. Chip widths are derived from the monospaced cell width, so no
    // ScrollView (hence no macOS scrollbar) is involved.
    private func resultsOffset(viewport: CGFloat) -> CGFloat {
        guard !results.isEmpty else { return 0 }
        let spacing: CGFloat = 6, rowPad: CGFloat = 12, chipPad: CGFloat = 10
        func chipW(_ app: IndexedApp) -> CGFloat { CGFloat(app.name.count) * BBS.charWidth + chipPad * 2 }

        var lead = rowPad
        var selCenter = rowPad
        var total = rowPad
        for (i, app) in results.enumerated() {
            let w = chipW(app)
            if i == selectedIndex { selCenter = lead + w / 2 }
            lead += w + spacing
            total += w + (i < results.count - 1 ? spacing : 0)
        }
        total += rowPad

        let desired = viewport / 2 - selCenter
        let minOffset = min(0, viewport - total)
        return max(minOffset, min(0, desired))
    }

    private func installKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                onDismiss()
                return nil
            case kVK_RightArrow, kVK_DownArrow:
                if selectedIndex < results.count - 1 { selectedIndex += 1 }
                return nil
            case kVK_LeftArrow, kVK_UpArrow:
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case kVK_Return:
                launchSelected()
                return nil
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

    private func launchSelected() {
        guard selectedIndex < results.count else { return }
        launchApp(results[selectedIndex])
    }

    private func launchApp(_ app: IndexedApp) {
        AppLauncher.launch(appURL: app.url)
        onDismiss()
    }
}

/// One horizontal result in the Quake strip; selected = white-on-magenta pill.
struct QuakeChip: View {
    let app: IndexedApp
    let query: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let nameText = isSelected
            ? BBS.matchedName(app.name, query: query, base: BBS.onMagenta, matched: BBS.onMagenta, dim: BBS.onMagenta.opacity(0.55))
            : BBS.matchedName(app.name, query: query, base: BBS.green, matched: BBS.amber, dim: BBS.green.opacity(0.5))
        return nameText
            .font(BBS.font(isSelected ? .bold : .regular))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? BBS.magenta : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }
}
