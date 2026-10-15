import CoreGraphics
import Testing
@testable import WhiskyCore

/// Numbers measured on a 14" MacBook Pro (macOS 26.7, 1512×982 points, notch from 663 to 848).
private let notched = MenuBarGeometry(displays: [
    MenuBarDisplay(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), barHeight: 32, drawableMinX: 848),
])

@Suite("Menu bar geometry")
struct MenuBarGeometryTests {
    @Test("Items entirely right of the notch are drawable")
    func rightOfNotch() {
        #expect(notched.isInDrawableArea(CGRect(x: 871, y: 0, width: 84, height: 32)))
        #expect(notched.isInDrawableArea(CGRect(x: 1311, y: 0, width: 201, height: 32)))
    }

    @Test("An item straddling the notch edge is not drawn")
    func straddlingNotch() {
        // Observed: x 827, width 44 reported off-screen.
        #expect(!notched.isInDrawableArea(CGRect(x: 827, y: 0, width: 44, height: 32)))
    }

    @Test("Items left of the notch, off screen, or zero-sized are not drawable", arguments: [
        CGRect(x: 111, y: 0, width: 40, height: 32),
        CGRect(x: -4000, y: 0, width: 30, height: 32),
        CGRect(x: 900, y: 0, width: 0, height: 0),
        CGRect(x: 900, y: 400, width: 30, height: 32),
    ])
    func notDrawable(frame: CGRect) {
        #expect(!notched.isInDrawableArea(frame))
    }

    @Test("Menu bar row membership uses the vertical centre and ignores x")
    func menuBarRow() {
        // Measured: items of apps switched off in System Settings report frames at the bottom-left corner.
        #expect(!notched.isInMenuBarRow(CGRect(x: -1, y: 981, width: 34, height: 24)))
        // Measured: a status item whose AX frame is taller than the bar (Foresight).
        #expect(notched.isInMenuBarRow(CGRect(x: 115, y: -24.5, width: 24, height: 82)))
        // Pushed off the screen by a separator, but still in the row.
        #expect(notched.isInMenuBarRow(CGRect(x: -4000, y: 4.5, width: 30, height: 24)))
    }

    @Test("A display without a notch draws from its left edge")
    func secondDisplay() {
        let geometry = MenuBarGeometry(displays: [
            MenuBarDisplay(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), barHeight: 32, drawableMinX: 848),
            MenuBarDisplay(frame: CGRect(x: 1512, y: -100, width: 1920, height: 1080), barHeight: 24, drawableMinX: 1512),
        ])
        #expect(geometry.isInDrawableArea(CGRect(x: 1600, y: -100, width: 30, height: 24)))
        #expect(geometry.display(at: CGPoint(x: 1600, y: -100))?.drawableMinX == 1512)
    }

    @Test("Cocoa rects flip to top-left coordinates")
    func cocoaConversion() {
        let primary = MenuBarGeometry.topLeftRect(fromCocoa: CGRect(x: 0, y: 0, width: 1512, height: 982), primaryMaxY: 982)
        #expect(primary == CGRect(x: 0, y: 0, width: 1512, height: 982))
        // A display above the primary one has a negative top-left y.
        let above = MenuBarGeometry.topLeftRect(fromCocoa: CGRect(x: 0, y: 982, width: 1920, height: 1080), primaryMaxY: 982)
        #expect(above.minY == -1080)
    }
}

@Suite("Status window matching")
struct StatusWindowMatcherTests {
    let windows = [
        StatusWindow(id: 1, frame: CGRect(x: 827, y: 0, width: 44, height: 32), isOnscreen: false),
        StatusWindow(id: 2, frame: CGRect(x: 871, y: 0, width: 84, height: 32), isOnscreen: true),
        StatusWindow(id: 3, frame: CGRect(x: 358, y: 33, width: 510, height: 300), isOnscreen: false),
    ]

    @Test("Matches the window whose centre lines up")
    func nearestCentre() {
        let match = StatusWindowMatcher.match(CGRect(x: 873, y: 0, width: 80, height: 24), in: windows)
        #expect(match?.id == 2)
    }

    @Test("Matches by centre even when the AX frame is taller than the window")
    func tallFrame() {
        let window = StatusWindow(id: 9, frame: CGRect(x: 111, y: 0, width: 40, height: 33), isOnscreen: false)
        #expect(StatusWindowMatcher.match(CGRect(x: 115, y: -24.5, width: 24, height: 82), in: [window])?.id == 9)
    }

    @Test("Ignores windows too far away or below the bar")
    func noMatch() {
        #expect(StatusWindowMatcher.match(CGRect(x: 600, y: 0, width: 30, height: 24), in: windows) == nil)
        #expect(StatusWindowMatcher.match(CGRect(x: 360, y: 0, width: 506, height: 24), in: windows) == nil)
    }

    @Test("The on-screen flag decides visibility when a window matched")
    func visibility() {
        let straddling = CGRect(x: 829, y: 0, width: 40, height: 24)
        #expect(!ItemVisibility.isDrawn(frame: straddling, window: windows[0], geometry: notched))
        #expect(ItemVisibility.isDrawn(frame: CGRect(x: 873, y: 0, width: 80, height: 24), window: windows[1], geometry: notched))
        // Without a window, geometry decides.
        #expect(!ItemVisibility.isDrawn(frame: straddling, window: nil, geometry: notched))
    }
}
