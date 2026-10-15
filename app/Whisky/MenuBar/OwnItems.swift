import AppKit
import WhiskyCore

/// Creates Whisky's own extra status items and learns their window IDs reliably.
///
/// On macOS 26 the menu bar windows belong to Control Center and the app-side window number is not the listed one.
/// Matching by the button's frame works for an item that is drawn and doesn't change size (Whisky's icon), but went
/// wrong for the spacer behind the notch while it was resizing. So instead: list the status windows, create the item,
/// and take the window that appeared. Window IDs stay the same for the item's lifetime.
@MainActor
enum OwnItems {
    static func create(length: CGFloat, autosaveName: String?, configure: (NSStatusItem) -> Void) async -> (item: NSStatusItem, windowID: UInt32?) {
        let before = Set(WindowList.statusWindows().map(\.id))
        let item = NSStatusBar.system.statusItem(withLength: length)
        if let autosaveName { item.autosaveName = autosaveName }
        configure(item)
        for _ in 0..<40 {
            try? await Task.sleep(for: .milliseconds(50))
            let fresh = WindowList.statusWindows().filter { !before.contains($0.id) }
            if fresh.count == 1 { return (item, fresh[0].id) }
            if fresh.count > 1 {
                // Another app created an item at the same moment: take the one nearest our button.
                let id = nearest(to: item, among: fresh)
                Log.write("own item: \(fresh.count) new windows at once, picked \(id.map(String.init) ?? "none")")
                return (item, id)
            }
        }
        Log.write("own item: no new window appeared for \(autosaveName ?? "an item")")
        return (item, nil)
    }

    private static func nearest(to item: NSStatusItem, among windows: [StatusWindow]) -> UInt32? {
        guard let button = item.button, let window = button.window, let primary = NSScreen.screens.first else { return windows.first?.id }
        let cocoa = window.convertToScreen(button.convert(button.bounds, to: nil))
        let frame = MenuBarGeometry.topLeftRect(fromCocoa: cocoa, primaryMaxY: primary.frame.maxY)
        return windows.min { abs($0.frame.midX - frame.midX) < abs($1.frame.midX - frame.midX) }?.id
    }
}
