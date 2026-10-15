import AppKit
import WhiskyCore

/// A self-test for the spacer that moves only Whisky's own items: four test items (T1–T4) and the spacer. The user's
/// items are never dragged; they only get hidden while the test runs (they end up left of the spacer) and come back
/// when it tears down. Triggered with `whisky://spike`; every step is logged with PASS/FAIL.
@MainActor
final class SpacerSpike {
    private let arranger: Arranger
    private let spacer: SpacerController
    private var testItems: [(item: NSStatusItem, windowID: UInt32?)] = []
    private var failures = 0
    /// Whether Whisky's glass is in the menu bar (it leaves between moves when it lives in the notch).
    private var isGlassShown: () -> Bool = { true }

    init(arranger: Arranger, spacer: SpacerController) {
        self.arranger = arranger
        self.spacer = spacer
    }

    func run(isGlassShown: @escaping () -> Bool = { true }) async {
        guard !arranger.isBusy else { Log.write("spike: busy"); return }
        // The test moves the spacer to the glass and keeps it: with the user's spacer on, their whole run would end
        // up off the screen. Turn the spacer off first (and back on afterwards).
        guard !spacer.isActive else {
            Log.write("spike: refused: the spacer is on; turn it off before the self-test")
            return
        }
        self.isGlassShown = isGlassShown
        failures = 0
        Log.write("spike: start\(arranger.revealAnchor != nil ? " (glass in the notch)" : "")")
        // The glass may just have left the menu bar: let it finish making room before taking the "before" picture.
        if arranger.revealAnchor != nil { try? await Task.sleep(for: .seconds(2)) }
        let before = Snapshot.take(excluding: [])
        let hadSpacer = spacer.isActive
        defer { Log.write("spike: end, \(failures) failure(s)") }

        // 1. Test items and the spacer, with window IDs learned at creation. T5 and T6 are wide: with all six in the
        //    run it reaches the notch boundary, where the 1 pt spacer once went astray (step 9).
        for (index, width) in [30, 44, 60, 84, 100, 100].enumerated() {
            let result = await OwnItems.create(length: CGFloat(width), autosaveName: "WhiskyTest\(index + 1)") { item in
                item.button?.title = "T\(index + 1)"
                if index == 2 {
                    // T3 has an ordinary menu, for menu mirroring.
                    let menu = NSMenu()
                    menu.addItem(NSMenuItem(title: "Alpha", action: nil, keyEquivalent: ""))
                    menu.addItem(NSMenuItem(title: "Beta", action: nil, keyEquivalent: ""))
                    item.menu = menu
                }
            }
            testItems.append(result)
        }
        check("test items have window IDs", testItems.allSatisfy { $0.windowID != nil }, detail: "\(testItems.map { $0.windowID.map(String.init) ?? "nil" })")
        if !hadSpacer { await spacer.create() }
        check("spacer has a window ID", spacer.windowID != nil, detail: spacer.summary)
        guard failures == 0, let spacerID = spacer.windowID else { await tearDown(hadSpacer: hadSpacer, before: before); return }
        let ids = testItems.compactMap(\.windowID)

        // 2. Turn the spacer on the way Settings does, keeping [T1, T2]: spacer next to the glass, expanded, then the
        //    run brought back from off the screen (re-pins of Whisky's own items only).
        let wasEnabled = spacer.isEnabled
        let enabled = await arranger.enableSpacer(keeping: [ids[0], ids[1]])
        spacer.isEnabled = wasEnabled
        if case .failure = enabled { check("enable the spacer keeping T1, T2", false, detail: "failed") }
        await settle()
        checkRun(expect: [spacerID, ids[0], ids[1]], label: "run is spacer, T1, T2")
        checkOnlyDrawn([ids[0], ids[1]], label: "with the spacer expanded")
        await checkGlassAway(order: [spacerID, ids[0], ids[1]], label: "T1, T2")

        // 3. A run item gets wider (like a clock or a percentage changing): nothing else may appear.
        testItems[1].item.length = 84
        await settle()
        checkOnlyDrawn([ids[0], ids[1]], label: "after T2 grew to 84 pt")

        // 4. Reorder, with the spacer expanded.
        _ = await strictRebuild([ids[1], ids[0]])
        await settle()
        checkRun(expect: [spacerID, ids[1], ids[0]], label: "run is spacer, T2, T1")
        await checkGlassAway(order: [spacerID, ids[1], ids[0]], label: "T2, T1")

        // 5. Hide one: T2 is re-pinned away from the run (it ends up left of the spacer, off the screen).
        _ = await strictRebuild([ids[0]])
        await settle()
        checkRun(expect: [spacerID, ids[0]], label: "run is spacer, T1")
        checkOnlyDrawn([ids[0]], label: "after hiding T2")

        // 6. Bring an off-screen test item back.
        _ = await strictRebuild([ids[0], ids[3]])
        await settle()
        checkRun(expect: [spacerID, ids[0], ids[3]], label: "run is spacer, T1, T4")
        checkOnlyDrawn([ids[0], ids[3]], label: "after showing T4")
        await checkGlassAway(order: [spacerID, ids[0], ids[3]], label: "T1, T4")

        // 7. Send T4 away (the usual, non-strict plan picks "send away" here), with the spacer expanded.
        var own = Set(ids)
        own.insert(spacerID)
        _ = await arranger.rebuild(wanted: [ids[0]], allowSendAway: true, onlyIDs: own) { _, _ in }
        await settle()
        checkRun(expect: [spacerID, ids[0]], label: "after sending T4 away")
        checkOnlyDrawn([ids[0]], label: "after sending T4 away")

        // 8. Menu mirroring reads T3's menu while T3 is off the screen.
        let pid = ProcessInfo.processInfo.processIdentifier
        if let frame = WindowList.statusFrames()[ids[2]] {
            let titles = await Task.detached { () -> [String]? in
                guard let element = Self.ownElement(near: frame, pid: pid) else { return nil }
                return MenuMirror.read(element)?.map(\.title)
            }.value
            check("menu mirroring reads an off-screen item's menu", titles == ["Alpha", "Beta"], detail: "\(titles ?? [])")
        } else {
            check("menu mirroring reads an off-screen item's menu", false, detail: "T3 window missing")
        }

        // 9. A run that fills the space up to the notch: turn the spacer on keeping all six (the way Settings does).
        //    The old order (pin the run, then the 1 pt spacer) left the spacer at the notch boundary, where macOS
        //    reshuffled it far left (2026-10-16, on the user's menu bar). Now the spacer is pinned and expanded first.
        spacer.setExpanded(false)
        try? await Task.sleep(for: .milliseconds(400))
        let all = Array(ids.prefix(6))
        let wide = await arranger.enableSpacer(keeping: all)
        spacer.isEnabled = wasEnabled
        if case .failure = wide { check("enable the spacer keeping all six (run up to the notch)", false, detail: "failed") }
        await settle()
        checkRun(expect: [spacerID] + all, label: "run reaching the notch is spacer, T1–T6")
        await checkGlassAway(order: [spacerID] + all, label: "T1–T6")

        // Opening a hidden item that shows a popover ("show it for a moment") isn't covered here: a test popover
        // anchored to one of Whisky's own items stayed on screen after close() and orderOut (2026-10-15), so the
        // step could never see it closed. It is checked by hand with a real app instead.

        await tearDown(hadSpacer: hadSpacer, before: before)
    }

