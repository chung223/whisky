import CoreGraphics
import Testing
@testable import WhiskyCore

@Suite("Autosave name inference")
struct AutosaveNameInferenceTests {
    /// Measured on iStat Menus (macOS 26.7): positions from its defaults, items' x from the menu bar.
    @Test("Pairs names with items by order")
    func iStatMenus() {
        let positions: [String: Double] = [
            "com.bjango.istatmenus.cpu": 428, "com.bjango.istatmenus.disks": 1411, "com.bjango.istatmenus.memory": 496,
            "com.bjango.istatmenus.sensors": 1005, "com.bjango.istatmenus.weather": 1195,
        ]
        // Scan order (by AX index): memory, cpu, disks, sensors, weather.
        let xs: [CGFloat] = [1005, 1073, 47, 438, 264]
        #expect(AutosaveNameInference.names(positions: positions, itemMinXs: xs) == [
            "com.bjango.istatmenus.memory", "com.bjango.istatmenus.cpu", "com.bjango.istatmenus.disks",
            "com.bjango.istatmenus.sensors", "com.bjango.istatmenus.weather",
        ])
    }

    @Test("Refuses to guess when counts differ or positions tie")
    func refuses() {
        #expect(AutosaveNameInference.names(positions: ["a": 1, "b": 2, "c": 3], itemMinXs: [10, 20]) == nil)
        #expect(AutosaveNameInference.names(positions: ["a": 5, "b": 5], itemMinXs: [10, 20]) == nil)
        #expect(AutosaveNameInference.names(positions: ["a": 5], itemMinXs: [10]) == nil)
    }

    @Test("Reads position keys from a defaults dictionary")
    func readsDefaults() {
        let defaults: [String: Any] = ["NSStatusItem Preferred Position cpu": 428, "NSStatusItem Preferred Position net": 12.5, "Other": 1]
        #expect(AutosaveNameInference.positions(fromDefaults: defaults) == ["cpu": 428, "net": 12.5])
    }
}
