/// Notices when a hidden item changes how it looks (a badge appears, a backup starts), so Whisky can point it out at
/// the notch. Items that change all the time (a CPU percentage, network speed, a temperature) are live readouts, not
/// news: an item is only reported when it had looked the same for `quietRounds` rounds before.
public struct ChangeTracker: Sendable {
    /// Fingerprints closer than this count as the same look (anti-aliasing and tiny shifts).
    public static let threshold = 0.035
    public static let quietRounds = 5

    private var last: [String: [UInt8]] = [:]
    /// For each item, whether it changed in each of the recent rounds (newest last).
    private var history: [String: [Bool]] = [:]

    public init() {}

    /// Records one round of fingerprints and returns the items that just changed after being quiet, in the order
    /// given. Items missing from this round are forgotten (they may have left the menu bar).
    public mutating func observe(_ round: [(key: String, fingerprint: [UInt8])]) -> [String] {
        var reported: [String] = []
        var seen = Set<String>()
        for (key, fingerprint) in round {
            seen.insert(key)
            defer { last[key] = fingerprint }
            guard let previous = last[key] else {
                history[key] = []
                continue
            }
            let changed = GlyphAnalysis.difference(previous, fingerprint) > Self.threshold
            let past = history[key] ?? []
            if changed, past.count >= Self.quietRounds, !past.suffix(Self.quietRounds).contains(true) {
                reported.append(key)
            }
            history[key] = Array((past + [changed]).suffix(Self.quietRounds + 1))
        }
        for key in last.keys where !seen.contains(key) {
            last[key] = nil
            history[key] = nil
        }
        return reported
    }
}
