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
    private var sleepObservers: [NSObjectProtocol] = []
    private var powerSource: CFRunLoopSource?
    /// Displays asleep: monitors drop out of the screen list then, which isn't the user unplugging them.
    private var displaysAsleep = false
    /// Switched to, but its arrangement isn't in place yet. Until it is, the active preset stays the one whose
    /// arrangement the menu bar shows, so arranging meanwhile can't write the old layout into the new preset.
    private(set) var pendingID: UUID?

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
        let workspace = NSWorkspace.shared.notificationCenter
        sleepObservers.append(workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.displaysAsleep = true
                self?.pendingEvaluation?.cancel()
            }
        })
        sleepObservers.append(workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.displaysAsleep = false
                // Docks and monitors come back late after a wake.
                self?.evaluateSoon(after: .seconds(10))
            }
        })
        lastConditions = Self.currentConditions()
    }

    /// At launch: the preset the conditions call for now (it may differ from the one active when Whisky quit), made
    /// active without switching: the launch check puts its arrangement in place.
    func selectForLaunch() -> LayoutPreset? {
        let conditions = Self.currentConditions()
        lastConditions = conditions
        guard let id = PresetSelector.select(presets, for: conditions), let preset = presets.first(where: { $0.id == id }) else { return active }
        if id != activeID {
            Log.write("presets: at launch \(Self.describe(conditions)) → \(preset.name)")
            pendingID = id
        }
        return preset
    }

    /// Displays come and go in bursts of notifications, and some flicker: act only on conditions that held still.
    private func evaluateSoon(after delay: Duration = .seconds(4)) {
        pendingEvaluation?.cancel()
        pendingEvaluation = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled, !self.displaysAsleep else { return }
            let first = Self.currentConditions()
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !self.displaysAsleep, Self.currentConditions() == first else { return }
            self.evaluate()
        }
    }

    private func evaluate() {
        let conditions = Self.currentConditions()
        guard conditions != lastConditions else { return }
        lastConditions = conditions
        guard let id = PresetSelector.select(presets, for: conditions), id != (pendingID ?? activeID),
              let preset = presets.first(where: { $0.id == id }) else { return }
        Log.write("presets: \(Self.describe(conditions)) → \(preset.name)")
        switchPending(to: preset)
    }

    private func switchPending(to preset: LayoutPreset) {
        pendingID = preset.id == activeID ? nil : preset.id
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
        if pendingID == id { pendingID = nil }
        guard activeID == id else { return }
        // The menu bar shows the deleted preset's arrangement: switch to the everyday one properly, so its
        // arrangement is put in place (and arranging later doesn't write the deleted layout into it).
        activeID = nil
        if let next = presets.first(where: { $0.trigger == .otherwise }) ?? presets.first {
            pendingID = next.id
            onSwitch?(next)
        }
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
        guard let preset = presets.first(where: { $0.id == id }), id != (pendingID ?? activeID) else { return }
        Log.write("presets: picked \(preset.name)")
        switchPending(to: preset)
    }

    /// The pending preset's arrangement turned out to be in place already (the launch check matched).
    func confirmPending() {
        guard let pendingID else { return }
        activeID = pendingID
        self.pendingID = nil
        Log.write("presets: \(active?.name ?? "?") is in place")
    }

    /// The arrangement was taken anew. After a put-back it is the pending preset's arrangement in place: that preset
    /// becomes active, and keeps its items as the user arranged them. What the menu bar shows afterwards can be short
    /// of some (an app slow to answer, an item that couldn't be moved this time), and writing that into the preset
    /// lost them for good: on 2026-10-18 a morning of plugging a display in and out took 平常 from nine items to one,
    /// and every switch back to it then hid the rest. Otherwise the user arranged or kept something: it belongs to the
    /// active preset, and a switch still waiting is dropped (the user has just said what they want).
    func syncActive(_ keys: [String], afterPuttingBack: Bool) {
        if let pendingID {
            if afterPuttingBack {
                activeID = pendingID
                Log.write("presets: \(active?.name ?? "?") is in place")
            } else {
                Log.write("presets: switch dropped; the arrangement was changed by hand")
            }
            self.pendingID = nil
        }
        guard !afterPuttingBack, let activeID else { return }
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
