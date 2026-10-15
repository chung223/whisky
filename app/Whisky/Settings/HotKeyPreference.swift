import Foundation
import WhiskyCore

/// The shortcut that opens Whisky Bar: ⌃⌥⌘W until the user records another one or clears it.
enum HotKeyPreference {
    private static let shortcutKey = "hotKey"
    private static let disabledKey = "hotKeyDisabled"

    /// nil: no shortcut.
    static var shortcut: HotKeyShortcut? {
        get {
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: disabledKey) { return nil }
            guard let data = defaults.data(forKey: shortcutKey),
                  let shortcut = try? JSONDecoder().decode(HotKeyShortcut.self, from: data)
            else { return .default }
            return shortcut
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue == nil, forKey: disabledKey)
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: shortcutKey)
            }
        }
    }
}
