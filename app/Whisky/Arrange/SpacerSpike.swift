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

    init(arranger: Arranger, spacer: SpacerController) {
        self.arranger = arranger
        self.spacer = spacer
    }

    func run() async {
        guard !arranger.isBusy else { Log.write("spike: busy"); return }
        Log.write("spike: start")
        let before = Snapshot.take(excluding: [])
        let hadSpacer = spacer.isActive
        defer { Log.write("spike: end, \(failures) failure(s)") }

        // 1. Test items and the spacer, with window IDs learned at creation.
        for (index, width) in [30, 44, 60, 84].enumerated() {
            let result = await OwnItems.create(length: CGFloat(width), autosaveName: "WhiskyTest\(index + 1)") { item in
                item.button?.title = "T\(index + 1)"
            }
            testItems.append(result)
        }
        check("test items have window IDs", testItems.allSatisfy { $0.windowID != nil }, detail: "\(testItems.map { $0.windowID.map(String.init) ?? "nil" })")
        if !hadSpacer { await spacer.create() }
        check("spacer has a window ID", spacer.windowID != nil, detail: spacer.summary)
        guard failures == 0, let spacerID = spacer.windowID else { await tearDown(hadSpacer: hadSpacer, before: before); return }
        let ids = testItems.compactMap(\.windowID)

        // 2. Build the run [spacer, T1, T2] by pinning only Whisky's own items, then expand the spacer.
        _ = await strictRebuild([ids[0], ids[1]])
        spacer.setExpanded(true)
        await settle()
        checkRun(expect: [spacerID, ids[0], ids[1]], label: "run is spacer, T1, T2")
        checkOnlyDrawn([ids[0], ids[1]], label: "with the spacer expanded")

        // 3. A run item gets wider (like a clock or a percentage changing): nothing else may appear.
        testItems[1].item.length = 84
        await settle()
        checkOnlyDrawn([ids[0], ids[1]], label: "after T2 grew to 84 pt")

        // 4. Reorder, with the spacer expanded.
        _ = await strictRebuild([ids[1], ids[0]])
        await settle()
        checkRun(expect: [spacerID, ids[1], ids[0]], label: "run is spacer, T2, T1")

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

        await tearDown(hadSpacer: hadSpacer, before: before)
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

    /// Left of Whisky's icon, macOS draws exactly the expected test items: none of the user's items slipped in.
    private func checkOnlyDrawn(_ expected: Set<UInt32>, label: String) {
        let windows = WindowList.statusWindows().filter { $0.frame.midY >= -1 && $0.frame.midY < 40 }
        guard let anchor = arranger.anchorWindowID(), let anchorFrame = windows.first(where: { $0.id == anchor })?.frame else {
            check("only the run is drawn \(label)", false, detail: "Whisky's icon not found")
            return
        }
        let drawn = Set(windows.filter { $0.isOnscreen && $0.frame.maxX <= anchorFrame.minX + 1 && $0.id != spacer.windowID }.map(\.id))
        check("only the run is drawn \(label)", drawn == expected,
              detail: "drawn \(drawn.sorted()), expected \(expected.sorted()); \(spacer.summary)")
    }

    private func settle(seconds: Double = 1.5) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: - Tear down

    private func tearDown(hadSpacer: Bool, before: Snapshot) async {
        for entry in testItems { NSStatusBar.system.removeStatusItem(entry.item) }
        for index in 1...4 {
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
