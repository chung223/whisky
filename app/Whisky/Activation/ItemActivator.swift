import AppKit
import WhiskyCore

/// Opens a status item that macOS didn't draw.
///
/// 1. If the item has a menu, mirror it under the pointer and forward the choice (nothing moves).
/// 2. Otherwise, if the item is in the menu bar but hidden (behind the notch or pushed off the screen), show it for a
///    moment: put it next to Whisky's icon (the move that always lands), click it, wait until what it opened is
///    closed, and send it back. Popovers need their item on screen to anchor to.
/// 3. Items that aren't in the menu bar at all are pressed through AX; if that does nothing, the app is brought forward.
@MainActor
final class ItemActivator {
    private let arranger: Arranger
    private var menuController: MirroredMenuController?
    private var isShowingTemporarily = false

    init(arranger: Arranger) {
        self.arranger = arranger
    }

    func open(_ item: ScannedItem, at location: NSPoint, beforePresenting: @escaping @MainActor () -> Void) {
        let element = item.element
        Task {
            let entries = await Task.detached(priority: .userInitiated) { MenuMirror.read(element) }.value
            beforePresenting()
            if let entries {
                Log.write("open \(item.id): mirrored \(entries.count) entries")
                let controller = MirroredMenuController()
                menuController = controller
                let menu = controller.makeMenu(appName: item.appName, entries: entries)
                // Let the panel finish closing before the menu starts tracking.
                try? await Task.sleep(for: .milliseconds(60))
                menu.popUp(positioning: nil, at: location, in: nil)
            } else {
                await press(item)
            }
        }
    }

    func press(_ item: ScannedItem) async {
        if item.placement == .hidden, let windowID = item.windowID {
            await showTemporarily(item, windowID: windowID)
        } else {
            await pressInPlace(item)
        }
    }

    // MARK: - Pressing where the item is

    private func pressInPlace(_ item: ScannedItem) async {
        let before = WindowList.onscreenWindowIDs(ownedBy: item.pid)
        let error = await axPress(item)
        if error == AXError.success.rawValue {
            let opened = await waitForNewWindows(of: item.pid, besides: before, timeout: .milliseconds(600))
            Log.write("open \(item.id): AXPress ok, opened \(opened.count) window(s)")
            if opened.isEmpty { NSSound.beep() }
        } else {
            Log.write("open \(item.id): AXPress failed (AXError \(error)), activating app")
            activateApp(item)
        }
    }

    // MARK: - Showing it for a moment

    private func showTemporarily(_ item: ScannedItem, windowID: UInt32) async {
        guard !isShowingTemporarily, !arranger.isBusy else {
            NSSound.beep()
            return
        }
        isShowingTemporarily = true
        arranger.temporarilyShown.insert(windowID)
        // Keep the glass in the menu bar the whole time (when it lives in the notch): it is where the item is shown.
        await arranger.holdAnchor()
        defer {
            isShowingTemporarily = false
            arranger.temporarilyShown.remove(windowID)
            arranger.releaseAnchor()
        }

        guard case .success = await arranger.pinWindow(windowID, label: "show \(item.id) for a moment") else {
            Log.write("open \(item.id): couldn't bring it out; pressing in place")
            await pressInPlace(item)
            return
        }
        // Let the menu bar finish relaying out (the spacer may have been collapsed and expanded around the move):
        // a popover opened while the item's window is still being replaced is left orphaned on screen.
        try? await Task.sleep(for: .milliseconds(600))

        let before = Set(WindowList.onscreenWindows().map(\.id))
        let itemMidX = WindowList.statusFrames(inMenuBarRowOnly: true)[windowID]?.midX ?? 0
        var opened: Set<UInt32> = []
        // Three ways to click it, gentlest first; the log says which one worked, to learn each app's habits.
        let pressResult = await axPress(item)
        if pressResult == AXError.success.rawValue {
            opened = await waitForPopup(near: itemMidX, of: item, besides: before, timeout: .milliseconds(1000))
        }
        Log.write("open \(item.id): AXPress \(pressResult == AXError.success.rawValue ? "ok" : "failed (\(pressResult))"), \(opened.isEmpty ? "nothing opened" : "opened")")
        if opened.isEmpty, let frame = WindowList.statusFrames(inMenuBarRowOnly: true)[windowID] {
            // A click routed to the item's window, the pointer hidden and put back.
            await Task.detached(priority: .userInitiated) { Self.click(windowID: windowID, at: CGPoint(x: frame.midX, y: frame.midY)) }.value
            opened = await waitForPopup(near: itemMidX, of: item, besides: before, timeout: .milliseconds(1200))
            Log.write("open \(item.id): routed click \(opened.isEmpty ? "nothing opened" : "opened")")
        }
        if opened.isEmpty, let frame = WindowList.statusFrames(inMenuBarRowOnly: true)[windowID] {
            // Some apps (iStat Menus) ignored both: a plain click, the pointer really moved onto the item and left
            // there until the dropdown is up, then put back.
            let saved = CGEvent(source: nil)?.location
            await Task.detached(priority: .userInitiated) { Self.plainClick(at: CGPoint(x: frame.midX, y: frame.midY)) }.value
            opened = await waitForPopup(near: itemMidX, of: item, besides: before, timeout: .milliseconds(1500))
            if let saved { CGWarpMouseCursorPosition(saved) }
            Log.write("open \(item.id): plain click \(opened.isEmpty ? "nothing opened" : "opened")")
        }
        Log.write("open \(item.id): shown for a moment, opened \(opened.count) window(s)")
        if opened.isEmpty {
            logNewWindows(besides: before, for: item)
            NSSound.beep()
        } else {
            await waitUntilClosed(opened)
        }
        _ = await arranger.sendAwayWindow(windowID, label: "put \(item.id) back")
    }

