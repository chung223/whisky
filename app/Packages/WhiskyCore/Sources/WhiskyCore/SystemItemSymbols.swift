/// SF Symbols that stand in for Apple's own menu bar items when Whisky Bar can't show their real image (without
/// Screen Recording). Their owners are background agents (Control Center, SystemUIServer, the text input agent) whose
/// app icon says nothing about the item.
public enum SystemItemSymbols {
    /// Item keys are `<bundle ID>-<autosave name>`; the part after the bundle ID names the module.
    private static let modules: [String: String] = [
        "WiFi": "wifi",
        "Battery": "battery.100percent",
        "Sound": "speaker.wave.2.fill",
        "FocusModes": "moon.fill",
        "Display": "sun.max.fill",
        "NowPlaying": "play.fill",
        "ScreenMirroring": "rectangle.on.rectangle",
        "KeyboardBrightness": "light.max",
        "UserSwitcher": "person.crop.circle",
        "AccessibilityShortcuts": "accessibility",
        "Hearing": "ear",
        "BentoBox": "switch.2",
        "Clock": "clock",
        "StageManager": "rectangle.split.3x1",
        "VPN": "network.badge.shield.half.filled",
        "Weather": "cloud.sun.fill",
        "Spotlight": "magnifyingglass",
        "TimeMachine": "clock.arrow.circlepath",
        "com.apple.menuextra.TimeMachine": "clock.arrow.circlepath",
        "com.apple.menuextra.vpn": "network.badge.shield.half.filled",
        "com.apple.menuextra.eject": "eject.fill",
        "com.apple.menuextra.volume": "speaker.wave.2.fill",
        "com.apple.menuextra.battery": "battery.100percent",
    ]

    /// Whole apps whose only item is well known.
    private static let bundles: [String: String] = [
        "com.apple.TextInputMenuAgent": "keyboard",
        "com.apple.weather.menu": "cloud.sun.fill",
        "com.apple.Spotlight": "magnifyingglass",
    ]

    /// The symbol for an item, or nil to use the owner's app icon.
    public static func symbol(key: String, bundleID: String?) -> String? {
        guard let bundleID, bundleID.hasPrefix("com.apple.") else { return nil }
        if let symbol = bundles[bundleID] { return symbol }
        guard key.hasPrefix(bundleID + "-") else { return nil }
        var module = String(key.dropFirst(bundleID.count + 1))
        // Control Center numbers repeated modules ("BentoBox-0").
        if let dash = module.lastIndex(of: "-"), module[module.index(after: dash)...].allSatisfy(\.isNumber) {
            module = String(module[..<dash])
        }
        return modules[module]
    }
}