    /// One of Whisky's own status items through Accessibility (call off the main thread: the main thread answers it).
    nonisolated static func ownElement(near frame: CGRect, pid: pid_t) -> AXElement? {
        let app = AXElement.application(pid)
        app.setTimeout(1)
        guard let bar = app.element("AXExtrasMenuBar") else { return nil }
        return bar.children.first { child in
            child.setTimeout(1)
            return child.frame.map { abs($0.midX - frame.midX) < 6 } ?? false
        }
    }

    /// Rebuilds moving nothing but Whisky's own items; refuses outright otherwise.
    private func strictRebuild(_ wanted: [UInt32]) async -> Bool {
        var own = Set(testItems.compactMap(\.windowID))
        if let id = spacer.windowID { own.insert(id) }
        let result = await arranger.rebuild(wanted: wanted, allowSendAway: false, onlyIDs: own) { _, _ in }
        if case .failure = result { check("rebuild moved only Whisky's own items", false, detail: "refused or failed") ; return false }
        return true
    }

    // MARK: - Checks

    private func check(_ label: String, _ passed: Bool, detail: String = "") {
        if !passed { failures += 1 }
        Log.write("spike: \(passed ? "PASS" : "FAIL") \(label)\(detail.isEmpty ? "" : " — \(detail)")")
    }