    /// Waits for a dropdown, popover or menu near the item, from any process (some apps draw their dropdown from a
    /// helper process, so watching only the item's owner misses it).
    private func waitForPopup(near itemMidX: CGFloat, of item: ScannedItem, besides before: Set<UInt32>, timeout: Duration) async -> Set<UInt32> {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let menuBarHeight = NSScreen.screens.first.map { $0.safeAreaInsets.top > 0 ? $0.safeAreaInsets.top : NSStatusBar.system.thickness } ?? 24
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let new = WindowList.onscreenWindows().filter { !before.contains($0.id) }
            let popups = PopupDetection.popups(among: new, itemMidX: itemMidX, menuBarHeight: menuBarHeight, statusLevel: statusLevel,
                                               excludingPID: item.pid == ownPID ? nil : ownPID)
            if !popups.isEmpty {
                Log.write("open \(item.id): opened \(popups.map { "\($0.id) pid \($0.pid) layer \($0.layer) \(Int($0.frame.width))×\(Int($0.frame.height))" })")
                return Set(popups.map(\.id))
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return []
    }

    /// Nothing recognisable opened: record what did appear, to learn how this app shows its dropdown.
    private func logNewWindows(besides before: Set<UInt32>, for item: ScannedItem) {
        let new = WindowList.onscreenWindows().filter { !before.contains($0.id) }.prefix(6)
        let described = new.map { "\($0.id) pid \($0.pid)\($0.pid == item.pid ? " (item's app)" : "") layer \($0.layer) at \(Int($0.frame.minX)),\(Int($0.frame.minY)) \(Int($0.frame.width))×\(Int($0.frame.height))" }
        Log.write("open \(item.id): nothing recognised as opened; new windows: \(described.isEmpty ? "none" : described.joined(separator: "; "))")
    }

    /// Waits until none of `windows` is on screen any more (the user closed the popover or menu), for at most 15 minutes.
    private func waitUntilClosed(_ windows: Set<UInt32>) async {
        let deadline = ContinuousClock.now + .seconds(15 * 60)
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(300))
            if WindowList.onscreenWindowIDs().isDisjoint(with: windows) { return }
        }
    }

    // MARK: - Helpers

    private func axPress(_ item: ScannedItem) async -> Int32 {
        let element = item.element
        // Pressing one of Whisky's own items runs its action right here, on the calling thread (AppKit handles
        // in-process AX calls directly), so it must be the main thread. Other apps answer on their own main thread,
        // so their calls go to the background to keep Whisky responsive.
        if item.pid == ProcessInfo.processInfo.processIdentifier {
            element.setTimeout(1)
            return element.perform("AXPress").rawValue
        }
        return await Task.detached(priority: .userInitiated) { () -> Int32 in
            element.setTimeout(1)
            return element.perform("AXPress").rawValue
        }.value
    }

    private func waitForNewWindows(of pid: pid_t, besides before: Set<UInt32>, timeout: Duration) async -> Set<UInt32> {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let fresh = WindowList.onscreenWindowIDs(ownedBy: pid).subtracting(before)
            if !fresh.isEmpty { return fresh }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return []
    }

    /// An ordinary left click where the pointer is moved to, as a person would make it.
    nonisolated private static func plainClick(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        if let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            move.post(tap: .cghidEventTap)
        }
        usleep(60_000)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.post(tap: .cghidEventTap)
            usleep(50_000)
        }
    }

    /// A left click routed to the item's window (field 0x33), with the pointer hidden and put back.
    nonisolated private static func click(windowID: UInt32, at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let saved = CGEvent(source: nil)?.location
        let concealment = CursorConcealment.begin()
        defer { concealment.end(warpingTo: saved) }
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.setIntegerValueField(DragPoster.windowIDField, value: Int64(windowID))
            event.post(tap: .cgSessionEventTap)
            usleep(30_000)
        }
    }

    func activateApp(_ item: ScannedItem) {
        if let app = NSRunningApplication(processIdentifier: item.pid), app.activationPolicy == .regular {
            app.activate()
        } else if let bundleID = item.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSSound.beep()
        }
    }
}
