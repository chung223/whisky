import Foundation
import WhiskyCore

/// Shortcuts that open one item directly (its menu, popover or dropdown), without opening Whisky Bar first.
enum ItemHotKeyPreference {
    struct Assignment: Codable, Equatable {
        var shortcut: HotKeyShortcut
        /// The item's name when it was assigned, shown while its app isn't running.
        var name: String
    }

    private static let key = "itemHotKeys"

    /// By item key.
    static var all: [String: Assignment] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([String: Assignment].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: key) }
        }
    }
}
