import CoreGraphics

public struct LayoutMove: Equatable, Sendable, CustomStringConvertible {
    public var itemID: UInt32
    public var destination: MoveDestination

    public init(itemID: UInt32, destination: MoveDestination) {
        self.itemID = itemID
        self.destination = destination
    }

    public var description: String { "\(itemID) \(destination)" }
}

/// Turns "these items should be visible, in this order" into single ⌘-drag moves, each relative to an item whose
/// position is already settled, so every move can be verified on its own.
///
/// The visible part of the menu bar is the run of items just left of Whisky's icon (the anchor); everything further
/// left ends up behind the notch, reachable from Whisky Bar. Items right of the anchor (Control Center, the clock)
/// are never touched.
public enum LayoutPlanner {
    /// - Parameters:
    ///   - current: window IDs in the menu bar row, left to right, including the anchor.
    ///   - anchor: Whisky's icon.
    ///   - visible: the items that should end up immediately left of the anchor, left to right.
    ///   - shown: items macOS draws now; without a spacer, those left of the anchor and not in `visible` are sent to the
    ///     far left first.
    ///   - spacer: Whisky's spacer item. When given, it is placed immediately left of the visible run, so everything
    ///     else ends up left of it (behind the notch) without being moved one by one.
    public static func plan(current: [UInt32], anchor: UInt32, visible: [UInt32], shown: Set<UInt32>,
                            spacer: UInt32? = nil) -> [LayoutMove] {
        guard current.contains(anchor) else { return [] }
        var wanted = visible.filter { $0 != anchor && $0 != spacer && current.contains($0) }
        if let spacer, current.contains(spacer) { wanted.insert(spacer, at: 0) }
        var order = current
        var moves: [LayoutMove] = []

        func perform(_ move: LayoutMove) {
            order.removeAll { $0 == move.itemID }
            guard let targetIndex = order.firstIndex(of: move.destination.targetWindowID) else { return }
            switch move.destination {
            case .leftOf: order.insert(move.itemID, at: targetIndex)
            case .rightOf: order.insert(move.itemID, at: targetIndex + 1)
            }
            moves.append(move)
        }

        // 1. Without a spacer, send away what is shown now but not wanted, so the wanted items don't have to fight for
        //    room. With one, step 2 leaves every unwanted item left of the spacer anyway.
        let wantedSet = Set(wanted)
        let anchorIndex = order.firstIndex(of: anchor)!
        let unwanted = spacer == nil ? order[..<anchorIndex].filter { shown.contains($0) && !wantedSet.contains($0) } : []
        for id in unwanted {
            guard order.first != id, let leftmost = order.first(where: { $0 != id }) else { continue }
            perform(LayoutMove(itemID: id, destination: .leftOf(leftmost)))
        }

        // 2. Place the wanted items right to left, each immediately left of the one placed before it.
        var target = anchor
        for id in wanted.reversed() {
            if let index = order.firstIndex(of: id), let targetIndex = order.firstIndex(of: target), index + 1 == targetIndex {
                // Already in place.
            } else {
                perform(LayoutMove(itemID: id, destination: .leftOf(target)))
            }
            target = id
        }
        return moves
    }

    /// How many of the wanted items, counted from the left, won't fit in `capacity` points (they end up behind the
    /// notch). `widths` are the wanted items' widths, left to right.
    public static func overflowCount(widths: [CGFloat], capacity: CGFloat) -> Int {
        var used: CGFloat = 0
        var fitting = 0
        for width in widths.reversed() {
            guard used + width <= capacity + 0.5 else { break }
            used += width
            fitting += 1
        }
        return widths.count - fitting
    }
}
