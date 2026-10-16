import Foundation

/// What this macOS lets Whisky do. On macOS 27 the menu bar is drawn by the system's MenuBarAgent as one window:
/// status items are no longer windows of their own, a wide spacer doesn't push items away, and synthetic ⌘-drags
/// don't move them (every menu bar manager stopped working on 27 beta 1). There, Whisky only opens items (mirrored
/// menus, AXPress) and moves nothing until it has a backend for 27.
enum PlatformSupport {
    /// Testing on 26: `defaults write com.chung.whisky simulateMacOS27 -bool true`, then relaunch.
    static var isSimulating27: Bool { UserDefaults.standard.bool(forKey: "simulateMacOS27") }

    static var movesItems: Bool {
        !isSimulating27 && ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27
    }

    static var versionName: String {
        isSimulating27 ? "macOS 27（模擬）" : "macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
    }
}
