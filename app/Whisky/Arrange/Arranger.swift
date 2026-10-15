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

    init(model: BarModel, anchorFrame: @escaping () -> NSRect?, anchorNumber: @escaping () -> UInt32?) {
        self.model = model
        self.anchorFrame = anchorFrame
        self.anchorNumber = anchorNumber
    }

    var isBusy: Bool { mover.isBusy }

    private var spacerID: UInt32? {
        guard let spacer, spacer.isActive else { return nil }
        return spacer.currentWindowID()
    }

    // MARK: - Single items

    /// Puts the item immediately left of Whisky's icon, the rightmost slot a third-party item can have.
    func pin(key: String) async -> Result<Void, ItemMover.Failure> {
        await model.refresh(captureGlyphs: false)
        guard let item = model.item(forKey: key), let itemID = item.windowID else { return failed("pin \(key)", .itemNotFound) }
        let result = await pinWindow(itemID, label: key)
        await model.refresh(captureGlyphs: false)
        return result
    }

    /// Sends the item to the far left, behind the notch (and left of the spacer, if there is one).
    func unpin(key: String) async -> Result<Void, ItemMover.Failure> {
        await model.refresh(captureGlyphs: false)
        guard let item = model.item(forKey: key), let itemID = item.windowID else { return failed("unpin \(key)", .itemNotFound) }
        let result = await sendAwayWindow(itemID, label: key)
        await model.refresh(captureGlyphs: false)
        return result
    }

    func pinWindow(_ itemID: UInt32, label: String) async -> Result<Void, ItemMover.Failure> {
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
        let anchor = anchorWindowID()
        let frames = WindowList.statusFrames(inMenuBarRowOnly: true)
        guard let leftmost = frames.filter({ $0.key != itemID && $0.key != anchor }).min(by: { $0.value.minX < $1.value.minX })?.key
        else { return failed("send away \(label)", .targetNotFound) }
        let result = await run("send away \(label)") { () async throws(ItemMover.Failure) in try await self.mover.move(itemID, to: .leftOf(leftmost)) }
        return result
    }

    /// One move by window IDs (debugging).
    func moveRaw(_ itemID: UInt32, to destination: MoveDestination) async -> Result<Void, ItemMover.Failure> {
        await run("move \(itemID) \(destination)") { () async throws(ItemMover.Failure) in try await self.mover.move(itemID, to: destination) }
    }

    // MARK: - Whole run

    /// Makes `visible` (left to right) the run next to Whisky's icon, with the spacer at its left end when there is one.
    func apply(visible: [ScannedItem], progress: @escaping @MainActor (Int, Int) -> Void) async -> Result<Int, ItemMover.Failure> {
        await rebuild(wanted: visible.compactMap(\.windowID), progress: progress)
    }

    /// The moves `apply` would make (nil when Whisky's icon can't be found).
    func plan(visible: [ScannedItem]) async -> RebuildPlanner.Plan? {
        await model.refresh(captureGlyphs: false)
        return currentPlan(wanted: visible.compactMap(\.windowID))
    }

    /// Turns the spacer on without changing what is visible: it goes first, then the items drawn now are put back
    /// after it in the same order.
    func enableSpacer(progress: @escaping @MainActor (Int, Int) -> Void = { _, _ in }) async -> Result<Int, ItemMover.Failure> {
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
        guard let plan = currentPlan(wanted: wanted, allowSendAway: allowSendAway) else { return failed("rebuild", .anchorUnavailable).map { 0 } }
        Log.write("arrange: rebuild \(wanted.count) items (spacer \(spacerID.map(String.init) ?? "off")): send away \(plan.sendAway), pin \(plan.pin)")
        if let onlyIDs {
            let outside = (plan.sendAway + plan.pin).filter { !onlyIDs.contains($0) }
            guard outside.isEmpty else {
                Log.write("arrange: rebuild refused: it would move \(outside), which are not allowed here")
                return .failure(.didNotMove)
            }
        }
        // A 5,000 pt spacer can't be dragged: collapse it while it has to move, and expand it again afterwards.
        let spacerMoves = spacerID.map { plan.pin.contains($0) || plan.sendAway.contains($0) } ?? false
        let reExpand = spacerMoves && spacer?.isExpanded == true
        if reExpand {
            spacer?.setExpanded(false)
            try? await Task.sleep(for: .milliseconds(400))
        }
        defer { if reExpand { spacer?.setExpanded(true) } }
        var done = 0
        for id in plan.sendAway {
            progress(done, plan.count)
            if case .failure(let failure) = await sendAwayWindow(id, label: "\(id)") { return .failure(failure) }
            done += 1
        }
        for id in plan.pin {
            progress(done, plan.count)
            if case .failure(let failure) = await pinWindow(id, label: "\(id)") { return .failure(failure) }
            done += 1
        }
        progress(done, plan.count)
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

    /// Whisky's icon frame in the menu bar (global top-left coordinates).
    func anchorWindowFrame() -> CGRect? {
        guard let id = anchorWindowID() else { return nil }
        return WindowList.statusFrames(inMenuBarRowOnly: true)[id]
    }
}
