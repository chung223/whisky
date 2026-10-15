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
        defer {
            isShowingTemporarily = false
            arranger.temporarilyShown.remove(windowID)
        }

        guard case .success = await arranger.pinWindow(windowID, label: "show \(item.id) for a moment") else {
            Log.write("open \(item.id): couldn't bring it out; pressing in place")
            await pressInPlace(item)
            return
        }
        // Let the menu bar finish relaying out (the spacer may have been collapsed and expanded around the move):
        // a popover opened while the item's window is still being replaced is left orphaned on screen.
        try? await Task.sleep(for: .milliseconds(600))

        let before = WindowList.onscreenWindowIDs(ownedBy: item.pid)
        var opened: Set<UInt32> = []
        if await axPress(item) == AXError.success.rawValue {
            opened = await waitForNewWindows(of: item.pid, besides: before, timeout: .milliseconds(600))
        }
        if opened.isEmpty, let frame = WindowList.statusFrames(inMenuBarRowOnly: true)[windowID] {
            // Some items only react to a real click.
            await Task.detached(priority: .userInitiated) { Self.click(windowID: windowID, at: CGPoint(x: frame.midX, y: frame.midY)) }.value
            opened = await waitForNewWindows(of: item.pid, besides: before, timeout: .milliseconds(800))
        }
        Log.write("open \(item.id): shown for a moment, opened \(opened.count) window(s)")
        if opened.isEmpty {
            NSSound.beep()
        } else {
            await waitUntilClosed(opened)
        }
        _ = await arranger.sendAwayWindow(windowID, label: "put \(item.id) back")
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
