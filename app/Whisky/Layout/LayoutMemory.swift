import AppKit
import WhiskyCore

/// Remembers the run the user arranged and notices when the menu bar no longer shows it: an app updated, relaunched
/// or changed its item's width, and macOS put the item back somewhere else. Whisky only points it out (in Whisky Bar
/// and the menu); the user decides whether to put it right or keep the new order. Nothing moves on its own.
@MainActor
final class LayoutMemory {
    private static let savedKey = "savedLayout"
    private static let watchKey = "watchesLayout"

    private let model: BarModel
    private let arranger: Arranger
    private var pendingCheck: Task<Void, Never>?
    /// A difference seen once; it is shown only if the next check, 20 s later, still sees it (apps starting up and
    /// the menu bar relaying out pass through states that sort themselves out).
    private var unconfirmed: LayoutDriftNotice?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(model: BarModel, arranger: Arranger) {
        self.model = model
        self.arranger = arranger
    }

    /// The arranged run, left to right (item keys); nil until the first snapshot.
    var saved: [String]? {
        get { UserDefaults.standard.stringArray(forKey: Self.savedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.savedKey) }
    }

    var isWatching: Bool {
        get { UserDefaults.standard.object(forKey: Self.watchKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.watchKey)
            if newValue { scheduleCheck(after: .zero) } else { model.layoutDrift = nil }
        }
    }

    /// Checks shortly after launch, after waking, when apps start or quit, and every five minutes.
    func start() {
        scheduleCheck(after: .seconds(15))
        let workspace = NSWorkspace.shared.notificationCenter
        let checkSoon: @Sendable (Notification) -> Void = { [weak self] note in
            let delay: Duration = note.name == NSWorkspace.didWakeNotification ? .seconds(15) : .seconds(8)
            Task { @MainActor in self?.scheduleCheck(after: delay) }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main, using: checkSoon))
        }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCheck(after: .zero) }
        }
    }

    /// Takes the run as it is now as the arrangement (after the user arranged something, or chose to keep it): with the
    /// spacer, everything between it and Whisky's icon; without it, from the leftmost drawn item to the icon (an item
    /// skipped for room in between included). Control Center's modules are kept, so putting the run back leaves them
    /// where they were.
    func remember() async {
        await model.refresh(captureGlyphs: false)
        guard arranger.isMenuBarShown() else {
            Log.write("layout: menu bar hidden, keeping the remembered layout")
            return
        }
        let row = arranger.layoutRow()
        let firstDrawn = row.entries.firstIndex(where: \.isDrawn)
        let run = row.isBounded ? row.entries.map(\.key) : firstDrawn.map { row.entries[$0...].map(\.key) } ?? []
        saved = run
        unconfirmed = nil
        model.layoutDrift = nil
        Log.write("layout: remembered \(run)")
    }

    func scheduleCheck(after delay: Duration) {
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.check()
        }
    }

    /// Compares the run with the arrangement and updates the notice.
    func check() async {
        guard isWatching, model.isAccessibilityTrusted, !arranger.isBusy else { return }
        await model.refresh(captureGlyphs: false)
        guard !arranger.isBusy, arranger.anchorWindowID() != nil, arranger.isMenuBarShown() else { return }
        guard let saved else {
            // First run: what the user has now is the arrangement.
            await remember()
            return
        }
        // Compared by order, drawn or not: an item that got wider pushing its neighbour behind the notch isn't a change
        // of layout (and putting the run back couldn't make room anyway). Without the spacer the run is as long as
        // the arrangement; items further left are behind the notch whatever their order.
        let present = Set(model.lastScan.filter { $0.placement != .off && !BarModel.isSystemOwned($0) }.map(\.key))
        let row = arranger.layoutRow()
        let others = row.entries.filter { !$0.isSystem }.map(\.key)
        let expectedCount = saved.filter { present.contains($0) }.count
        let current = row.isBounded ? others : Array(others.suffix(expectedCount))
        let difference = LayoutDrift.compare(saved: saved, current: current, present: present)
        let notice = difference.map { LayoutDriftNotice($0, missing: names($0.missing), extra: names($0.extra)) }
        guard let notice, let difference else {
            if model.layoutDrift != nil { Log.write("layout: as arranged again") }
            unconfirmed = nil
            model.layoutDrift = nil
            return
        }
        if notice == model.layoutDrift {
            unconfirmed = nil
        } else if notice == unconfirmed {
            Log.write("layout: drift: missing \(difference.missing), extra \(difference.extra), reordered \(difference.reordered)")
            unconfirmed = nil
            model.layoutDrift = notice
        } else {
            unconfirmed = notice
            scheduleCheck(after: .seconds(20))
        }
    }

    /// Puts the arranged items back, then takes what the menu bar shows afterwards as the arrangement (an item that
    /// doesn't fit any more is dropped from it instead of being reported forever).
    func restore() async -> Result<Int, ItemMover.Failure> {
        guard let saved else { return .success(0) }
        await model.refresh(captureGlyphs: false)
        let items = saved.compactMap { model.item(forKey: $0) }.filter { $0.placement != .off }
        Log.write("layout: restoring \(items.map(\.key))")
        let result = await arranger.apply(visible: items) { _, _ in }
        if case .success = result {
            await remember()
        } else {
            await check()
        }
        return result
    }

    private func names(_ keys: [String]) -> [String] {
        keys.compactMap { key in
            guard let item = model.item(forKey: key) else { return nil }
            let label = item.label.trimmingCharacters(in: .whitespaces)
            return label.isEmpty || label == item.appName ? item.appName : "\(item.appName)（\(label)）"
        }
    }
}

/// What Whisky Bar and the menu say when the run isn't as arranged.
struct LayoutDriftNotice: Equatable {
    /// Arranged items pushed out of the run, and items that turned up in it, by display name.
    let missing: [String]
    let extra: [String]
    let count: Int

    init(_ difference: LayoutDrift.Difference, missing: [String], extra: [String]) {
        self.missing = missing
        self.extra = extra
        count = difference.count
    }

    var names: [String] { missing + extra }

    var summary: String {
        switch (missing.count, extra.count) {
        case (0, 0): "選單列圖示的順序和你排的不一樣"
        case (1, 0): "「\(missing[0])」被擠出選單列了"
        case (_, 0): "有 \(missing.count) 個排好的圖示被擠出選單列"
        case (0, 1): "「\(extra[0])」跑到選單列上了"
        case (0, _): "有 \(extra.count) 個圖示跑到選單列上"
        default: "有 \(count) 個圖示不在你排好的位置"
        }
    }
}
