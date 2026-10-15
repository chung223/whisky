import AppKit
import WhiskyCore

/// Looks at the hidden items every half minute and points out, at the notch, one that changed after being quiet
/// for a while (a badge, a backup starting). Live readouts that change all the time are never pointed out
/// (`ChangeTracker`). Needs Screen Recording; pauses while the screen is locked, Whisky Bar is open or items move.
@MainActor
final class ChangeWatcher {
    private static let enabledKey = "announcesChanges"
    private static let interval: TimeInterval = 30

    var onChange: ((BarItem) -> Void)?
    /// Whether pointing something out is possible now (a notch to show it in, Whisky Bar closed).
    var canAnnounce: () -> Bool = { true }

    private let model: BarModel
    private let arranger: Arranger
    private var tracker = ChangeTracker()
    private var timer: Timer?
    private var isLooking = false
    private var timedRounds = 0

    init(model: BarModel, arranger: Arranger) {
        self.model = model
        self.arranger = arranger
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue { tracker = ChangeTracker() }
        }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.look() }
            }
        }
    }

    private func look() async {
        guard isEnabled, !isLooking, canAnnounce(), Permissions.hasScreenRecording, model.isAccessibilityTrusted,
              !arranger.isBusy, arranger.temporarilyShown.isEmpty, !Self.isScreenLocked
        else { return }
        isLooking = true
        defer { isLooking = false }

        await model.refresh(captureGlyphs: false)
        let hidden = model.items.filter { !$0.isOff && $0.scanned.windowID != nil }
        let started = ContinuousClock.now
        let glyphs = await GlyphCapture.capture(hidden.map { (id: $0.id, windowID: $0.scanned.windowID!) })
        if timedRounds < 3 {
            timedRounds += 1
            Log.write("changes: looked at \(hidden.count) hidden items in \(ContinuousClock.now - started)")
        }
        model.store(glyphs)
        let round = hidden.compactMap { item in glyphs[item.id].map { (key: item.scanned.key, fingerprint: $0.fingerprint) } }
        let changed = tracker.observe(round)
        guard let key = changed.first, canAnnounce(), let item = model.items.first(where: { $0.scanned.key == key }) else { return }
        Log.write("changes: \(item.displayName) changed\(changed.count > 1 ? " (and \(changed.count - 1) more)" : "")")
        onChange?(item)
    }

    private static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
