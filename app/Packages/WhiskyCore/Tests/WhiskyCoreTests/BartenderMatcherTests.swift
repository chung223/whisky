import Testing
@testable import WhiskyCore

@Suite("Bartender matcher")
struct BartenderMatcherTests {
    private typealias C = BartenderMatcher.Candidate

    @Test("Exact autosave names win when window titles are readable")
    func byWindowName() {
        let candidates = [
            C(key: "a", bundleID: "com.bjango.istatmenus-setapp.status", windowName: "com.bjango.istatmenus.cpu", label: "x"),
            C(key: "b", bundleID: "com.bjango.istatmenus-setapp.status", windowName: "com.bjango.istatmenus.disks", label: "y"),
        ]
        let result = BartenderMatcher.match(["com.bjango.istatmenus-setapp.status-com.bjango.istatmenus.disks"], candidates: candidates)
        #expect(result == ["b"])
    }

    @Test("A single-item app matches without a window name")
    func singleItem() {
        let candidates = [C(key: "ru.keepcoder.Telegram-Item-0", bundleID: "ru.keepcoder.Telegram", windowName: nil, label: "Telegram")]
        #expect(BartenderMatcher.match(["ru.keepcoder.Telegram-Item-0"], candidates: candidates) == ["ru.keepcoder.Telegram-Item-0"])
    }

    @Test("Several items of one app fall back to their labels")
    func byLabel() {
        let bundle = "com.bjango.istatmenus-setapp.status"
        let candidates = [
            C(key: "k0", bundleID: bundle, windowName: nil, label: "CPU 44°"),
            C(key: "k1", bundleID: bundle, windowName: nil, label: "Memory 61%"),
            C(key: "k2", bundleID: bundle, windowName: nil, label: "Macintosh HD. 40.8 GB available"),
        ]
        let entries = ["\(bundle)-com.bjango.istatmenus.memory", "\(bundle)-com.bjango.istatmenus.cpu", "\(bundle)-com.bjango.istatmenus.disks"]
        // "disks" isn't in any label, so it stays unmatched rather than guessed.
        #expect(BartenderMatcher.match(entries, candidates: candidates) == ["k1", "k0", nil])
    }

    @Test("Control Center's Wi-Fi matches its label despite the different spelling")
    func wifi() {
        let candidates = [
            C(key: "cc0", bundleID: "com.apple.controlcenter", windowName: nil, label: "時鐘"),
            C(key: "cc1", bundleID: "com.apple.controlcenter", windowName: nil, label: "Wi‑Fi"),
        ]
        #expect(BartenderMatcher.match(["com.apple.controlcenter-WiFi"], candidates: candidates) == ["cc1"])
    }

    @Test("Unknown apps, Bartender's own entries and reused candidates give nil")
    func unmatched() {
        let candidates = [C(key: "s", bundleID: "com.nssurge.surge-mac", windowName: nil, label: "Surge")]
        let result = BartenderMatcher.match(
            ["special.AllOtherItems", "com.surteesstudios.Bartender-setapp-statusItem", "com.nssurge.surge-mac-Item-0", "com.nssurge.surge-mac-Item-1"],
            candidates: candidates
        )
        #expect(result == [nil, nil, "s", nil])
    }
}
