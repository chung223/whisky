import CoreGraphics

/// Recovers status items' autosave names without Screen Recording.
///
/// AppKit keeps each item's position in its app's defaults as `NSStatusItem Preferred Position <autosave name>`
/// (distance from the right end, larger is further left) and rewrites it whenever the item moves. So for an app with
/// several items, sorting those names by position and the items by x pairs them up. Measured on iStat Menus: five keys,
/// five items, same order.
public enum AutosaveNameInference {
    public static let positionKeyPrefix = "NSStatusItem Preferred Position "

    /// Names for `itemMinXs` (in the given order), or nil when the counts differ or two positions tie: then guessing
    /// could swap items, so it doesn't.
    public static func names(positions: [String: Double], itemMinXs: [CGFloat]) -> [String]? {
        guard positions.count == itemMinXs.count, positions.count > 1 else { return nil }
        let values = positions.values.sorted()
        guard zip(values, values.dropFirst()).allSatisfy({ $0 != $1 }) else { return nil }
        let namesLeftToRight = positions.sorted { $0.value > $1.value }.map(\.key)
        let order = itemMinXs.indices.sorted { itemMinXs[$0] < itemMinXs[$1] }
        var result = [String](repeating: "", count: itemMinXs.count)
        for (rank, index) in order.enumerated() { result[index] = namesLeftToRight[rank] }
        return result
    }

    /// The `[name: position]` pairs among an app's defaults keys.
    public static func positions(fromDefaults defaults: [String: Any]) -> [String: Double] {
        var positions: [String: Double] = [:]
        for (key, value) in defaults where key.hasPrefix(positionKeyPrefix) {
            let name = String(key.dropFirst(positionKeyPrefix.count))
            if let number = value as? Double { positions[name] = number } else if let number = value as? Int { positions[name] = Double(number) }
        }
        return positions
    }
}
