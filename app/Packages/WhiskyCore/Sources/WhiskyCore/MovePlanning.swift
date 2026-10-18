import CoreGraphics

/// Where a status item should end up, relative to another item's window.
public enum MoveDestination: Hashable, Sendable, CustomStringConvertible {
    case leftOf(UInt32)
    case rightOf(UInt32)

    public var targetWindowID: UInt32 {
        switch self {
        case .leftOf(let id), .rightOf(let id): id
        }
    }

    public var description: String {
        switch self {
        case .leftOf(let id): "left of \(id)"
        case .rightOf(let id): "right of \(id)"
        }
    }
}

/// Pure rules for moving status items with a synthetic ⌘-drag on macOS 26.
///
/// How the drag behaves (measured by Frost on macOS 26.6.2, docs/macos-behavior.md): the mouse-down lifts the item
/// out of the menu bar and the system reserves a slot for it at the mouse-down position; the items between its old
/// slot and that position slide over by its width. The drop slot is then decided by the mouse-up's raw coordinates
/// against the menu bar as it is at that moment.
public enum MovePlanning {
    /// Mouse-up point for a destination: just inside the target's left or right edge.
    public static func dropPoint(for destination: MoveDestination, targetFrame: CGRect) -> CGPoint {
        switch destination {
        case .leftOf: CGPoint(x: targetFrame.minX + 1, y: targetFrame.midY)
        case .rightOf: CGPoint(x: targetFrame.maxX - 1, y: targetFrame.midY)
        }
    }

    /// Whether a mouse-up at `point` keeps a dragged status item in the menu bar the drag started in (global top-left
    /// coordinates; `displays` are the displays' bounds). On the drag's own display only its menu bar band counts; off
    /// every display (far left, where items are sent away) only that band's height; another display never does. An item
    /// let go outside the menu bar is removed from it, and apps whose item terminates on removal quit.
    public static func isSafeDrop(_ point: CGPoint, startingAt start: CGPoint, displays: [CGRect], barHeight: CGFloat = 40) -> Bool {
        guard let home = displays.first(where: { $0.contains(start) }) else { return false }
        if let other = displays.first(where: { $0.contains(point) }), other != home { return false }
        return point.y >= home.minY && point.y < home.minY + barHeight
    }

    /// Whether the item already sits immediately beside the target, ordering every window by minX.
    public static func isSatisfied(itemID: UInt32, destination: MoveDestination, frames: [UInt32: CGRect]) -> Bool {
        let ordered = frames.sorted { ($0.value.minX, $0.key) < ($1.value.minX, $1.key) }.map(\.key)
        guard let index = ordered.firstIndex(of: itemID) else { return false }
        switch destination {
        case .leftOf(let target): return index + 1 < ordered.count && ordered[index + 1] == target
        case .rightOf(let target): return index > 0 && ordered[index - 1] == target
        }
    }

    /// Whether the target may slide while the item is lifted, so a mouse-up aimed at its earlier frame could land a
    /// slot off. Windows between the item's old slot and the mouse-down point (the anchor, Whisky's own icon) slide.
    /// Dropping right of the anchor while the item comes from its left is safe: that gap stays under the point.
    public static func targetMaySlide(itemFrame: CGRect, destination: MoveDestination, targetFrame: CGRect,
                                      anchorID: UInt32, anchorFrame: CGRect) -> Bool {
        if destination.targetWindowID == anchorID {
            if case .rightOf = destination, itemFrame.minX < anchorFrame.minX { return false }
            return true
        }
        let low = min(itemFrame.minX, anchorFrame.minX)
        let high = max(itemFrame.minX, anchorFrame.minX)
        return targetFrame.minX > low && targetFrame.minX < high
    }
}

/// Decides when the mouse-up of a synthetic ⌘-drag may be posted. Feed it a snapshot of the menu bar's windows
/// every few milliseconds while the synthetic button is down.
///
/// A mouse-up that arrives before the item has been lifted is ignored, and one aimed at a target that is still
/// sliding lands a slot off; so wait until the item has left its frame for a few snapshots and, when the target may
/// slide, until nothing else has moved for as many snapshots.
public struct DragReleaseGate: Sendable {
    public let itemID: UInt32
    public let originalFrame: CGRect
    public let waitsForStillness: Bool
    public let requiredSnapshots: Int

    public private(set) var isLifted = false
    private var snapshotsSinceLift = 0
    private var previousOthers: [UInt32: CGRect]?
    private var unchanged = 0

    public init(itemID: UInt32, originalFrame: CGRect, waitsForStillness: Bool, requiredSnapshots: Int = 3) {
        self.itemID = itemID
        self.originalFrame = originalFrame
        self.waitsForStillness = waitsForStillness
        self.requiredSnapshots = requiredSnapshots
    }

    /// Returns true once the mouse-up may be posted.
    public mutating func observe(_ frames: [UInt32: CGRect]) -> Bool {
        if !isLifted, let frame = frames[itemID], frame != originalFrame { isLifted = true }
        if isLifted { snapshotsSinceLift += 1 }
        var others = frames
        others[itemID] = nil
        unchanged = others == previousOthers ? unchanged + 1 : 0
        previousOthers = others
        guard isLifted, snapshotsSinceLift >= requiredSnapshots else { return false }
        return !waitsForStillness || unchanged + 1 >= requiredSnapshots
    }
}
