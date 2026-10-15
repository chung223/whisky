/// Apple's own menu bar items: an SF Symbol to stand in when Whisky can't show the real image (without Screen
/// Recording), and a readable name. Their owners are background agents (Control Center, SystemUIServer, the text
/// input agent) whose app icon and name say nothing about the item.
public enum SystemItemSymbols {
    private struct Entry {
        let symbol: String?
        let name: String
    }

    /// Item keys are `<bundle ID>-<autosave name>`; the part after the bundle ID names the module.
    private static let modules: [String: Entry] = [
        "WiFi": Entry(symbol: "wifi", name: "Wi-Fi"),
        "Bluetooth": Entry(symbol: nil, name: "藍牙"),
        "Battery": Entry(symbol: "battery.100percent", name: "電池"),
        "Sound": Entry(symbol: "speaker.wave.2.fill", name: "聲音"),
        "FocusModes": Entry(symbol: "moon.fill", name: "專注模式"),
        "Display": Entry(symbol: "sun.max.fill", name: "顯示器"),
        "NowPlaying": Entry(symbol: "play.fill", name: "正在播放"),
        "ScreenMirroring": Entry(symbol: "rectangle.on.rectangle", name: "螢幕鏡像輸出"),
        "KeyboardBrightness": Entry(symbol: "light.max", name: "鍵盤亮度"),
        "UserSwitcher": Entry(symbol: "person.crop.circle", name: "快速切換使用者"),
        "AccessibilityShortcuts": Entry(symbol: "accessibility", name: "輔助使用快速鍵"),
        "Hearing": Entry(symbol: "ear", name: "聽力"),
        "BentoBox": Entry(symbol: "switch.2", name: "控制中心"),
        "Clock": Entry(symbol: "clock", name: "時鐘"),
        "StageManager": Entry(symbol: "rectangle.split.3x1", name: "幕前調度"),
        "AudioVideoModule": Entry(symbol: "mic.fill", name: "麥克風與相機"),
        "VPN": Entry(symbol: "network.badge.shield.half.filled", name: "VPN"),
        "Weather": Entry(symbol: "cloud.sun.fill", name: "天氣"),
        "Spotlight": Entry(symbol: "magnifyingglass", name: "Spotlight"),
        "Shortcuts": Entry(symbol: nil, name: "捷徑"),
        "Siri": Entry(symbol: nil, name: "Siri"),
        "TimeMachine": Entry(symbol: "clock.arrow.circlepath", name: "時光機"),
        "com.apple.menuextra.TimeMachine": Entry(symbol: "clock.arrow.circlepath", name: "時光機"),
        "com.apple.menuextra.vpn": Entry(symbol: "network.badge.shield.half.filled", name: "VPN"),
        "com.apple.menuextra.eject": Entry(symbol: "eject.fill", name: "退出"),
        "com.apple.menuextra.volume": Entry(symbol: "speaker.wave.2.fill", name: "聲音"),
        "com.apple.menuextra.battery": Entry(symbol: "battery.100percent", name: "電池"),
    ]

    /// Whole apps whose only item is well known.
    private static let bundles: [String: Entry] = [
        "com.apple.TextInputMenuAgent": Entry(symbol: "keyboard", name: "輸入法"),
        "com.apple.weather.menu": Entry(symbol: "cloud.sun.fill", name: "天氣"),
        "com.apple.Spotlight": Entry(symbol: "magnifyingglass", name: "Spotlight"),
    ]

    /// The symbol for an item, or nil to use the owner's app icon.
    public static func symbol(key: String, bundleID: String?) -> String? {
        entry(key: key, bundleID: bundleID)?.symbol
    }

    /// A readable name for one of Apple's items, or nil when it isn't known.
    public static func name(key: String, bundleID: String?) -> String? {
        entry(key: key, bundleID: bundleID)?.name
    }

    private static func entry(key: String, bundleID: String?) -> Entry? {
        guard let bundleID, bundleID.hasPrefix("com.apple.") else { return nil }
        if let entry = bundles[bundleID] { return entry }
        guard key.hasPrefix(bundleID + "-") else { return nil }
        var module = String(key.dropFirst(bundleID.count + 1))
        // Control Center numbers repeated modules ("BentoBox-0").
        if let dash = module.lastIndex(of: "-"), module[module.index(after: dash)...].allSatisfy(\.isNumber) {
            module = String(module[..<dash])
        }
        return modules[module]
    }
}
