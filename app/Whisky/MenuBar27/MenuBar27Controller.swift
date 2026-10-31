import AppKit
import WhiskyCore

/// macOS 27's stand-in for arranging. Items can't be moved there, but the menu bar can be restricted to a list of
/// apps (`MenuBarAllowList`): the apps with an item in the active preset stay, the other apps Whisky has seen with an
/// item are left out and listed in Whisky Bar. Opening one lets its app into the menu bar alone for a moment, clicks
/// its item, and puts the list back once what it opened is closed.
///
/// Whisky only knows an app has an item once AX has seen it drawn, and an app crowded into the system's » never is.
/// So before restricting, apps never looked at are let in on their own for a moment (`discover`): the ones with an
/// item are remembered and, like a new item behind the spacer on macOS 26, go to Whisky Bar unless the user shows
/// them; the ones without are remembered as such. An app that couldn't be looked at stays in the menu bar: Whisky
/// never leaves out an app it couldn't list in Whisky Bar. Apple's own apps are only left out when the user arranged
/// them before (the input menu); the rest are system items, turned on or off in System Settings.
@MainActor
final class MenuBar27Controller {
    static let entryPrefix = "27:"
    private static let enabledKey = "restrictsMenuBar"
    private static let knownKey = "knownMenuBarItems"
    private static let withoutItemsKey = "appsWithoutMenuBarItems"

    private let allowList = MenuBarAllowList()
    private let activator: ItemActivator
    /// The keys of the arrangement to show: the active preset's.
    var arrangement: () -> [String] = { [] }
    /// Puts these keys in the arrangement (true) or takes them out (false).
    var onChangeArrangement: (_ keys: [String], _ shown: Bool) -> Void = { _, _ in }

    /// Remembered items: key → the app it belongs to.
    private var known: [String: String] {
        didSet { UserDefaults.standard.set(known, forKey: Self.knownKey) }
    }
    /// Apps looked at with nothing in the menu bar (looked at again when they launch).
    private var withoutItems: Set<String> {
        didSet { UserDefaults.standard.set(withoutItems.sorted(), forKey: Self.withoutItemsKey) }
    }
    private var hasStarted = false
    private var isOpening = false
    private var needsUpdate = false
    private var launchObserver: NSObjectProtocol?
    private var pendingLaunchCheck: Task<Void, Never>?
    private var clockMonitor: Any?
    /// Notification Center was opened from the clock for the user: the menu bar is whole until it closes.
    private var isRelayingClock = false

    init(activator: ItemActivator) {
        self.activator = activator
        known = UserDefaults.standard.dictionary(forKey: Self.knownKey) as? [String: String] ?? [:]
        withoutItems = Set(UserDefaults.standard.stringArray(forKey: Self.withoutItemsKey) ?? [])
    }

    static var isAvailable: Bool { MenuBarAllowList.isAvailable }

