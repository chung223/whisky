import Foundation
import Testing
@testable import WhiskyCore

@Suite("Usage ranking")
struct UsageRankingTests {
    private let now = Date(timeIntervalSince1970: 1_000_000_000)
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 24 * 3600) }

    @Test("A use halves in weight every week")
    func decay() {
        #expect(abs(UsageRanking.score([now], now: now) - 1) < 0.0001)
        #expect(abs(UsageRanking.score([daysAgo(7)], now: now) - 0.5) < 0.0001)
    }

    @Test("Frequent beats occasional; recent breaks ties; stale uses drop out")
    func ranking() {
        let uses: [String: [Date]] = [
            "istat": [daysAgo(1), daysAgo(2), daysAgo(3)],
            "keysmith": [daysAgo(0.5)],
            "digup": [daysAgo(0.1)],
            "old": [daysAgo(60)],
        ]
        let top = UsageRanking.top(uses, among: ["istat", "keysmith", "digup", "old"], now: now)
        #expect(top == ["istat", "digup", "keysmith"])
    }

    @Test("Items no longer in the menu bar are left out")
    func absent() {
        #expect(UsageRanking.top(["gone": [now]], among: ["here"], now: now).isEmpty)
    }

    @Test("Only the most recent uses are kept")
    func capped() {
        var uses: [Date] = []
        for day in 0..<30 { uses = UsageRanking.recording(daysAgo(Double(30 - day)), in: uses) }
        #expect(uses.count == UsageRanking.keptUses)
        #expect(uses.last == daysAgo(1))
    }
}
