# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build
xcodebuild -project TriggerHappy.xcodeproj -scheme TriggerHappy -configuration Debug build

# Copy built app to project root
cp -R ~/Library/Developer/Xcode/DerivedData/TriggerHappy-*/Build/Products/Debug/TriggerHappy.app ./TriggerHappy.app

# Run
open ./TriggerHappy.app
```

Pure Xcode project (no SPM, no CocoaPods). macOS 14.0+, Swift 5.0, non-sandboxed, LSUIElement (no dock icon).

## Architecture

### Dual Hotkey Systems

The app has **two separate Carbon event handler pipelines**:

1. **User hotkeys** (`HotkeyManager`) — bindings the user creates (e.g., Ctrl+Shift+F opens Firefox). Each enabled binding gets a `RegisterEventHotKey` call. Managed via `BindingStore` which persists to UserDefaults and triggers `reregisterAll()` on any change.

2. **System hotkeys** (`AppDelegate`) — built-in features with reserved IDs (9999=App Launcher, 9998=Cheat Sheet, 9997=Clipboard History). Single shared Carbon callback dispatches by ID. These are stored in separate UserDefaults keys and registered independently.

Both use `Carbon.HIToolbox` `RegisterEventHotKey`/`UnregisterEventHotKey` — not `CGEventTap` — so no Accessibility/Input Monitoring permission is needed for hotkey registration.

### Floating Panel Pattern

Three features (App Launcher, Cheat Sheet, Clipboard History) follow an identical pattern:
- `*WindowController` creates a borderless `KeyablePanel` (NSPanel subclass that overrides `canBecomeKey`/`canBecomeMain`)
- Hosts a SwiftUI view via `NSHostingView`
- Positions on the screen where the mouse cursor is
- `toggle()` shows or hides; always recreates the window fresh on show

### Data Flow

`BindingStore` (@Observable) is the single source of truth for user hotkeys. It persists to UserDefaults as JSON. When bindings change, it fires `onBindingsChanged` which triggers `HotkeyManager.reregisterAll()` — this unregisters all Carbon hotkeys and re-registers only enabled ones.

`ClipboardStore` polls `NSPasteboard.general.changeCount` every 0.5s. It deduplicates consecutive identical copies and skips password manager entries (`org.nspasteboard.ConcealedType`).

### Key Recorder

`KeyRecorderView` uses `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` to capture key combinations inside the popover. It validates against: hard-reserved combos (Cmd+Tab), known system conflicts (warns but allows), and existing user bindings (blocks). The monitor is installed on recording start and removed on stop.

### Menu Bar UI

The app uses `NSPopover` with `.applicationDefined` behavior (not `.transient`) attached to an `NSStatusItem`. A global click monitor closes the popover on outside clicks but ignores NSOpenPanel clicks. The popover never auto-dismisses, which allows the key recorder and inline app search to work.

### App Indexer

Recursively scans `/Applications`, `/System/Applications`, `/System/Library/CoreServices`, and `~/Applications` to depth 2. Uses a custom fuzzy scoring algorithm with bonuses for prefix match, consecutive characters, and word-boundary matches.