    private func checkRun(expect: [UInt32], label: String) {
        let run = arranger.currentRun(spacerID: spacer.currentWindowID())
        check(label, run == expect, detail: "run \(run)")
    }

    /// With the glass living in the notch: once the moves are done it leaves the menu bar, and the run keeps its order.
    private func checkGlassAway(order: [UInt32], label: String) async {
        guard arranger.revealAnchor != nil else { return }
        releaseGlass()
        try? await Task.sleep(for: .seconds(1))
        check("the glass left the menu bar after the moves", !isGlassShown())
        let frames = WindowList.statusFrames(inMenuBarRowOnly: true)
        let sorted = order.filter { frames[$0] != nil }.sorted { frames[$0]!.minX < frames[$1]!.minX }
        check("order kept without the glass (\(label))", sorted == order, detail: "\(sorted)")
    }

    /// Left of Whisky's icon, macOS draws exactly the expected test items: none of the user's items slipped in.
    private func checkOnlyDrawn(_ expected: Set<UInt32>, label: String) {
        let windows = WindowList.statusWindows().filter { $0.frame.midY >= -1 && $0.frame.midY < 40 }
        guard let anchor = arranger.anchorWindowID(), let anchorFrame = windows.first(where: { $0.id == anchor })?.frame else {
            check("only the run is drawn \(label)", false, detail: "Whisky's icon not found")
            return
        }
        // A popover hangs below the bar at the same level; only items in the bar row count.
        let drawn = Set(windows.filter { $0.isOnscreen && $0.frame.maxX <= anchorFrame.minX + 1 && $0.id != spacer.windowID && $0.frame.minY < 10 }.map(\.id))
        check("only the run is drawn \(label)", drawn == expected,
              detail: "drawn \(drawn.sorted()), expected \(expected.sorted()); \(spacer.summary)")
    }

    /// Waits for the menu bar to settle; with the glass living in the notch, brings it back first, because the
    /// checks look for the run left of it (`releaseGlass` afterwards).
    private func settle(seconds: Double = 1.5) async {
        if arranger.revealAnchor != nil, !holdingGlass {
            await arranger.holdAnchor()
            holdingGlass = true
        }
        try? await Task.sleep(for: .seconds(seconds))
    }

    private var holdingGlass = false

    private func releaseGlass() {
        guard holdingGlass else { return }
        holdingGlass = false
        arranger.releaseAnchor()
    }

    // MARK: - Tear down

    private func tearDown(hadSpacer: Bool, before: Snapshot) async {
        releaseGlass()
        for entry in testItems { NSStatusBar.system.removeStatusItem(entry.item) }
        for index in 1...6 {
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position WhiskyTest\(index)")
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Visible WhiskyTest\(index)")
        }
        testItems = []
        if !hadSpacer { spacer.remove() }
        try? await Task.sleep(for: .seconds(2))
        let after = Snapshot.take(excluding: [])
        check("the same items are drawn as before the test", after.drawn == before.drawn,
              detail: "missing \(before.drawn.subtracting(after.drawn).sorted()), new \(after.drawn.subtracting(before.drawn).sorted())")
        check("drawn items are in the same order", after.drawnOrder == before.drawnOrder, detail: "\(after.drawnOrder)")
    }

    /// The user's menu bar as seen from CGWindowList.
    private struct Snapshot {
        var drawn: Set<UInt32>
        var drawnOrder: [UInt32]

        @MainActor
        static func take(excluding: Set<UInt32>) -> Snapshot {
            let windows = WindowList.statusWindows().filter { $0.frame.midY >= -1 && $0.frame.midY < 40 && !excluding.contains($0.id) }
            let drawn = windows.filter(\.isOnscreen).sorted { $0.frame.minX < $1.frame.minX }
            return Snapshot(drawn: Set(drawn.map(\.id)), drawnOrder: drawn.map(\.id))
        }
    }
}
