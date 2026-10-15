import Foundation

/// Which items the user opens most, recent uses weighing more ("frecency"): each use counts 1, halving every
/// `halfLife`. Whisky Bar shows the top few first.
public enum UsageRanking {
    public static let halfLife: TimeInterval = 7 * 24 * 3600
    /// At most this many uses are kept per item.
    public static let keptUses = 20

    public static func score(_ uses: [Date], now: Date) -> Double {
        uses.reduce(0) { total, date in
            total + pow(0.5, max(0, now.timeIntervalSince(date)) / halfLife)
        }
    }

    /// The keys worth showing first, best first: at most `limit`, each with a score of at least `minimumScore` (one
    /// use within the last week or so), ties broken by the most recent use.
    public static func top(_ uses: [String: [Date]], among keys: Set<String>, now: Date, limit: Int = 6, minimumScore: Double = 0.5) -> [String] {
        uses.compactMap { key, dates -> (key: String, score: Double, last: Date)? in
            guard keys.contains(key), let last = dates.max() else { return nil }
            let value = score(dates, now: now)
            return value >= minimumScore ? (key, value, last) : nil
        }
        .sorted { $0.score != $1.score ? $0.score > $1.score : $0.last > $1.last }
        .prefix(limit)
        .map(\.key)
    }

    /// Adds a use, keeping the most recent `keptUses`.
    public static func recording(_ date: Date, in uses: [Date]) -> [Date] {
        Array((uses + [date]).sorted().suffix(keptUses))
    }
}
