import AppKit
import WhiskyCore

extension MenuBarGeometry {
    /// The menu bars of all connected displays, read from NSScreen (main thread only).
    @MainActor
    static func current() -> MenuBarGeometry {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return MenuBarGeometry(displays: []) }
        let primaryMaxY = primary.frame.maxY
        return MenuBarGeometry(displays: screens.map { screen in
            let frame = MenuBarGeometry.topLeftRect(fromCocoa: screen.frame, primaryMaxY: primaryMaxY)
            let barHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : NSStatusBar.system.thickness
            var drawableMinX = frame.minX
            if let rightArea = screen.auxiliaryTopRightArea {
                // Documented as the screen's coordinate space. On the primary display that is also the
                // global space; if the value doesn't fall inside the screen's global span, treat it as local.
                let isGlobal = rightArea.minX >= screen.frame.minX - 0.5 && rightArea.maxX <= screen.frame.maxX + 0.5
                drawableMinX = isGlobal ? rightArea.minX : screen.frame.minX + rightArea.minX
            }
            return MenuBarDisplay(frame: frame, barHeight: barHeight, drawableMinX: drawableMinX)
        })
    }
}
