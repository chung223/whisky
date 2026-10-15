import AppKit
import IOKit.ps
import WhiskyCore

/// Layout presets ("everyday", "at the desk", "on battery"): each a remembered arrangement plus when to switch to it.
/// Watches the displays and the power source; when the conditions call for another preset, it becomes the active one
/// and `onSwitch` puts its arrangement in place (once the user is idle). Arranging while a preset is active updates it.
@MainActor
final class PresetManager {
    private static let presetsKey = "layoutPresets"
    private static let activeKey = "activePreset"

    /// The conditions changed (or the user picked one): put this arrangement in place.
    var onSwitch: ((LayoutPreset) -> Void)?

    private var lastConditions: TriggerConditions?
    private var pendingEvaluation: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?
    private var powerSource: CFRunLoopSource?

    private(set) var presets: [LayoutPreset] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.presetsKey),
                  let presets = try? JSONDecoder().decode([LayoutPreset].self, from: data) else { return [] }
            return presets
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: Self.presetsKey) }
        }
    }

    private(set) var activeID: UUID? {
        get { UserDefaults.standard.string(forKey: Self.activeKey).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: Self.activeKey) }
    }

    var active: LayoutPreset? { presets.first { $0.id == activeID } }

    // MARK: - Watching

    func start() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluateSoon() }
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let manager = Unmanaged<PresetManager>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { manager.evaluateSoon() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        lastConditions = Self.currentConditions()
    }

    /// At launch: the preset the conditions call for now (it may differ from the one active when Whisky quit), made
    /// active without switching: the launch check puts its arrangement in place.
    func selectForLaunch() -> LayoutPreset? {
        let conditions = Self.currentConditions()
        lastConditions = conditions
        guard let id = PresetSelector.select(presets, for: conditions), let preset = presets.first(where: { $0.id == id }) else { return active }
        if id != activeID { Log.write("presets: at launch \(Self.describe(conditions)) → \(preset.name)") }
        activeID = id
        return preset
    }

    /// Displays come and go in bursts of notifications: decide once things have settled.
    private func evaluateSoon() {
        pendingEvaluation?.cancel()
        pendingEvaluation = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }

    private func evaluate() {
        let conditions = Self.currentConditions()
        guard conditions != lastConditions else { return }
        lastConditions = conditions
        guard let id = PresetSelector.select(presets, for: conditions), id != activeID,
              let preset = presets.first(where: { $0.id == id }) else { return }
        Log.write("presets: \(Self.describe(conditions)) → \(preset.name)")
        activeID = id
        onSwitch?(preset)
    }

    static func currentConditions() -> TriggerConditions {
        let external = NSScreen.screens.contains { screen in
            let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            return CGDisplayIsBuiltin(number) == 0
        }
        let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let source = info.flatMap { IOPSGetProvidingPowerSourceType($0)?.takeUnretainedValue() as String? }
        return TriggerConditions(hasExternalDisplay: external, onBattery: source == kIOPMBatteryPowerKey)
    }

    private static func describe(_ conditions: TriggerConditions) -> String {
        "\(conditions.hasExternalDisplay ? "external display" : "built-in only"), \(conditions.onBattery ? "battery" : "power adapter")"
    }

    // MARK: - Editing

    /// Saves the current arrangement as a new preset. The first time, the arrangement is also kept as the everyday
    /// preset, so there is something to come back to.
    func save(name: String, trigger: LayoutPreset.Trigger, keys: [String]) {
        var all = presets
        if all.isEmpty, trigger != .otherwise {
            let everyday = LayoutPreset(name: "平常", keys: keys, trigger: .otherwise)
            all.append(everyday)
            activeID = everyday.id
        }
        let preset = LayoutPreset(name: name, keys: keys, trigger: trigger)
        all.append(preset)
        presets = Self.uniqueOtherwise(all, keeping: trigger == .otherwise ? preset.id : nil)
        if activeID == nil { activeID = preset.id }
        Log.write("presets: saved \(name) (\(trigger.rawValue)), \(keys.count) items")
        // A trigger that holds already: switch now.
        lastConditions = nil
        evaluate()
    }

    func delete(_ id: UUID) {
        presets.removeAll { $0.id == id }
        if activeID == id { activeID = presets.first { $0.trigger == .otherwise }?.id ?? presets.first?.id }
    }

    func setTrigger(_ trigger: LayoutPreset.Trigger, for id: UUID) {
        var all = presets
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].trigger = trigger
        presets = Self.uniqueOtherwise(all, keeping: trigger == .otherwise ? id : nil)
        lastConditions = nil
        evaluate()
    }

    func rename(_ id: UUID, to name: String) {
        var all = presets
        guard let index = all.firstIndex(where: { $0.id == id }), !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        all[index].name = name
        presets = all
    }

    /// Picked by hand (menu or Settings).
    func activate(_ id: UUID) {
        guard let preset = presets.first(where: { $0.id == id }), id != activeID else { return }
        activeID = id
        Log.write("presets: picked \(preset.name)")
        onSwitch?(preset)
    }

    /// The arrangement changed while this preset was active (arranged, kept, put back): it is the preset now.
    func syncActive(_ keys: [String]) {
        guard let activeID else { return }
        var all = presets
        guard let index = all.firstIndex(where: { $0.id == activeID }), all[index].keys != keys else { return }
        all[index].keys = keys
        presets = all
    }

    /// Only one preset can be the everyday one.
    private static func uniqueOtherwise(_ presets: [LayoutPreset], keeping id: UUID?) -> [LayoutPreset] {
        var seen = false
        return presets.map { preset in
            guard preset.trigger == .otherwise else { return preset }
            if let id, preset.id != id { var copy = preset; copy.trigger = .manual; return copy }
            if id == nil, seen { var copy = preset; copy.trigger = .manual; return copy }
            seen = true
            return preset
        }
    }
}

extension LayoutPreset.Trigger {
    var title: String {
        switch self {
        case .otherwise: "平常（其他情況）"
        case .externalDisplay: "接上外接螢幕時"
        case .onBattery: "用電池時"
        case .manual: "只手動切換"
        }
    }
}
