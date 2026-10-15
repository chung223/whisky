import CoreGraphics
import WhiskyCore

/// Moves one status item next to another with a synthetic ⌘-drag, then checks the menu bar's order.
/// One move at a time; each attempt is verified and retried a few times.
@MainActor
final class ItemMover {
    enum Failure: Error, CustomStringConvertible {
        case busy
        case anchorUnavailable
        case itemNotFound
        case targetNotFound
        case userBusy
        case didNotMove
        case menuBarHidden

        var description: String {
            switch self {
            case .busy: "另一個移動還在進行"
            case .anchorUnavailable: "找不到 Whisky 自己的圖示"
            case .itemNotFound: "找不到要移動的圖示"
            case .targetNotFound: "找不到目標位置"
            case .userBusy: "滑鼠按鍵一直按著"
            case .didNotMove: "圖示沒有移到位置"
            case .menuBarHidden: "選單列現在是隱藏的（全螢幕 App 或自動隱藏選單列），先讓它出現再試"
            }
        }
    }

    private(set) var isBusy = false
    private let anchorWindowID: () -> UInt32?

    init(anchorWindowID: @escaping () -> UInt32?) {
        self.anchorWindowID = anchorWindowID
    }

    func move(_ itemID: UInt32, to destination: MoveDestination, attempts: Int = 3) async throws(Failure) {
        guard !isBusy else { throw .busy }
        isBusy = true
        defer { isBusy = false }

        for attempt in 1...attempts {
            guard await waitForUserInput() else { throw .userBusy }
            guard let anchorID = anchorWindowID() else { throw .anchorUnavailable }
            let frames = WindowList.statusFrames(inMenuBarRowOnly: true)
            guard let anchor = frames[anchorID] else { throw .anchorUnavailable }
            // With the menu bar hidden (a full-screen app, or "automatically hide"), nothing in it is drawn and a drag
            // would land nowhere.
            guard WindowList.statusWindows().first(where: { $0.id == anchorID })?.isOnscreen == true else { throw .menuBarHidden }
            guard let item = frames[itemID] else { throw .itemNotFound }
            guard let target = frames[destination.targetWindowID] else { throw .targetNotFound }
            if MovePlanning.isSatisfied(itemID: itemID, destination: destination, frames: frames) {
                Log.write("move \(itemID) \(destination): already in place")
                return
            }

            let slides = MovePlanning.targetMaySlide(itemFrame: item, destination: destination, targetFrame: target,
                                                     anchorID: anchorID, anchorFrame: anchor)
            let mouseDown = CGPoint(x: anchor.midX, y: anchor.midY)
            let report = await Task.detached(priority: .userInitiated) {
                DragPoster.post(itemID: itemID, destination: destination, mouseDown: mouseDown,
                                originalFrame: item, plannedTargetFrame: target, waitsForStillness: slides)
            }.value
            Arranger.ownInputEnded = ContinuousClock.now
            let placed = await settle(itemID, destination)
            Log.write("move \(itemID) \(destination) attempt \(attempt): \(report); \(placed ? "verified" : "not in place")")
            if placed { return }
        }
        throw .didNotMove
    }

    /// Waits up to a few seconds for the user to let go of the mouse and close any open menu: a ⌘-drag posted
    /// meanwhile gets mixed up with their drag, and an open menu takes the mouse-down.
    private func waitForUserInput() async -> Bool {
        for _ in 0..<150 {
            if !UserMouseButtons.isAnyHeld && !WindowList.isMenuOpen() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return !UserMouseButtons.isAnyHeld
    }

    /// Polls the menu bar until the order is right and the frames have stopped moving (on-screen moves animate for
    /// about 0.4 s), or a timeout passes.
    private func settle(_ itemID: UInt32, _ destination: MoveDestination) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + .milliseconds(1200)
        try? await Task.sleep(for: .milliseconds(50))
        var previous = WindowList.statusFrames(inMenuBarRowOnly: true)
        var unchanged = 0
        while clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(25))
            let current = WindowList.statusFrames(inMenuBarRowOnly: true)
            unchanged = current == previous ? unchanged + 1 : 0
            previous = current
            if unchanged >= 2, MovePlanning.isSatisfied(itemID: itemID, destination: destination, frames: current) {
                return true
            }
        }
        return MovePlanning.isSatisfied(itemID: itemID, destination: destination, frames: previous)
    }
}
