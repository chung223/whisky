import CoreGraphics
import Testing
@testable import WhiskyCore

private func frame(_ x: CGFloat, _ width: CGFloat = 34) -> CGRect {
    CGRect(x: x, y: 0, width: width, height: 33)
}

@Suite("Move planning")
struct MovePlanningTests {
    @Test("Drop points sit just inside the target's edges")
    func dropPoints() {
        let target = frame(1000, 40)
        #expect(MovePlanning.dropPoint(for: .leftOf(7), targetFrame: target) == CGPoint(x: 1001, y: 16.5))
        #expect(MovePlanning.dropPoint(for: .rightOf(7), targetFrame: target) == CGPoint(x: 1039, y: 16.5))
        // Off-screen targets keep their raw coordinates.
        #expect(MovePlanning.dropPoint(for: .leftOf(7), targetFrame: frame(-4000)).x == -3999)
    }

    @Test("Satisfied only when immediately beside the target")
    func satisfied() {
        let frames: [UInt32: CGRect] = [1: frame(100), 2: frame(134), 3: frame(168)]
        #expect(MovePlanning.isSatisfied(itemID: 1, destination: .leftOf(2), frames: frames))
        #expect(MovePlanning.isSatisfied(itemID: 3, destination: .rightOf(2), frames: frames))
        #expect(!MovePlanning.isSatisfied(itemID: 1, destination: .leftOf(3), frames: frames))
        #expect(!MovePlanning.isSatisfied(itemID: 3, destination: .leftOf(1), frames: frames))
        #expect(!MovePlanning.isSatisfied(itemID: 9, destination: .leftOf(1), frames: frames))
    }

    @Test("Pinning next to the anchor from behind the notch: the target is the anchor and may slide")
    func pinSlides() {
        #expect(MovePlanning.targetMaySlide(itemFrame: frame(864), destination: .leftOf(5), targetFrame: frame(1231),
                                            anchorID: 5, anchorFrame: frame(1231)))
        #expect(!MovePlanning.targetMaySlide(itemFrame: frame(864), destination: .rightOf(5), targetFrame: frame(1231),
                                             anchorID: 5, anchorFrame: frame(1231)))
    }

    @Test("Sending an item to the far left: the leftmost target doesn't slide")
    func unpinDoesNotSlide() {
        #expect(!MovePlanning.targetMaySlide(itemFrame: frame(1093), destination: .leftOf(9), targetFrame: frame(67),
                                             anchorID: 5, anchorFrame: frame(1231)))
    }

    @Test("A target between the item and the anchor slides")
    func betweenSlides() {
        #expect(MovePlanning.targetMaySlide(itemFrame: frame(300), destination: .rightOf(9), targetFrame: frame(900),
                                            anchorID: 5, anchorFrame: frame(1231)))
    }
}

@Suite("Drag release gate")
struct DragReleaseGateTests {
    /// Feeds snapshots in order and returns what the gate answered for each.
    private func answers(_ gate: inout DragReleaseGate, _ snapshots: [[UInt32: CGRect]]) -> [Bool] {
        snapshots.map { gate.observe($0) }
    }

    @Test("Waits for the lift plus a few snapshots")
    func waitsForLift() {
        var gate = DragReleaseGate(itemID: 1, originalFrame: frame(864), waitsForStillness: false)
        let before: [UInt32: CGRect] = [1: frame(864), 2: frame(1231)]
        let lifted: [UInt32: CGRect] = [1: CGRect(x: 1240, y: 8, width: 34, height: 33), 2: frame(1231)]
        let result = answers(&gate, [before, before, lifted, lifted, lifted])
        #expect(result == [false, false, false, false, true])
        #expect(gate.isLifted)
    }

    @Test("When the target may slide, also waits for the others to stop moving")
    func waitsForStillness() {
        var gate = DragReleaseGate(itemID: 1, originalFrame: frame(864), waitsForStillness: true)
        let lifted = CGRect(x: 1240, y: 8, width: 34, height: 33)
        let result = answers(&gate, [1000, 990, 980, 966, 966, 966].map { [1: lifted, 2: frame($0)] })
        #expect(result == [false, false, false, false, false, true])
    }
}
