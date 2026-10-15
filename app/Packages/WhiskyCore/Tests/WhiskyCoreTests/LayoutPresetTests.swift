import Foundation
import Testing
@testable import WhiskyCore

@Suite("Layout presets")
struct LayoutPresetTests {
    private let everyday = LayoutPreset(name: "平常", keys: ["a", "b"], trigger: .otherwise)
    private let desk = LayoutPreset(name: "外接螢幕", keys: ["a", "b", "c", "d"], trigger: .externalDisplay)
    private let travel = LayoutPreset(name: "用電池", keys: ["a"], trigger: .onBattery)
    private let demo = LayoutPreset(name: "簡報", keys: [], trigger: .manual)

    @Test("Nothing special: the everyday preset")
    func otherwise() {
        let conditions = TriggerConditions(hasExternalDisplay: false, onBattery: false)
        #expect(PresetSelector.select([everyday, desk, travel, demo], for: conditions) == everyday.id)
    }

    @Test("A trigger that holds wins; the first in the list wins when several do")
    func triggers() {
        #expect(PresetSelector.select([everyday, desk, travel], for: TriggerConditions(hasExternalDisplay: true, onBattery: false)) == desk.id)
        #expect(PresetSelector.select([everyday, desk, travel], for: TriggerConditions(hasExternalDisplay: false, onBattery: true)) == travel.id)
        #expect(PresetSelector.select([everyday, travel, desk], for: TriggerConditions(hasExternalDisplay: true, onBattery: true)) == travel.id)
    }

    @Test("Manual presets are never picked automatically; no presets, no pick")
    func manual() {
        #expect(PresetSelector.select([demo], for: TriggerConditions(hasExternalDisplay: true, onBattery: true)) == nil)
        #expect(PresetSelector.select([], for: TriggerConditions(hasExternalDisplay: false, onBattery: false)) == nil)
    }

    @Test("Presets survive a round trip through JSON (how they are stored)")
    func codable() throws {
        let data = try JSONEncoder().encode([everyday, desk])
        #expect(try JSONDecoder().decode([LayoutPreset].self, from: data) == [everyday, desk])
    }
}
