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
    /// The arrangement was taken anew (the active layout preset follows it); true when it came from putting a
    /// remembered arrangement back (a preset switch completing), false when the user arranged or kept something.
    var onRemember: ((_ keys: [String], _ afterPuttingBack: Bool) -> Void)?
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
    func remember(afterPuttingBack: Bool = false) async {
        let previous = saved
        // Whatever goes wrong below, a put-back that finished leaves its preset in place (its items aren't rewritten).
        let keepRemembered = { [self] (reason: String) in
            Log.write("layout: \(reason), keeping the remembered layout")
            if afterPuttingBack, let previous { onRemember?(previous, true) }
        }
        guard await refreshWhileStill() else { return keepRemembered("the menu bar kept moving") }
        // A preset switch may have asked for another arrangement while the menu bar settled.
        guard saved == previous else {
            Log.write("layout: the arrangement changed meanwhile; not taking this one")
            return
        }
        guard arranger.isMenuBarShown() else { return keepRemembered("menu bar hidden") }
        let row = arranger.layoutRow()
        let firstDrawn = row.entries.firstIndex(where: \.isDrawn)
        let current = row.isBounded ? row.entries.map(\.key) : firstDrawn.map { row.entries[$0...].map(\.key) } ?? []
        // Arranged items this scan can't place keep their place: app not running or slow to answer, or an item the
        // scan didn't match to a window (it can't be in the row, which doesn't mean it left).
        let run = LayoutDrift.merge(current: current, previous: previous ?? [], present: placeableKeys(includingSystem: true))
        saved = run
        unconfirmed = nil
        model.layoutDrift = nil
        Log.write("layout: remembered \(run)")
        onRemember?(run, afterPuttingBack)
    }

    /// Scans until one scan ran while the menu bar held still. A scan matches items to their windows by frame, so one
    /// taken while items slide (the glass leaving the menu bar, a display coming or going) leaves some without a
    /// window and they drop out of the run read from it: on 2026-10-18 One Switch and AlDente went missing that way
    /// right after the glass left, and a whole run while an external display was being plugged in.
    private func refreshWhileStill(attempts: Int = 8) async -> Bool {
        // A scan already under way is joined rather than repeated, and it may have started before `before` below.
        await model.refresh(captureGlyphs: false)
        for attempt in 1...attempts {
            let before = WindowList.statusFrames(inMenuBarRowOnly: true)
            await model.refresh(captureGlyphs: false)
            if WindowList.statusFrames(inMenuBarRowOnly: true) == before { return true }
            if attempt < attempts { try? await Task.sleep(for: .milliseconds(400)) }
        }
        return false
    }

    /// Keys of the scanned items whose place in the run can be read (the scan matched them to a window). One without a
    /// window (iStat Menus' items on 2026-10-18) isn't in the row whether or not it moved, so it is neither reported
    /// missing nor dropped from the arrangement. Call after `model.refresh`.
    private func placeableKeys(includingSystem: Bool = false) -> Set<String> {
        Set(model.lastScan.filter { $0.windowID != nil && $0.placement != .off && (includingSystem || !BarModel.isSystemOwned($0)) }.map(\.key))
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
        guard PlatformSupport.movesItems, isWatching, model.isAccessibilityTrusted, !arranger.isBusy else { return }
        await model.refresh(captureGlyphs: false)
        // runBoundary, not the glass: it may live in the notch.
        guard !arranger.isBusy, arranger.runBoundary() != nil, arranger.isMenuBarShown() else { return }
        guard let saved else {
            // First run: what the user has now is the arrangement.
            await remember()
            return
        }
        // Compared by order, drawn or not: an item that got wider pushing its neighbour behind the notch isn't a change
        // of layout (and putting the run back couldn't make room anyway). Without the spacer the run is as long as
        // the arrangement; items further left are behind the notch whatever their order.
        let present = placeableKeys()
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

    /// Whether the run between the spacer and the end of the user's part matches the arrangement (by order, Control
    /// Center's modules aside). Used at launch to decide whether the spacer, put back by AppKit, can be expanded.
    enum LaunchCheck { case matches, differs, undecided }

    /// Whether the run between the spacer and the end of the user's part matches the arrangement (by order, Control
    /// Center's modules aside). Undecided while the menu bar is hidden (a full-screen app): nothing can be judged then.
    func checkRunAtLaunch() async -> LaunchCheck {
        await model.refresh(captureGlyphs: false)
        guard let saved else { return .matches }
        guard arranger.isMenuBarShown() else { return .undecided }
        let present = placeableKeys()
        let row = arranger.layoutRow()
        guard row.isBounded else { return .undecided }
        let current = row.entries.filter { !$0.isSystem }.map(\.key)
        let difference = LayoutDrift.compare(saved: saved, current: current, present: present)
        Log.write("layout: at launch the spacer's run \(difference == nil ? "matches" : "doesn't match") the arrangement\(difference.map { " (missing \($0.missing), extra \($0.extra))" } ?? "")")
        return difference == nil ? .matches : .differs
    }

    /// Puts the arranged items back, then takes what the menu bar shows afterwards as the arrangement (an item that
    /// doesn't fit any more is dropped from it instead of being reported forever). The layout preset it came from keeps
    /// all its items (`PresetManager.syncActive`), so the next switch to it tries them all again.
    /// - Parameter automatic: nobody asked for this just now (after a launch, a preset switch): only items Whisky
    ///   knows aren't arranged may be sent away (`Arranger.apply(onlyKnownStrays:)`).
    func restore(automatic: Bool = false) async -> Result<Int, ItemMover.Failure> {
        guard let target = saved else { return .success(0) }
        // An app can be slow to answer the scan (right after a launch); an arranged item missing from it would be
        // left out. Look a few more times, but only for apps that are running (the others can't answer).
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        for attempt in 1...5 {
            await model.refresh(captureGlyphs: false)
            let missing = target.filter { key in model.item(forKey: key) == nil && running.contains { key.hasPrefix($0 + "-") } }
            if missing.isEmpty || attempt == 5 {
                if !missing.isEmpty { Log.write("layout: \(missing) not in the menu bar; restoring without them") }
                break
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard !Task.isCancelled, saved == target else { return .failure(.didNotMove) }
        let items = target.compactMap { model.item(forKey: $0) }.filter { $0.placement != .off }
        // Known items in the run that aren't arranged.
        let arranged = Set(target)
        let strays = arranger.layoutRow().entries.filter { !$0.isSystem && !arranged.contains($0.key) }.compactMap { model.item(forKey: $0.key)?.windowID }
        Log.write("layout: restoring \(items.map(\.key))\(strays.isEmpty ? "" : ", sending away \(strays)")")
        let result = await arranger.apply(visible: items, strays: strays, onlyKnownStrays: automatic) { _, _ in }
        if case .success = result {
            // Another arrangement may have been asked for meanwhile (a preset switch): don't overwrite it.
            if saved == target {
                await remember(afterPuttingBack: true)
            } else {
                Log.write("layout: the arrangement changed while it was put back; not taking this one")
            }
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
