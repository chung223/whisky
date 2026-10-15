import AppKit
import WhiskyCore

/// Arranges the menu bar with only the two moves that proved reliable on a notched macOS 26 menu bar (see
/// `RebuildPlanner`): put an item immediately left of Whisky's icon, or send it to the far left. Nothing is dropped
/// at the notch boundary, where macOS repacks items.
@MainActor
final class Arranger {
    private let model: BarModel
    private lazy var mover = ItemMover(anchorWindowID: { [unowned self] in self.anchorWindowID() })
    private let anchorFrame: () -> NSRect?
    private let anchorNumber: () -> UInt32?
    /// Whisky's spacer, when it exists: hidden items end up left of it, and rebuilds keep it at the run's left end.
    var spacer: SpacerController?
    /// Items put next to Whisky's icon for a moment (to click them); they aren't part of the user's layout.
    var temporarilyShown: Set<UInt32> = []
    /// When Whisky's glass lives in the notch, it is only in the menu bar while items are moved (every drag starts on
    /// it, and items are dropped next to it). nil: the glass is always there.
    var revealAnchor: (() -> Void)?
    var concealAnchor: (() -> Void)?
    private var anchorHolds = 0

    init(model: BarModel, anchorFrame: @escaping () -> NSRect?, anchorNumber: @escaping () -> UInt32?) {
        self.model = model
        self.anchorFrame = anchorFrame
        self.anchorNumber = anchorNumber
    }

    var isBusy: Bool { mover.isBusy }

    // MARK: - The glass, on demand

