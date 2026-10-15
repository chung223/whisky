import Foundation

/// A named arrangement of the menu bar (which items are shown, left to right) and when to switch to it.
public struct LayoutPreset: Codable, Equatable, Identifiable, Sendable {
    public enum Trigger: String, Codable, CaseIterable, Sendable {
        /// When no other preset's trigger holds (the everyday arrangement).
        case otherwise
        /// While an external display is connected.
        case externalDisplay
        /// While running on battery.
        case onBattery
        /// Only when picked by hand.
        case manual
    }

    public var id: UUID
    public var name: String
    /// Item keys, left to right.
    public var keys: [String]
    public var trigger: Trigger

    public init(id: UUID = UUID(), name: String, keys: [String], trigger: Trigger) {
        self.id = id
        self.name = name
        self.keys = keys
        self.trigger = trigger
    }
}

/// What the triggers look at.
public struct TriggerConditions: Equatable, Sendable {
    public var hasExternalDisplay: Bool
    public var onBattery: Bool

    public init(hasExternalDisplay: Bool, onBattery: Bool) {
        self.hasExternalDisplay = hasExternalDisplay
        self.onBattery = onBattery
    }
}

public enum PresetSelector {
    /// The preset the conditions call for: the first in the list whose trigger holds, else the "otherwise" one.
    /// Manual presets are only ever picked by hand. nil when there is nothing to pick.
    public static func select(_ presets: [LayoutPreset], for conditions: TriggerConditions) -> UUID? {
        if let preset = presets.first(where: { holds($0.trigger, conditions) }) { return preset.id }
        return presets.first { $0.trigger == .otherwise }?.id
    }

    static func holds(_ trigger: LayoutPreset.Trigger, _ conditions: TriggerConditions) -> Bool {
        switch trigger {
        case .externalDisplay: conditions.hasExternalDisplay
        case .onBattery: conditions.onBattery
        case .otherwise, .manual: false
        }
    }
}
