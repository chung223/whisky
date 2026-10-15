import Testing
@testable import WhiskyCore

@Suite("Change tracker")
struct ChangeTrackerTests {
    private let plain = [UInt8](repeating: 10, count: 256)
    private var badged: [UInt8] {
        var copy = plain
        for index in 0..<40 { copy[index] = 250 }
        return copy
    }

    private func rounds(_ tracker: inout ChangeTracker, _ looks: [[UInt8]], key: String = "app") -> [[String]] {
        looks.map { tracker.observe([(key, $0)]) }
    }

    @Test("A quiet item that changes is reported once")
    func quietThenChange() {
        var tracker = ChangeTracker()
        let results = rounds(&tracker, Array(repeating: plain, count: 6) + [badged, badged])
        let quiet = results.dropLast(2).allSatisfy { $0.isEmpty }
        #expect(quiet)
        #expect(results[6] == ["app"])
        #expect(results[7].isEmpty)
    }

    @Test("Nothing is reported while the tracker is still learning")
    func learning() {
        var tracker = ChangeTracker()
        let results = rounds(&tracker, [plain, plain, badged])
        let quiet = results.allSatisfy { $0.isEmpty }
        #expect(quiet)
    }

    @Test("A live readout that keeps changing is never reported")
    func live() {
        var tracker = ChangeTracker()
        let looks = (0..<12).map { $0.isMultiple(of: 2) ? plain : badged }
        let quiet = rounds(&tracker, looks).allSatisfy { $0.isEmpty }
        #expect(quiet)
    }

    @Test("Tiny differences don't count")
    func noise() {
        var tracker = ChangeTracker()
        var nearly = plain
        nearly[0] = 40
        let results = rounds(&tracker, Array(repeating: plain, count: 6) + [nearly])
        let quiet = results.allSatisfy { $0.isEmpty }
        #expect(quiet)
    }

    @Test("An item that left the menu bar starts over when it returns")
    func forgotten() {
        var tracker = ChangeTracker()
        _ = rounds(&tracker, Array(repeating: plain, count: 6))
        _ = tracker.observe([])
        #expect(tracker.observe([("app", badged)]).isEmpty)
    }
}
