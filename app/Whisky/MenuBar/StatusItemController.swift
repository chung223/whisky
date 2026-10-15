import AppKit

/// Whisky's own icon in the menu bar. Left click toggles the bar; right click (or ⌃-click) shows the menu.
///
/// When the glass lives in the notch it leaves the menu bar between moves. It is removed and created again rather
/// than hidden with `isVisible`: hiding makes AppKit forget the item's place (measured 2026-10-15: shown again, it
/// came back at the far left, behind the notch), while a new item is put where its saved position says.
@MainActor
final class StatusItemController: NSObject {
    static let autosaveName = "WhiskyIcon"
    private static let positionKey = "NSStatusItem Preferred Position \(autosaveName)"
    /// Whisky's own copy of the glass's place: AppKit deletes its key when the item is removed, and a relaunch would
    /// then take the glass for new (measured 2026-10-16: position 237 before a relaunch, 0 after).
    private static let savedPositionKey = "glassPosition"

    var onToggleBar: (() -> Void)?
    var menuProvider: (() -> NSMenu)?

    private var statusItem: NSStatusItem?
    private var glass: GlassAnimator?
    private var isBarOpen = false
    /// The place to put the glass back at (AppKit's distance from the right end).
    private var savedPosition: Double

    override init() {
        // On first launch ask for the rightmost third-party slot (0 = distance from the right end), so the icon lands
        // next to Control Center instead of behind the notch. After that, the user's own ⌘-drag position wins.
        let stored = UserDefaults.standard.object(forKey: Self.savedPositionKey) as? Double
            ?? UserDefaults.standard.object(forKey: Self.positionKey) as? Double
        savedPosition = stored ?? 0
        UserDefaults.standard.set(savedPosition, forKey: Self.savedPositionKey)
        super.init()
        create()
    }

    private func create() {
        UserDefaults.standard.set(savedPosition, forKey: Self.positionKey)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = Self.autosaveName
        statusItem = item
        guard let button = item.button else { return }
        glass = GlassAnimator(button: button)
        if isBarOpen { glass?.setFull(true) }
        button.toolTip = "Whisky：被瀏海擋住的圖示"
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Whether the glass is in the menu bar now.
    var isShown: Bool { statusItem != nil }

    /// Puts the glass in the menu bar (where it was) or takes it out.
    func setShown(_ shown: Bool) {
        guard shown != isShown else { return }
        if shown {
            create()
        } else if let item = statusItem {
            // Its current place, in case the user moved it.
            if let position = UserDefaults.standard.object(forKey: Self.positionKey) as? Double {
                savedPosition = position
                UserDefaults.standard.set(position, forKey: Self.savedPositionKey)
            }
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            glass = nil
            UserDefaults.standard.set(savedPosition, forKey: Self.positionKey)
        }
        Log.write("glass: \(shown ? "shown" : "hidden") (position \(Int(savedPosition)))")
    }

    /// The icon's frame in screen coordinates.
    var buttonFrame: NSRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// The icon window's number, when it fits a CGWindowID. On macOS 26 the menu bar windows belong to Control
    /// Center and the app-side number can be out of range (measured: larger than UInt32), so callers fall back to
    /// matching the icon's frame.
    var windowID: UInt32? {
        statusItem?.button?.window.flatMap { UInt32(exactly: $0.windowNumber) }
    }

    /// Whisky Bar opened or closed: pour the glass full, or empty it.
    func setBarOpen(_ open: Bool) {
        isBarOpen = open
        statusItem?.button?.highlight(open)
        glass?.setFull(open)
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            onToggleBar?()
        }
    }

    private func showMenu() {
        guard let menu = menuProvider?(), let statusItem else { return }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
