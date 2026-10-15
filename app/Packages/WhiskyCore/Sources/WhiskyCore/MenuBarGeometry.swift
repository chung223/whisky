import CoreGraphics

/// One display's menu bar, in global top-left coordinates (the space AX and CGWindowList use:
/// origin at the top-left of the primary display, y growing downward).
public struct MenuBarDisplay: Sendable, Equatable {
    public var frame: CGRect
    public var barHeight: CGFloat
    /// Leftmost x at which macOS draws status items. On a notched display this is the notch's right edge;
    /// macOS only draws items that sit entirely to the right of it.
    public var drawableMinX: CGFloat

    public init(frame: CGRect, barHeight: CGFloat, drawableMinX: CGFloat) {
        self.frame = frame
        self.barHeight = barHeight
        self.drawableMinX = drawableMinX
    }
}

public struct MenuBarGeometry: Sendable, Equatable {
    public var displays: [MenuBarDisplay]

    public init(displays: [MenuBarDisplay]) {
        self.displays = displays
    }

    /// The display whose menu bar row contains `point`.
    public func display(at point: CGPoint) -> MenuBarDisplay? {
        displays.first { display in
            point.x >= display.frame.minX && point.x < display.frame.maxX
                && point.y >= display.frame.minY - 1 && point.y < display.frame.minY + display.barHeight
        }
    }

    /// Whether the frame sits in some display's menu bar row, judged by its vertical centre (some items
    /// report frames taller than the bar). x is ignored: items pushed off the screen are still in the row.
    /// Items whose app was switched off in System Settings report frames elsewhere (e.g. the bottom-left
    /// corner of the screen).
    public func isInMenuBarRow(_ frame: CGRect) -> Bool {
        displays.contains { display in
            frame.midY >= display.frame.minY - 1 && frame.midY < display.frame.minY + display.barHeight
        }
    }

    /// Whether an item with this frame lies entirely inside the span where macOS draws status items.
    /// Items pushed past the notch or off the screen report plausible-looking frames, so the frame
    /// alone never proves an item is visible; this only rules items out.
    public func isInDrawableArea(_ frame: CGRect) -> Bool {
        guard frame.width > 0, frame.height > 0,
              let display = display(at: CGPoint(x: frame.midX, y: frame.midY))
        else { return false }
        return frame.minX >= display.drawableMinX && frame.maxX <= display.frame.maxX + 0.5
    }

    /// Converts a Cocoa rect (bottom-left origin) to global top-left coordinates.
    /// `primaryMaxY` is the height of the primary display, whose Cocoa origin is (0, 0).
    public static func topLeftRect(fromCocoa rect: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }
}
