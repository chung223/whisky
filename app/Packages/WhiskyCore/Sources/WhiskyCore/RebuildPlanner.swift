/// Arranges the visible run using only the two moves that proved reliable on a notched macOS 26 menu bar:
/// "put X immediately left of Whisky's icon" (the slot the window server reserves at the mouse-down) and "send X to
/// the far left". Nothing is ever dropped at the notch boundary, where macOS repacks items (see
/// wiki/concepts/platform-verification.md, 2026-10-15).
///
/// Each "pin" appends an item to the right end of the run, so pinning the wanted items in order rebuilds the run from
/// the left. Items already in place at the start of the run are kept; unwanted items that sit between them and the
/// icon are sent away first.
public enum RebuildPlanner {
    public struct Plan: Equatable, Sendable {
        /// Sent to the far left, in this order.
        public var sendAway: [UInt32]
        /// Put immediately left of the anchor, in this order.
        public var pin: [UInt32]

        public var isEmpty: Bool { sendAway.isEmpty && pin.isEmpty }
        public var count: Int { sendAway.count + pin.count }
    }

    /// - Parameters:
    ///   - run: the items between the hidden ones and the anchor, left to right, as the menu bar shows them now
    ///     (with a spacer: from the spacer up to the anchor; without one: the drawn items left of the anchor).
    ///   - wanted: the desired run, left to right (spacer first when there is one).
    ///   - hasSpacer: with a spacer, unwanted items only need to end up left of it, so they can be left alone and the
    ///     wanted items re-pinned instead; without one, every unwanted item in the run must be sent away.
    ///   - allowSendAway: false to never move an item that isn't wanted (the self-test promises to move only
    ///     Whisky's own items). Requires a spacer.
    public static func plan(run: [UInt32], wanted: [UInt32], hasSpacer: Bool, allowSendAway: Bool = true) -> Plan {
        let wantedSet = Set(wanted)
        if !hasSpacer {
            // Unwanted items would stay visible: send them all away, then fix the order of the rest.
            let sendAway = run.filter { !wantedSet.contains($0) }
            return Plan(sendAway: sendAway, pin: pins(run: run.filter { wantedSet.contains($0) }, wanted: wanted, allowingUnwantedAfterKept: false))
        }
        let repinOnly = Plan(sendAway: [], pin: pins(run: run, wanted: wanted, allowingUnwantedAfterKept: false))
        guard allowSendAway else { return repinOnly }
        // Or: send away the unwanted items sitting after the kept start, and keep more in place.
        let kept = keptPrefix(run: run, wanted: wanted, allowingUnwantedAfterKept: true)
        let after = kept.length > 0 ? Array(run[(kept.start + kept.length)...]) : run
        let rest = Set(wanted.dropFirst(kept.length))
        let sendAway = after.filter { !rest.contains($0) }
        let withSendAway = Plan(sendAway: sendAway, pin: pins(run: run.filter { !sendAway.contains($0) }, wanted: wanted, allowingUnwantedAfterKept: false))
        return withSendAway.count < repinOnly.count ? withSendAway : repinOnly
    }

    /// The pins that turn `run` into a run ending with `wanted`, given that pinning appends at the right end.
    private static func pins(run: [UInt32], wanted: [UInt32], allowingUnwantedAfterKept: Bool) -> [UInt32] {
        let kept = keptPrefix(run: run, wanted: wanted, allowingUnwantedAfterKept: allowingUnwantedAfterKept)
        // Nothing kept: unwanted items may sit anywhere among the wanted ones, so pin every wanted item in order.
        guard kept.length > 0 else { return wanted }
        let rest = Array(wanted.dropFirst(kept.length))
        let restSet = Set(rest)
        let after = Array(run[(kept.start + kept.length)...])
        let present = after.filter { restSet.contains($0) }
        var common = 0
        while common < present.count, present[common] == rest[common] { common += 1 }
        return Array(rest.dropFirst(common))
    }

    /// The longest start of `wanted` that sits contiguously, in order, in `run`. Unless `allowingUnwantedAfterKept`,
    /// everything after it in `run` must belong to the rest of `wanted` (an unwanted item there would stay in the run).
    private static func keptPrefix(run: [UInt32], wanted: [UInt32], allowingUnwantedAfterKept: Bool) -> (start: Int, length: Int) {
        for length in stride(from: wanted.count, through: 1, by: -1) {
            let prefix = Array(wanted.prefix(length))
            guard let start = run.firstIndex(of: prefix[0]), start + length <= run.count,
                  Array(run[start..<(start + length)]) == prefix else { continue }
            let rest = Set(wanted.dropFirst(length))
            if allowingUnwantedAfterKept || run[(start + length)...].allSatisfy({ rest.contains($0) }) {
                return (start, length)
            }
        }
        return (0, 0)
    }
}
