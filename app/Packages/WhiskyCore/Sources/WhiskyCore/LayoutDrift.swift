/// Compares the run the user arranged with the run the menu bar shows now. Apps update, relaunch or change their
/// item's width, and macOS then puts the item back somewhere else; Whisky notices and offers to put it right (it never
/// moves anything on its own).
public enum LayoutDrift {
    public struct Difference: Equatable, Sendable {
        /// Arranged items that aren't in the run any more (behind the notch or pushed away).
        public var missing: [String]
        /// Items in the run the user didn't arrange there (a new app, or one that came back in a new place).
        public var extra: [String]
        /// The same items as arranged, in another order.
        public var reordered: Bool

        /// How many items are out of place, for a one-line summary.
        public var count: Int {
            let moved = missing.count + extra.count
            return moved > 0 ? moved : (reordered ? 1 : 0)
        }
    }

    /// - Parameters:
    ///   - saved: the run as the user arranged it, left to right (item keys).
    ///   - current: the run now, left to right.
    ///   - present: every item that is in the menu bar now (drawn or not). Arranged items whose app isn't running, or
    ///     that the app took out of the menu bar itself, can't be put back, so they don't count as missing.
    /// - Returns: nil when the run is as arranged.
    public static func compare(saved: [String], current: [String], present: Set<String>) -> Difference? {
        let expected = saved.filter { present.contains($0) }
        guard expected != current else { return nil }
        let currentSet = Set(current)
        let savedSet = Set(saved)
        let missing = expected.filter { !currentSet.contains($0) }
        let extra = current.filter { !savedSet.contains($0) }
        let kept = current.filter { savedSet.contains($0) }
        let reordered = missing.isEmpty && extra.isEmpty ? true : kept != expected.filter { currentSet.contains($0) }
        return Difference(missing: missing, extra: extra, reordered: reordered)
    }

    /// The arrangement to remember after the run changed: the run as it is now, plus arranged items that aren't in the
    /// menu bar at the moment (their app isn't running, or didn't answer yet), each kept right after the item it
    /// followed before. Forgetting them would drop them from the layout for good.
    public static func merge(current: [String], previous: [String], present: Set<String>) -> [String] {
        var merged = current
        for (index, key) in previous.enumerated() where !merged.contains(key) && !present.contains(key) {
            let before = previous[..<index].last { merged.contains($0) }
            let position = before.flatMap { merged.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            merged.insert(key, at: position)
        }
        return merged
    }
}
