import Foundation

/// Matches Bartender's layout entries to the items Whisky scanned.
///
/// Bartender stores each item as `<bundle ID>-<autosave name>` (e.g. `ru.keepcoder.Telegram-Item-0`,
/// `com.bjango.istatmenus-setapp.status-com.bjango.istatmenus.cpu`, `com.apple.controlcenter-WiFi`). Whisky only knows
/// the autosave name when it can read window titles (Screen Recording), so when the name is missing it falls back to
/// "the app has a single item" and then to the item's accessibility label.
public enum BartenderMatcher {
    public struct Candidate: Sendable, Equatable {
        public var key: String
        public var bundleID: String
        public var windowName: String?
        public var label: String

        public init(key: String, bundleID: String, windowName: String?, label: String) {
            self.key = key
            self.bundleID = bundleID
            self.windowName = windowName
            self.label = label
        }
    }

    /// For each Bartender entry, the key of the matched candidate, or nil. A candidate is used at most once.
    public static func match(_ entries: [String], candidates: [Candidate]) -> [String?] {
        var used = Set<String>()
        return entries.map { entry in
            // The longest bundle ID that prefixes the entry (bundle IDs can contain hyphens).
            let owners = candidates.filter { entry.hasPrefix($0.bundleID + "-") }
            guard let bundleID = owners.map(\.bundleID).max(by: { $0.count < $1.count }) else { return nil }
            let name = String(entry.dropFirst(bundleID.count + 1))
            let pool = candidates.filter { $0.bundleID == bundleID && !used.contains($0.key) }

            let match = pool.first { $0.windowName == name }
                ?? pool.first { $0.windowName == nil && $0.key == entry }
                ?? (candidates.filter { $0.bundleID == bundleID }.count == 1 ? pool.first : nil)
                ?? uniqueLabelMatch(name: name, in: pool)
            guard let match else { return nil }
            used.insert(match.key)
            return match.key
        }
    }

    /// The candidate whose label mentions the name's last component ("…istatmenus.cpu" → "CPU 44°", "WiFi" → "Wi‑Fi"),
    /// if exactly one does.
    private static func uniqueLabelMatch(name: String, in pool: [Candidate]) -> Candidate? {
        let lastComponent = name.split(whereSeparator: { $0 == "." || $0 == "-" }).last.map(String.init) ?? name
        let needle = normalized(lastComponent)
        guard needle.count >= 3 else { return nil }
        let hits = pool.filter { normalized($0.label).contains(needle) }
        return hits.count == 1 ? hits[0] : nil
    }

    static func normalized(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }
}
