import CoreGraphics

/// Recognises what a menu bar item opened (a dropdown, popover or menu) among the windows that appeared after it was
/// clicked. Checking only the item owner's windows isn't enough: some apps draw their dropdown from another process.
public enum PopupDetection {
    public struct Window: Equatable, Sendable {
        public let id: UInt32
        public let pid: Int32
        public let layer: Int
        /// Global top-left coordinates, as CGWindowList reports them.
        public let frame: CGRect

        public init(id: UInt32, pid: Int32, layer: Int, frame: CGRect) {
            self.id = id
            self.pid = pid
            self.layer = layer
            self.frame = frame
        }
    }

    /// The windows among `new` that hang from the menu bar near the item: their top within `reach` of the menu bar's
    /// bottom edge, horizontally within `reach` of the item, big enough to be a panel. Other status items and the
    /// excluded process's windows (Whisky's own) don't count.
    public static func popups(among new: [Window], itemMidX: CGFloat, menuBarHeight: CGFloat, statusLevel: Int,
                              excludingPID: Int32? = nil, reach: CGFloat = 420) -> [Window] {
        new.filter { window in
            if let excludingPID, window.pid == excludingPID { return false }
            let frame = window.frame
            let isStatusItem = window.layer == statusLevel && frame.height <= 60 && frame.midY < menuBarHeight + 8
            guard !isStatusItem, frame.width >= 40, frame.height >= 20 else { return false }
            guard frame.minY <= menuBarHeight + 60 else { return false }
            let horizontalGap = max(0, frame.minX - itemMidX, itemMidX - frame.maxX)
            return horizontalGap <= reach
        }
    }
}
