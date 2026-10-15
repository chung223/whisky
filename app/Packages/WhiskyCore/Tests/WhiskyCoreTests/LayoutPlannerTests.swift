import CoreGraphics
import Testing
@testable import WhiskyCore

/// Replays a plan on an order, the way the menu bar would end up.
private func replay(_ moves: [LayoutMove], on current: [UInt32]) -> [UInt32] {
    var order = current
    for move in moves {
        order.removeAll { $0 == move.itemID }
        let index = order.firstIndex(of: move.destination.targetWindowID)!
        if case .leftOf = move.destination { order.insert(move.itemID, at: index) } else { order.insert(move.itemID, at: index + 1) }
    }
    return order
}

@Suite("Layout planner")
struct LayoutPlannerTests {
    // Behind the notch: 1 2 3; shown: 4 5 6; Whisky's icon 9; Control Center and the clock 20 21.
    let current: [UInt32] = [1, 2, 3, 4, 5, 6, 9, 20, 21]
    let shown: Set<UInt32> = [4, 5, 6, 9, 20, 21]

    @Test("Nothing to do when the layout already matches")
    func noOp() {
        #expect(LayoutPlanner.plan(current: current, anchor: 9, visible: [4, 5, 6], shown: shown).isEmpty)
    }

    @Test("Pinning one more item places it next to the anchor")
    func pinOne() {
        let moves = LayoutPlanner.plan(current: current, anchor: 9, visible: [4, 5, 6, 2], shown: shown)
        #expect(moves == [LayoutMove(itemID: 2, destination: .leftOf(9))])
    }

    @Test("Reordering and hiding end with exactly the wanted run left of the anchor")
    func reorderAndHide() {
        let moves = LayoutPlanner.plan(current: current, anchor: 9, visible: [6, 1, 4], shown: shown)
        let result = replay(moves, on: current)
        let anchorIndex = result.firstIndex(of: 9)!
        #expect(Array(result[(anchorIndex - 3)..<anchorIndex]) == [6, 1, 4])
        // 5 was shown and is no longer wanted: it went to the far left.
        #expect(result.first == 5)
        // Nothing right of the anchor moved.
        #expect(Array(result[(anchorIndex + 1)...]) == [20, 21])
    }

    @Test("Items right of the anchor and unknown items are ignored")
    func ignored() {
        let moves = LayoutPlanner.plan(current: current, anchor: 9, visible: [20, 99, 4, 5, 6], shown: shown)
        #expect(!moves.contains { $0.itemID == 99 })
        let result = replay(moves, on: current)
        #expect(result.last == 21)
    }

    @Test("With a spacer, unwanted items end up left of it without being moved one by one")
    func spacer() {
        // Spacer 8 sits left of the shown run 4 5 6.
        let current: [UInt32] = [1, 2, 3, 8, 4, 5, 6, 9, 20, 21]
        let moves = LayoutPlanner.plan(current: current, anchor: 9, visible: [6, 2], shown: shown, spacer: 8)
        let result = replay(moves, on: current)
        let anchorIndex = result.firstIndex(of: 9)!
        #expect(Array(result[(anchorIndex - 3)..<anchorIndex]) == [8, 6, 2])
        // 4 and 5 were not moved individually; they are simply left of the spacer now.
        #expect(!moves.contains { $0.itemID == 4 || $0.itemID == 5 })
        #expect(result.firstIndex(of: 4)! < result.firstIndex(of: 8)!)
    }

    @Test("A spacer already in place costs nothing")
    func spacerInPlace() {
        let current: [UInt32] = [1, 2, 3, 8, 4, 5, 6, 9, 20, 21]
        #expect(LayoutPlanner.plan(current: current, anchor: 9, visible: [4, 5, 6], shown: shown, spacer: 8).isEmpty)
    }

    @Test("Overflow counts the leftmost items that don't fit")
    func overflow() {
        #expect(LayoutPlanner.overflowCount(widths: [84, 35, 35, 35], capacity: 120) == 1)
        #expect(LayoutPlanner.overflowCount(widths: [84, 35, 35, 35], capacity: 500) == 0)
        #expect(LayoutPlanner.overflowCount(widths: [84, 35], capacity: 10) == 2)
    }
}
