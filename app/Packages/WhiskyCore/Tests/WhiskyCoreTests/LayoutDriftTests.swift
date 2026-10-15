import Testing
@testable import WhiskyCore

@Suite("Layout drift")
struct LayoutDriftTests {
    @Test("No difference when the run is as arranged")
    func same() {
        #expect(LayoutDrift.compare(saved: ["a", "b", "c"], current: ["a", "b", "c"], present: ["a", "b", "c", "x"]) == nil)
    }

    @Test("An arranged item whose app isn't running doesn't count")
    func notRunning() {
        #expect(LayoutDrift.compare(saved: ["a", "b", "c"], current: ["a", "c"], present: ["a", "c"]) == nil)
    }

    @Test("An arranged item that fell behind the notch is missing")
    func missing() {
        let difference = LayoutDrift.compare(saved: ["a", "b", "c"], current: ["a", "c"], present: ["a", "b", "c"])
        #expect(difference?.missing == ["b"])
        #expect(difference?.extra == [])
        #expect(difference?.reordered == false)
        #expect(difference?.count == 1)
    }

    @Test("An item that came back in the run is extra")
    func extra() {
        let difference = LayoutDrift.compare(saved: ["a", "b"], current: ["x", "a", "b"], present: ["a", "b", "x"])
        #expect(difference?.extra == ["x"])
        #expect(difference?.missing == [])
        #expect(difference?.count == 1)
    }

    @Test("Same items in another order")
    func reordered() {
        let difference = LayoutDrift.compare(saved: ["a", "b", "c"], current: ["b", "a", "c"], present: ["a", "b", "c"])
        #expect(difference == LayoutDrift.Difference(missing: [], extra: [], reordered: true))
        #expect(difference?.count == 1)
    }

    @Test("One item swapped for another")
    func swapped() {
        // AlDente grew and pushed Surge behind the notch; Plaud took its place.
        let difference = LayoutDrift.compare(saved: ["surge", "usb", "aldente"], current: ["plaud", "usb", "aldente"],
                                             present: ["surge", "usb", "aldente", "plaud"])
        #expect(difference?.missing == ["surge"])
        #expect(difference?.extra == ["plaud"])
        #expect(difference?.reordered == false)
        #expect(difference?.count == 2)
    }
}