    /// Makes sure Whisky's glass is in the menu bar until the matching `releaseAnchor`. Holds nest.
    func holdAnchor() async {
        anchorHolds += 1
        guard anchorHolds == 1, let revealAnchor else { return }
        revealAnchor()
        // Wait for its window to be listed and drawn, then for the menu bar to finish making room.
        let deadline = ContinuousClock.now + .milliseconds(1500)
        while ContinuousClock.now < deadline {
            if let id = anchorWindowID(), WindowList.statusWindows().first(where: { $0.id == id })?.isOnscreen == true { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        try? await Task.sleep(for: .milliseconds(350))
    }

    func releaseAnchor() {
        anchorHolds = max(0, anchorHolds - 1)
        guard anchorHolds == 0, concealAnchor != nil else { return }
        // A moment's grace, so back-to-back operations don't make it flicker.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, self.anchorHolds == 0 else { return }
            self.concealAnchor?()
        }
    }

    private func withAnchor<T>(_ body: () async -> T) async -> T {
        await holdAnchor()
        defer { releaseAnchor() }
        return await body()
    }

    private var spacerID: UInt32? {
        guard let spacer, spacer.isActive else { return nil }
        return spacer.currentWindowID()
    }

    // MARK: - Single items

    /// Puts the item immediately left of Whisky's icon, the rightmost slot a third-party item can have.
    func pin(key: String) async -> Result<Void, ItemMover.Failure> {
        await withAnchor { await pinKey(key) }
    }

    private func pinKey(_ key: String) async -> Result<Void, ItemMover.Failure> {
        await model.refresh(captureGlyphs: false)
        guard let item = model.item(forKey: key), let itemID = item.windowID else { return failed("pin \(key)", .itemNotFound) }
        let result = await pinWindow(itemID, label: key)
        await model.refresh(captureGlyphs: false)
        return result
    }

    /// Sends the item to the far left, behind the notch (and left of the spacer, if there is one).
    func unpin(key: String) async -> Result<Void, ItemMover.Failure> {
        await withAnchor { await unpinKey(key) }
    }

    private func unpinKey(_ key: String) async -> Result<Void, ItemMover.Failure> {
        await model.refresh(captureGlyphs: false)
        guard let item = model.item(forKey: key), let itemID = item.windowID else { return failed("unpin \(key)", .itemNotFound) }
        let result = await sendAwayWindow(itemID, label: key)
        await model.refresh(captureGlyphs: false)
        return result
    }

    func pinWindow(_ itemID: UInt32, label: String) async -> Result<Void, ItemMover.Failure> {
        await withAnchor { await pinWindowHeld(itemID, label: label) }
    }

    private func pinWindowHeld(_ itemID: UInt32, label: String) async -> Result<Void, ItemMover.Failure> {
        guard let anchor = anchorWindowID() else { return failed("pin \(label)", .anchorUnavailable) }
        // With nothing between an expanded spacer and Whisky's icon, a drop next to the icon doesn't land (measured:
        // three misses in a row). Collapse the spacer for that one move.
        let collapse = spacer?.isExpanded == true && spacerID.map { currentRun(spacerID: $0) == [$0] } == true
        if collapse {
            spacer?.setExpanded(false)
            try? await Task.sleep(for: .milliseconds(400))
        }
        defer { if collapse { spacer?.setExpanded(true) } }
        return await run("pin \(label)") { () async throws(ItemMover.Failure) in try await self.mover.move(itemID, to: .leftOf(anchor)) }
    }

    func sendAwayWindow(_ itemID: UInt32, label: String) async -> Result<Void, ItemMover.Failure> {
        await withAnchor { await sendAwayWindowHeld(itemID, label: label) }
    }

    private func sendAwayWindowHeld(_ itemID: UInt32, label: String) async -> Result<Void, ItemMover.Failure> {
        let anchor = anchorWindowID()
        let frames = WindowList.statusFrames(inMenuBarRowOnly: true).filter { $0.key != itemID && $0.key != anchor }
        // With the spacer, everything left of it is already off the screen and a drop far out there lands (measured
        // in the self-test). Without it, the leftmost item can hang partly off the screen when the menu bar is
        // overfull, and a drop left of it can't land (measured: three misses at x = -113); the leftmost item that
        // starts on the screen is just as far behind the notch.
        let displayMinX = NSScreen.screens.first?.frame.minX ?? 0
        let candidates = spacerID == nil ? frames.filter { $0.value.minX >= displayMinX } : frames
        guard let leftmost = (candidates.isEmpty ? frames : candidates).min(by: { $0.value.minX < $1.value.minX })?.key
        else { return failed("send away \(label)", .targetNotFound) }
        let result = await run("send away \(label)") { () async throws(ItemMover.Failure) in try await self.mover.move(itemID, to: .leftOf(leftmost)) }
        return result
    }

    /// One move by window IDs (debugging).
    func moveRaw(_ itemID: UInt32, to destination: MoveDestination) async -> Result<Void, ItemMover.Failure> {
        await holdAnchor()
        defer { releaseAnchor() }
        return await run("move \(itemID) \(destination)") { () async throws(ItemMover.Failure) in try await self.mover.move(itemID, to: destination) }
    }

    // MARK: - Whole run

    /// Makes `visible` (left to right) the run next to Whisky's icon, with the spacer at its left end when there is one.
    func apply(visible: [ScannedItem], progress: @escaping @MainActor (Int, Int) -> Void) async -> Result<Int, ItemMover.Failure> {
        await rebuild(wanted: visible.compactMap(\.windowID), progress: progress)
    }

    /// The moves `apply` would make (nil when Whisky's icon can't be found).
    func plan(visible: [ScannedItem]) async -> RebuildPlanner.Plan? {
        await holdAnchor()
        defer { releaseAnchor() }
        await model.refresh(captureGlyphs: false)
        return currentPlan(wanted: visible.compactMap(\.windowID))
    }

    /// Turns the spacer on without changing what is visible: it goes first, then the items drawn now are put back
    /// after it in the same order.
    func enableSpacer(progress: @escaping @MainActor (Int, Int) -> Void = { _, _ in }) async -> Result<Int, ItemMover.Failure> {
        await holdAnchor()
        defer { releaseAnchor() }
        guard let spacer else { return failed("enable spacer", .itemNotFound).map { 0 } }
        let shown = drawnRun()
        if !spacer.isActive { await spacer.create() }
        guard spacer.isActive else { return failed("enable spacer", .itemNotFound).map { 0 } }
        spacer.isEnabled = true
        Log.write("arrange: enable spacer, keeping \(shown.count) items visible")
        let result = await rebuild(wanted: shown, progress: progress)
        // Only once the run is in place does the spacer push everything else away.
        if case .success = result { spacer.setExpanded(true) }
        return result
    }

    func disableSpacer() {
        spacer?.remove()
        spacer?.isEnabled = false
    }

    /// - Parameters:
    ///   - allowSendAway: false to never move an item that isn't in `wanted` (needs a spacer).
    ///   - onlyIDs: a hard limit: if the plan would move anything outside this set, nothing is moved at all.
    func rebuild(wanted: [UInt32], allowSendAway: Bool = true, onlyIDs: Set<UInt32>? = nil,
                 progress: @escaping @MainActor (Int, Int) -> Void) async -> Result<Int, ItemMover.Failure> {
        await holdAnchor()
        defer { releaseAnchor() }
        guard let first = currentPlan(wanted: wanted, allowSendAway: allowSendAway) else { return failed("rebuild", .anchorUnavailable).map { 0 } }
        Log.write("arrange: rebuild \(wanted.count) items (spacer \(spacerID.map(String.init) ?? "off")): send away \(first.sendAway), pin \(first.pin)")
        if let onlyIDs {
            let outside = (first.sendAway + first.pin).filter { !onlyIDs.contains($0) }
            guard outside.isEmpty else {
                Log.write("arrange: rebuild refused: it would move \(outside), which are not allowed here")
                return .failure(.didNotMove)
            }
        }
        // A 5,000 pt spacer can't be dragged: when it has to move, keep it collapsed for the whole rebuild (as the
        // self-test measured it) and expand it again at the end.
        let spacerMoves = spacerID.map { first.pin.contains($0) || first.sendAway.contains($0) } ?? false
        let reExpandAtEnd = spacerMoves && spacer?.isExpanded == true
        if reExpandAtEnd {
            spacer?.setExpanded(false)
            try? await Task.sleep(for: .milliseconds(400))
        }
        defer { if reExpandAtEnd { spacer?.setExpanded(true) } }
        // Send-aways one at a time, re-reading the menu bar after each: macOS refills a gap on its own (sending one
        // item away often brings the next one back into place), so later moves may no longer be needed. Pins are a
        // sequence (each appends an item at the right end; pinning one already there is a no-op that still counts),
        // so they are carried out as planned, then the result is checked once more.
        var done = 0
        let limit = first.count + 3
        var plan = first
        while !plan.isEmpty {
            guard done < limit else {
                Log.write("arrange: rebuild gave up after \(done) moves; still to do: send away \(plan.sendAway), pin \(plan.pin)")
                return .failure(.didNotMove)
            }
            let steps: [(id: UInt32, sendsAway: Bool)] = plan.sendAway.first.map { [($0, true)] } ?? plan.pin.map { ($0, false) }
            for step in steps {
                progress(done, done + plan.count)
                if let onlyIDs, !onlyIDs.contains(step.id) {
                    Log.write("arrange: rebuild refused: the next move is \(step.id), which is not allowed here")
                    return .failure(.didNotMove)
                }
                // The spacer turned up in a later plan while expanded: collapse it for its own move.
                let reExpand = step.id == spacerID && spacer?.isExpanded == true
                if reExpand {
                    spacer?.setExpanded(false)
                    try? await Task.sleep(for: .milliseconds(400))
                }
                let result = step.sendsAway ? await sendAwayWindow(step.id, label: "\(step.id)") : await pinWindow(step.id, label: "\(step.id)")
                if reExpand { spacer?.setExpanded(true) }
                if case .failure(let failure) = result { return .failure(failure) }
                done += 1
            }
            guard let next = currentPlan(wanted: wanted, allowSendAway: allowSendAway) else { return failed("rebuild", .anchorUnavailable).map { 0 } }
            if steps.first?.sendsAway == true, next.count < plan.count - 1 { Log.write("arrange: the menu bar filled in by itself; \(next.count) moves left") }
            plan = next
        }
        progress(done, done)
        await model.refresh(captureGlyphs: false)
        return .success(done)
    }

    private func currentPlan(wanted: [UInt32], allowSendAway: Bool = true) -> RebuildPlanner.Plan? {
        guard anchorWindowID() != nil else { return nil }
        let spacerID = spacerID
        let wantedIDs = (spacerID.map { [$0] } ?? []) + wanted.filter { $0 != spacerID }
        return RebuildPlanner.plan(run: currentRun(spacerID: spacerID), wanted: wantedIDs, hasSpacer: spacerID != nil,
                                   allowSendAway: allowSendAway || spacerID == nil)
    }

    /// The run as the menu bar shows it: from the spacer to Whisky's icon, or without a spacer, the items drawn left
    /// of the icon. Left to right.
    func currentRun(spacerID: UInt32?) -> [UInt32] {
        let windows = WindowList.statusWindows().filter { $0.frame.midY >= -1 && $0.frame.midY < 40 }
        guard let anchor = anchorWindowID(), let anchorFrame = windows.first(where: { $0.id == anchor })?.frame else { return [] }
        let left = windows.filter { $0.id != anchor && $0.frame.maxX <= anchorFrame.minX + 1 }.sorted { $0.frame.minX < $1.frame.minX }
        if let spacerID, let spacer = left.first(where: { $0.id == spacerID }) {
            return left.filter { $0.frame.minX >= spacer.frame.minX - 1 }.map(\.id)
        }
        return left.filter(\.isOnscreen).map(\.id)
    }

    struct RowEntry: Equatable {
        let key: String
        let isDrawn: Bool
        /// Control Center's modules: some come and go on their own (the microphone and camera indicator, Now Playing,
        /// Focus), so they don't count when comparing layouts.
        let isSystem: Bool
    }

    /// The menu bar left of Whisky's icon in order, drawn or not: from the spacer when there is one (`isBounded`),
    /// otherwise from the far left. Whisky's own items, items shown for a moment and windows the last scan didn't
    /// name are left out. Call after `model.refresh`.
    func layoutRow() -> (entries: [RowEntry], isBounded: Bool) {
        let windows = WindowList.statusWindows().filter { $0.frame.midY >= -1 && $0.frame.midY < 40 }
        guard let boundary = runBoundary() else { return ([], false) }
        let anchor = anchorWindowID()
        var left = windows.filter { $0.id != anchor && $0.frame.maxX <= boundary.minX + 1 }.sorted { $0.frame.minX < $1.frame.minX }
        var isBounded = false
        if let spacerID, let spacer = left.first(where: { $0.id == spacerID }) {
            left = left.filter { $0.frame.minX > spacer.frame.minX }
            isBounded = true
        }
        let items = Dictionary(model.lastScan.compactMap { item in item.windowID.map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        let entries = left.compactMap { window -> RowEntry? in
            guard !temporarilyShown.contains(window.id), let item = items[window.id] else { return nil }
            return RowEntry(key: item.key, isDrawn: window.isOnscreen, isSystem: BarModel.isSystemOwned(item))
        }
        return (entries, isBounded)
    }

    /// The items drawn left of Whisky's icon now (not counting the spacer), left to right.
    private func drawnRun() -> [UInt32] {
        let spacerID = spacerID
        return currentRun(spacerID: nil).filter { $0 != spacerID }
    }

    // MARK: - Helpers

    private func failed(_ label: String, _ failure: ItemMover.Failure) -> Result<Void, ItemMover.Failure> {
        Log.write("arrange: \(label) failed: \(failure)")
        return .failure(failure)
    }

    private func run(_ label: String, _ body: () async throws(ItemMover.Failure) -> Void) async -> Result<Void, ItemMover.Failure> {
        Log.write("arrange: \(label)")
        do {
            try await body()
            return .success(())
        } catch {
            Log.write("arrange: \(label) failed: \(error)")
            return .failure(error)
        }
    }

    /// Whisky's icon as the window server lists it, matched by the button's frame (it is drawn and fixed in size,
    /// which is where frame matching is reliable).
    func anchorWindowID() -> UInt32? {
        let windows = WindowList.statusWindows()
        if let number = anchorNumber(), windows.contains(where: { $0.id == number }) { return number }
        guard let cocoa = anchorFrame(), let primary = NSScreen.screens.first else { return nil }
        let frame = MenuBarGeometry.topLeftRect(fromCocoa: cocoa, primaryMaxY: primary.frame.maxY)
        return StatusWindowMatcher.match(frame, in: windows)?.id
    }

    /// False while the menu bar is hidden (a full-screen app, or "automatically hide the menu bar"): then nothing in it
    /// is drawn, so it can be neither read as a layout nor arranged.
    func isMenuBarShown() -> Bool {
        let windows = WindowList.statusWindows()
        if let id = anchorWindowID(), let anchor = windows.first(where: { $0.id == id }) { return anchor.isOnscreen }
        // The glass is in the notch: look at the items macOS keeps at the right end instead.
        let fixed = fixedRightItemIDs()
        return windows.contains { fixed.contains($0.id) && $0.isOnscreen }
    }

    /// Where the user's part of the menu bar ends on the right: Whisky's glass, or while it is in the notch, the first
    /// of the items macOS keeps at the right end (Control Center, the clock). Global top-left coordinates.
    func runBoundary() -> CGRect? {
        if let frame = anchorWindowFrame() { return frame }
        let frames = WindowList.statusFrames(inMenuBarRowOnly: true)
        return fixedRightItemIDs().compactMap { frames[$0] }.min { $0.minX < $1.minX }
    }

    /// Control Center's own icon and the clock: always the rightmost items, never moved.
    private func fixedRightItemIDs() -> Set<UInt32> {
        let keys: Set<String> = ["com.apple.controlcenter-BentoBox", "com.apple.controlcenter-BentoBox-0", "com.apple.controlcenter-Clock"]
        return Set(model.lastScan.filter { keys.contains($0.key) }.compactMap(\.windowID))
    }

    /// Whisky's icon frame in the menu bar (global top-left coordinates).
    func anchorWindowFrame() -> CGRect? {
        guard let id = anchorWindowID() else { return nil }
        return WindowList.statusFrames(inMenuBarRowOnly: true)[id]
    }
}
