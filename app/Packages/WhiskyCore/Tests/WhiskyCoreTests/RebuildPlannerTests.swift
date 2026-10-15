import Testing
@testable import WhiskyCore

/// Replays a plan: send-away items leave the run, pinned items are appended to its right end.
private func replay(_ plan: RebuildPlanner.Plan, on run: [UInt32]) -> [UInt32] {
    var order = run.filter { !plan.sendAway.contains($0) }
    for id in plan.pin {
        order.removeAll { $0 == id }
        order.append(id)
    }
    return order
}

@Suite("Rebuild planner")
struct RebuildPlannerTests {
    @Test("Nothing to do when the run already matches")
    func noOp() {
        #expect(RebuildPlanner.plan(run: [8, 1, 2, 3], wanted: [8, 1, 2, 3], hasSpacer: true).isEmpty)
    }

    @Test("Turning the spacer on: it goes first, then the shown items follow it")
    func enableSpacer() {
        // The spacer (8) was just created far away; the run is the shown items.
        let plan = RebuildPlanner.plan(run: [1, 2, 3], wanted: [8, 1, 2, 3], hasSpacer: true)
        #expect(plan.pin == [8, 1, 2, 3])
        #expect(replay(plan, on: [1, 2, 3]) == [8, 1, 2, 3])
    }

    @Test("Hiding one item keeps the start and rebuilds after it")
    func hideOne() {
        let run: [UInt32] = [8, 1, 2, 3]
        let plan = RebuildPlanner.plan(run: run, wanted: [8, 1, 3], hasSpacer: true)
        #expect(plan.sendAway == [2])
        #expect(plan.pin.isEmpty)
        #expect(replay(plan, on: run) == [8, 1, 3])
    }

    @Test("Adding an item appends it")
    func addOne() {
        let plan = RebuildPlanner.plan(run: [8, 1, 2], wanted: [8, 1, 2, 5], hasSpacer: true)
        #expect(plan == RebuildPlanner.Plan(sendAway: [], pin: [5]))
    }

    @Test("Reordering rebuilds from the first difference")
    func reorder() {
        let run: [UInt32] = [8, 1, 2, 3]
        let plan = RebuildPlanner.plan(run: run, wanted: [8, 3, 1, 2], hasSpacer: true)
        #expect(replay(plan, on: run) == [8, 3, 1, 2])
        #expect(plan.sendAway.isEmpty)
    }

    @Test("Without a spacer, unwanted items left of the kept start are sent away too")
    func noSpacer() {
        let run: [UInt32] = [3, 1, 2]
        let plan = RebuildPlanner.plan(run: run, wanted: [1, 2], hasSpacer: false)
        #expect(plan == RebuildPlanner.Plan(sendAway: [3], pin: []))
    }

    @Test("Items already in order after the kept start aren't moved")
    func partialOrder() {
        let plan = RebuildPlanner.plan(run: [8, 1, 3, 5, 4], wanted: [8, 1, 3, 4, 5], hasSpacer: true)
        #expect(plan == RebuildPlanner.Plan(sendAway: [], pin: [4, 5]))
    }

    @Test("The self-test regression: a spacer far left of many unwanted items is re-pinned, nothing else moves")
    func spacerFarLeft() {
        // The spacer (8) was created left of nine of the user's items; the test wants [8, T1, T2] = [8, 50, 51].
        let run: [UInt32] = [8, 1, 2, 3, 4, 5, 6, 7, 9, 10]
        let plan = RebuildPlanner.plan(run: run, wanted: [8, 50, 51], hasSpacer: true)
        #expect(plan == RebuildPlanner.Plan(sendAway: [], pin: [8, 50, 51]))
        let strict = RebuildPlanner.plan(run: run, wanted: [8, 50, 51], hasSpacer: true, allowSendAway: false)
        #expect(strict.sendAway.isEmpty)
    }

    @Test("Without send-aways, unwanted items in the run are left alone and end up left of the spacer")
    func strictHide() {
        let run: [UInt32] = [8, 1, 2, 3]
        let plan = RebuildPlanner.plan(run: run, wanted: [8, 1, 3], hasSpacer: true, allowSendAway: false)
        #expect(plan.sendAway.isEmpty)
        let result = replay(plan, on: run)
        #expect(Array(result.suffix(3)) == [8, 1, 3])
        #expect(result.firstIndex(of: 2)! < result.firstIndex(of: 8)!)
    }

    @Test("Any wanted run is reached from any start", arguments: [
        ([8, 1, 2, 3], [8, 2]),
        ([1, 8, 2, 3], [8, 3, 2]),
        ([3, 2, 1], [8, 1, 2, 3]),
        ([8, 1, 2, 3], [8]),
        ([8, 4, 1], [8, 1, 4, 6]),
    ] as [([UInt32], [UInt32])])
    func reachesWanted(run: [UInt32], wanted: [UInt32]) {
        let plan = RebuildPlanner.plan(run: run, wanted: wanted, hasSpacer: true)
        let result = replay(plan, on: run)
        // Unwanted items that were left of the kept start may remain left of it; the run's end must be `wanted`.
        #expect(Array(result.suffix(wanted.count)) == wanted)
        #expect(!result.dropLast(wanted.count).contains { wanted.contains($0) })
    }
}
