import CoreGraphics

/// A status item's backing window as CGWindowList reports it. Reading bounds and the on-screen flag
/// needs no permission. On macOS 26 every one of these windows is owned by Control Center.
public struct StatusWindow: Sendable, Equatable {
    public var id: UInt32
    public var frame: CGRect
    public var isOnscreen: Bool
    public var name: String?

    public init(id: UInt32, frame: CGRect, isOnscreen: Bool, name: String? = nil) {
        self.id = id
        self.frame = frame
        self.isOnscreen = isOnscreen
        self.name = name
    }
}

public enum StatusWindowMatcher {
    /// The window whose centre is nearest the AX frame's, within `tolerance` horizontally.
    /// The window is a little larger than the AX element, but their centres line up.
    public static func match(_ frame: CGRect, in windows: [StatusWindow], tolerance: CGFloat = 4) -> StatusWindow? {
        var best: StatusWindow?
        var bestDistance = CGFloat.infinity
        for window in windows where abs(window.frame.midY - frame.midY) <= 8 {
            let distance = abs(window.frame.midX - frame.midX)
            if distance <= tolerance, distance < bestDistance {
                best = window
                bestDistance = distance
            }
        }
        return best
    }
}

public enum ItemVisibility {
    /// Whether macOS actually drew the item. The window's on-screen flag is the ground truth when we
    /// found the window; otherwise fall back to geometry.
    public static func isDrawn(frame: CGRect, window: StatusWindow?, geometry: MenuBarGeometry) -> Bool {
        if let window {
            return window.isOnscreen && geometry.display(at: CGPoint(x: frame.midX, y: frame.midY)) != nil
        }
        return geometry.isInDrawableArea(frame)
    }
}
