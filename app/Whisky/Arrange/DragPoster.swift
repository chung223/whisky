import CoreGraphics
import Darwin
import WhiskyCore

/// The user's own mouse buttons, read from the HID state: the ⌘-drags Whisky posts at the session tap don't show up
/// there, so they never count as the user pressing.
enum UserMouseButtons {
    static var isAnyHeld: Bool {
        [CGMouseButton.left, .right, .center].contains { CGEventSource.buttonState(.hidSystemState, button: $0) }
    }

    static var pressCount: UInt32 {
        [CGEventType.leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(0) { $0 &+ CGEventSource.counterForEventType(.hidSystemState, eventType: $1) }
    }
}

/// Posts one synthetic ⌘-drag on macOS 26 (runs on a background thread; it sleeps between events).
///
/// The mouse-down lands on Whisky's own icon, which is always visible, and every event carries the undocumented
/// field 0x33 set to the dragged item's window, so the window server drags *that* item whatever its position, even
/// behind the notch. If routing ever degraded to the pointer position, the worst case is dragging Whisky's own icon.
/// The mouse-up is posted only once the item has been lifted (see `DragReleaseGate`), aimed at the target as it is then.
enum DragPoster {
    struct Report: Sendable, CustomStringConvertible {
        var posted = false
        var liftedAfter: Int?
        var releasedAfter = 0
        var mouseUp = CGPoint.zero
        var interrupted = false

        var description: String {
            guard posted else { return "not posted (a mouse button was down)" }
            let lift = liftedAfter.map { "lifted after \($0) ms" } ?? "never seen lifted"
            return "\(lift), released after \(releasedAfter) ms at (\(Int(mouseUp.x)), \(Int(mouseUp.y)))"
                + (interrupted ? ", cut short by the user's mouse" : "")
        }
    }

    static let windowIDField = CGEventField(rawValue: 0x33)!
    private static let pollMicroseconds: useconds_t = 10_000
    private static let liftTimeout: Duration = .milliseconds(600)
    private static let releaseTimeout: Duration = .milliseconds(1200)

    static func post(itemID: UInt32, destination: MoveDestination, mouseDown: CGPoint,
                     originalFrame: CGRect, plannedTargetFrame: CGRect, waitsForStillness: Bool) -> Report {
        var report = Report(mouseUp: MovePlanning.dropPoint(for: destination, targetFrame: plannedTargetFrame))

        // Don't let the window server swallow the user's own input while synthetic events are in flight.
        if let session = CGEventSource(stateID: .combinedSessionState) {
            let permit: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
            session.setLocalEventsFilterDuringSuppressionState(permit, state: .eventSuppressionStateRemoteMouseDrag)
            session.setLocalEventsFilterDuringSuppressionState(permit, state: .eventSuppressionStateSuppressionInterval)
            session.localEventsSuppressionInterval = 0
        }

        let presses = UserMouseButtons.pressCount
        guard !UserMouseButtons.isAnyHeld else { return report }

        let source = CGEventSource(stateID: .hidSystemState)
        func event(_ type: CGEventType, at point: CGPoint) -> CGEvent? {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return nil }
            event.flags = .maskCommand
            event.setIntegerValueField(windowIDField, value: Int64(itemID))
            return event
        }
        guard let down = event(.leftMouseDown, at: mouseDown) else { return report }

        let savedPointer = CGEvent(source: nil)?.location
        let concealment = CursorConcealment.begin()
        defer { concealment.end(warpingTo: savedPointer) }

        let clock = ContinuousClock()
        let start = clock.now
        func elapsed() -> Int { Int((clock.now - start) / .milliseconds(1)) }
        var gate = DragReleaseGate(itemID: itemID, originalFrame: originalFrame, waitsForStillness: waitsForStillness)

        down.post(tap: .cgSessionEventTap)
        report.posted = true
        while true {
            usleep(pollMicroseconds)
            let frames = WindowList.statusFrames()
            let ready = gate.observe(frames)
            if gate.isLifted, report.liftedAfter == nil { report.liftedAfter = elapsed() }
            if gate.isLifted, let target = frames[destination.targetWindowID] {
                report.mouseUp = MovePlanning.dropPoint(for: destination, targetFrame: target)
            }
            if ready { break }
            if UserMouseButtons.isAnyHeld || UserMouseButtons.pressCount != presses {
                report.interrupted = true
                break
            }
            let waited = clock.now - start
            if waited >= releaseTimeout || (!gate.isLifted && waited >= liftTimeout) { break }
        }
        report.releasedAfter = elapsed()
        event(.leftMouseUp, at: report.mouseUp)?.post(tap: .cgSessionEventTap)
        usleep(20_000)
        if UserMouseButtons.pressCount != presses { report.interrupted = true }
        return report
    }
}