    /// Restrict the menu bar to the arranged apps. Off by default: it has side effects (see Settings).
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            Log.write("menu bar 27: restricting \(newValue ? "on" : "off")")
            Task { await update() }
        }
    }

    var isRestricting: Bool { allowList.allowed != nil }

    func start(seedKeys: [String]) async {
        guard Self.isAvailable else { return }
        seed(seedKeys)
        hasStarted = true
        if launchObserver == nil {
            launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                MainActor.assumeIsolated { self?.appLaunched(bundleID) }
            }
        }
        if clockMonitor == nil {
            clockMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                let location = CGEvent(source: nil)?.location ?? .zero
                MainActor.assumeIsolated { self?.clockClicked(at: location) }
            }
        }
        await update()
    }

    func stop() {
        allowList.stop()
    }

    // MARK: - The list

    /// Puts the list in place for the current arrangement (or lifts it when off, or when there is no arrangement),
    /// after looking at the apps never looked at.
    func update() async {
        guard Self.isAvailable, hasStarted else { return }
        if isOpening || isRelayingClock {
            needsUpdate = true
            return
        }
        let arranged = Set(arrangement().compactMap(bundleID(ofKey:)))
        guard isEnabled, !arranged.isEmpty else {
            await allowList.lift()
            return
        }
        let unlooked = Self.runningBundleIDs().subtracting(Set(known.values)).subtracting(withoutItems).filter(Self.mayHaveItems)
        if !unlooked.isEmpty { await discover(unlooked) }
        let allowed = MenuBarRestriction.allowed(arranged: arranged, known: Set(known.values), running: Self.runningBundleIDs())
        if allowList.allowed != allowed {
            let hidden = MenuBarRestriction.hidden(known: Set(known.values), allowed: allowed)
            Log.write("menu bar 27: showing \(arranged.sorted()); in Whisky Bar \(hidden.sorted())")
        }
        await allowList.apply(allowed)
    }

    /// Lets only these apps into the menu bar for a moment and remembers which have items. When they don't all fit
    /// (the system's » shows), the ones seen are taken out and the rest looked at again, a few rounds at most.
    private func discover(_ bundleIDs: Set<String>) async {
        var remaining = bundleIDs
        for round in 1...6 {
            Log.write("menu bar 27: looking for items of \(remaining.count) apps (round \(round)): \(remaining.sorted())")
            guard await allowList.apply(MenuBarRestriction.alwaysAllowed.union(remaining)) else { return }
            try? await Task.sleep(for: .milliseconds(1200))
            let apps = NSWorkspace.shared.runningApplications.compactMap { app -> RunningAppInfo? in
                guard let bundleID = app.bundleIdentifier, remaining.contains(bundleID) else { return nil }
                return RunningAppInfo(pid: app.processIdentifier, bundleID: bundleID, name: app.localizedName ?? bundleID, isBackgroundOnly: false)
            }
            let geometry = MenuBarGeometry.current()
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let (items, overflowing) = await Task.detached(priority: .userInitiated) {
                (MenuBarScanner().scan(apps: apps, geometry: geometry, ownPID: ownPID).items, Self.isOverflowing())
            }.value
            let seen = Set(items.compactMap(\.bundleID))
            remember(items.filter { $0.placement != .off })
            Log.write("menu bar 27: items found for \(seen.sorted())")
            remaining.subtract(seen)
            // Without the », everything left had room and drew nothing.
            guard overflowing else {
                withoutItems.formUnion(remaining)
                return
            }
            guard !seen.isEmpty, !remaining.isEmpty else { break }
        }
        Log.write("menu bar 27: no room to look at \(remaining.sorted()); they stay in the menu bar")
    }

    /// The system's » is in the menu bar (MenuBarAgent lists it among its items while it is drawn).
    nonisolated private static func isOverflowing() -> Bool {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else { return false }
        let app = AXElement.application(agent.processIdentifier)
        app.setTimeout(0.3)
        guard let bar = app.element("AXExtrasMenuBar") else { return false }
        bar.setTimeout(0.3)
        return bar.elements("AXChildren").contains { $0.string("AXIdentifier") == "menu-bar-overflow-indicator" }
    }

    /// Items seen in a scan. Apps never seen before go to Whisky Bar from now on (the list is updated).
    func learn(_ items: [ScannedItem]) {
        guard Self.isAvailable, hasStarted, !isOpening else { return }
        let added = remember(items)
        if !added.isEmpty {
            Log.write("menu bar 27: new apps with items: \(added.sorted())")
            Task { await update() }
        }
    }

    /// Adds the items' keys; returns the apps that weren't known before.
    @discardableResult
    private func remember(_ items: [ScannedItem]) -> Set<String> {
        let arranged = Set(arrangement().compactMap(bundleID(ofKey:)))
        let knownApps = Set(known.values)
        var added: Set<String> = []
        var updated = known
        for item in items {
            guard let bundleID = item.bundleID, updated[item.key] == nil,
                  !MenuBarRestriction.neverListed.contains(bundleID), !MenuBarRestriction.alwaysAllowed.contains(bundleID),
                  Self.mayHaveItems(bundleID) || knownApps.contains(bundleID) || arranged.contains(bundleID)
            else { continue }
            updated[item.key] = bundleID
            if !knownApps.contains(bundleID) { added.insert(bundleID) }
        }
        if updated != known { known = updated }
        if !added.isEmpty { withoutItems.subtract(added) }
        return added
    }

    /// Apple's apps are system items (or arranged before); everything else may have an item of its own.
    private static func mayHaveItems(_ bundleID: String) -> Bool {
        !bundleID.hasPrefix("com.apple.") && !MenuBarRestriction.alwaysAllowed.contains(bundleID)
    }

    /// Remembered keys (presets, uses, the saved layout) from before: their apps count as known.
    private func seed(_ keys: [String]) {
        var updated = known
        for key in keys where updated[key] == nil {
            guard let bundleID = bundleID(ofKey: key), !MenuBarRestriction.neverListed.contains(bundleID) else { continue }
            updated[key] = bundleID
        }
        if updated != known { known = updated }
    }

    func bundleID(ofKey key: String) -> String? {
        if let bundleID = known[key] { return bundleID }
        let running = Self.runningBundleIDs()
        return MenuBarRestriction.bundleID(ofKey: key) { candidate in
            running.contains(candidate) || NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate) != nil
        }
    }

    /// A launched app may have an item now: it is looked at again (and, with one, joins Whisky Bar).
    private func appLaunched(_ bundleID: String?) {
        guard isRestricting, let bundleID, Self.mayHaveItems(bundleID), !Set(known.values).contains(bundleID) else { return }
        withoutItems.remove(bundleID)
        pendingLaunchCheck?.cancel()
        pendingLaunchCheck = Task { [weak self] in
            // Apps put their item up a moment after launching.
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            await self.update()
        }
    }

    // MARK: - The clock

    /// While the menu bar is restricted, clicking the clock doesn't open Notification Center (measured on 27.2,
    /// 2026-10-31; neither does a synthetic Globe-N). A click on it lifts the restriction, clicks the clock again for
    /// the user, and restricts again once Notification Center is closed.
    private func clockClicked(at point: CGPoint) {
        guard isRestricting, !isOpening, !isRelayingClock, point.y < 40,
              let clock = Self.clockFrame(), clock.contains(point) else { return }
        isRelayingClock = true
        Task {
            Log.write("menu bar 27: the clock was clicked; lifting the restriction for Notification Center")
            await allowList.lift()
            try? await Task.sleep(for: .milliseconds(400))
            // Should a click ever get through while restricted, a second one would close it again.
            if !Self.isNotificationCenterOpen() {
                await Task.detached { Self.click(at: CGPoint(x: clock.midX, y: clock.midY)) }.value
            }
            var opened = false
            for _ in 0..<20 where !opened {
                try? await Task.sleep(for: .milliseconds(100))
                opened = Self.isNotificationCenterOpen()
            }
            if opened {
                // Its windows come and go while it slides in: closed means gone for a second.
                let deadline = ContinuousClock.now + .seconds(600)
                var goneSince: ContinuousClock.Instant?
                while ContinuousClock.now < deadline {
                    try? await Task.sleep(for: .milliseconds(250))
                    if Self.isNotificationCenterOpen() {
                        goneSince = nil
                    } else if let since = goneSince {
                        if ContinuousClock.now - since >= .seconds(1) { break }
                    } else {
                        goneSince = .now
                    }
                }
            }
            Log.write("menu bar 27: Notification Center \(opened ? "closed" : "didn't open"); restricting again")
            isRelayingClock = false
            needsUpdate = false
            await update()
        }
    }

    /// The clock: the last of the menu bar agent's own items.
    private static func clockFrame() -> CGRect? {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else { return nil }
        let app = AXElement.application(agent.processIdentifier)
        app.setTimeout(0.2)
        guard let bar = app.element("AXExtrasMenuBar") else { return nil }
        bar.setTimeout(0.2)
        return bar.elements("AXChildren").filter { $0.string("AXRole") == "AXGroup" }.compactMap(\.frame).max { $0.maxX < $1.maxX }
    }

    private static func isNotificationCenterOpen() -> Bool {
        guard let center = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return false }
        // Its desktop widgets are windows too, below everything; the panel floats above.
        return WindowList.onscreenWindows().contains { $0.pid == center.processIdentifier && $0.layer > 0 && $0.frame.width > 200 }
    }

    nonisolated private static func click(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.post(tap: .cghidEventTap)
            usleep(50_000)
        }
    }

    // MARK: - Whisky Bar

    /// Whisky Bar's entries while restricting: one per remembered item of a running app that is left out. nil while
    /// nothing is restricted (Whisky Bar shows what the scan found).
    func hiddenEntries() -> [ScannedItem]? {
        guard let allowed = allowList.allowed, !isOpening else { return nil }
        let hidden = MenuBarRestriction.hidden(known: Set(known.values), allowed: allowed)
        var apps: [String: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier, hidden.contains(bundleID), apps[bundleID] == nil { apps[bundleID] = app }
        }
        return known.compactMap { key, bundleID in apps[bundleID].map { Self.entry(key: key, bundleID: bundleID, app: $0) } }
        .sorted { $0.appName.localizedStandardCompare($1.appName) == .orderedAscending || ($0.appName == $1.appName && $0.key < $1.key) }
    }

    private static func entry(key: String, bundleID: String, app: NSRunningApplication) -> ScannedItem {
        let name = app.localizedName ?? bundleID
        return ScannedItem(
            id: entryPrefix + key, key: key, pid: app.processIdentifier, bundleID: bundleID, appName: name,
            element: .application(app.processIdentifier), frame: .zero,
            label: MenuBarRestriction.itemName(ofKey: key, bundleID: bundleID) ?? name,
            windowID: nil, windowName: nil, placement: .hidden
        )
    }

    /// Whether this key's app is left out of the menu bar now (so opening it is this controller's job).
    func isHidden(key: String) -> Bool {
        guard let allowed = allowList.allowed, let bundleID = known[key] ?? bundleID(ofKey: key) else { return false }
        return !allowed.contains(bundleID) && !MenuBarRestriction.neverListed.contains(bundleID)
    }

    /// The arranged apps that are running, for "put in Whisky Bar".
    func shownApps() -> [NSRunningApplication] {
        let arranged = Set(arrangement().compactMap(bundleID(ofKey:)))
            .subtracting(MenuBarRestriction.alwaysAllowed).subtracting(MenuBarRestriction.neverListed)
        var seen: Set<String> = []
        return NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleID = app.bundleIdentifier, arranged.contains(bundleID), !seen.contains(bundleID) else { return false }
            seen.insert(bundleID)
            return true
        }
        .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }
    }

    /// Shows an app in the menu bar from now on (in the active preset), or puts it in Whisky Bar.
    func setShown(_ shown: Bool, bundleID: String) {
        var keys = known.filter { $0.value == bundleID }.map(\.key).sorted()
        if keys.isEmpty { keys = ["\(bundleID)-Item-0"] }
        if !shown { keys = arrangement().filter { self.bundleID(ofKey: $0) == bundleID } }
        Log.write("menu bar 27: \(shown ? "show" : "hide") \(bundleID)")
        onChangeArrangement(keys, shown)
        Task { await update() }
    }

    /// Opens a left-out item: its app alone in the menu bar for a moment, the item clicked, the list put back once
    /// what it opened is closed.
    func open(key: String) async {
        guard !isOpening, let bundleID = known[key] ?? bundleID(ofKey: key),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else {
            NSSound.beep()
            return
        }
        isOpening = true
        Log.write("open \(key): letting \(bundleID) into the menu bar alone")
        if await allowList.apply(MenuBarRestriction.alwaysAllowed.union([bundleID])),
           let item = await waitForItem(key: key, app: app) {
            if await !activator.openDrawn(item) { NSSound.beep() }
        } else {
            Log.write("open \(key): its item didn't show up; bringing the app forward")
            activator.activateApp(Self.entry(key: key, bundleID: bundleID, app: app))
        }
        isOpening = false
        needsUpdate = false
        await update()
    }

    /// The app's item once it is drawn and has held still (its frame from AX; an item left out keeps reporting the
    /// place it had before, so the first readings can be stale). Up to 3 s.
    private func waitForItem(key: String, app: NSRunningApplication) async -> ScannedItem? {
        let info = RunningAppInfo(pid: app.processIdentifier, bundleID: app.bundleIdentifier,
                                  name: app.localizedName ?? key, isBackgroundOnly: false)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let start = ContinuousClock.now
        var previous: CGRect?
        while ContinuousClock.now - start < .seconds(3) {
            try? await Task.sleep(for: .milliseconds(150))
            let geometry = MenuBarGeometry.current()
            let items = await Task.detached(priority: .userInitiated) {
                MenuBarScanner().scan(apps: [info], geometry: geometry, ownPID: ownPID).items
            }.value
            guard let item = items.first(where: { $0.key == key }) ?? items.first(where: { $0.placement != .off }) else { continue }
            defer { previous = item.frame }
            if ContinuousClock.now - start >= .milliseconds(600), item.frame == previous { return item }
        }
        return nil
    }

    private static func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy != .prohibited }.compactMap(\.bundleIdentifier))
    }
}
