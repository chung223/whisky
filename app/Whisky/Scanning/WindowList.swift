import CoreGraphics
import Foundation
import WhiskyCore

/// CGWindowList queries. Bounds, layers, owner PIDs and the on-screen flag need no permission;
/// only window titles are gated by Screen Recording.
enum WindowList {
    private struct Info {
        let id: UInt32
        let layer: Int
        let frame: CGRect
        let isOnscreen: Bool
        let ownerPID: pid_t
        let name: String?
    }

    /// Status item windows in the menu bar row (popovers share the layer, so tall windows are dropped).
    static func statusWindows() -> [StatusWindow] {
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        return windows(onScreenOnly: false).compactMap { info in
            guard info.layer == statusLevel, info.frame.width > 0, info.frame.height <= 60 else { return nil }
            return StatusWindow(id: info.id, frame: info.frame, isOnscreen: info.isOnscreen, name: info.name)
        }
    }

    /// Frames of status item windows by window ID. With `inMenuBarRowOnly`, only windows in the primary display's menu
    /// bar row (a lifted item jumps to the pointer but stays in the row; popovers sit below it).
    static func statusFrames(inMenuBarRowOnly: Bool = false) -> [UInt32: CGRect] {
        var frames: [UInt32: CGRect] = [:]
        for window in statusWindows() where !inMenuBarRowOnly || (window.frame.midY >= -1 && window.frame.midY < 40) {
            frames[window.id] = window.frame
        }
        return frames
    }

    /// On-screen windows owned by `pid` (popovers, menus and panels an app opened).
    static func onscreenWindowIDs(ownedBy pid: pid_t) -> Set<UInt32> {
        Set(windows(onScreenOnly: true).filter { $0.ownerPID == pid }.map(\.id))
    }

    static func onscreenWindowIDs() -> Set<UInt32> {
        Set(windows(onScreenOnly: true).map(\.id))
    }

    /// Every on-screen window, for telling what an item opened (`PopupDetection`).
    static func onscreenWindows() -> [PopupDetection.Window] {
        windows(onScreenOnly: true).map { PopupDetection.Window(id: $0.id, pid: $0.ownerPID, layer: $0.layer, frame: $0.frame) }
    }

    /// Whether any app has a menu open (menus sit exactly at the pop-up menu level; some apps keep
    /// unrelated windows at higher levels all the time, so "at least" would always be true).
    static func isMenuOpen() -> Bool {
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        // Some apps keep a tiny window at this level all the time (Cloudflare WARP: 20 × 1 pt in a corner), so only
        // windows big enough to be a menu count.
        return windows(onScreenOnly: true).contains { $0.layer == menuLevel && $0.frame.width >= 40 && $0.frame.height >= 20 }
    }

    private static func windows(onScreenOnly: Bool) -> [Info] {
        let options: CGWindowListOption = onScreenOnly ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionAll, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { window in
            guard let number = window[kCGWindowNumber as String] as? Int,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return Info(
                id: UInt32(truncatingIfNeeded: number),
                layer: layer,
                frame: frame,
                isOnscreen: window[kCGWindowIsOnscreen as String] as? Bool ?? false,
                ownerPID: pid_t(window[kCGWindowOwnerPID as String] as? Int ?? 0),
                name: window[kCGWindowName as String] as? String
            )
        }
    }
}
