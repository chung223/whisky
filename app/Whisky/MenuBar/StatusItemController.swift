import AppKit

/// Whisky's own icon in the menu bar. Left click toggles the bar; right click (or ⌃-click) shows the menu.
@MainActor
final class StatusItemController: NSObject {
    static let autosaveName = "WhiskyIcon"

    var onToggleBar: (() -> Void)?
    var menuProvider: (() -> NSMenu)?

    private let statusItem: NSStatusItem
    private var glass: GlassAnimator?

    override init() {
        // On first launch ask for the rightmost third-party slot (0 = distance from the right end),
        // so the icon lands next to Control Center instead of behind the notch. After that, the
        // user's own ⌘-drag position wins.
        let positionKey = "NSStatusItem Preferred Position \(Self.autosaveName)"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(0.0, forKey: positionKey)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.autosaveName = Self.autosaveName

        guard let button = statusItem.button else { return }
        glass = GlassAnimator(button: button)
        button.toolTip = "Whisky：被瀏海擋住的圖示"
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// The icon's frame in screen coordinates.
    var buttonFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// The icon window's number, when it fits a CGWindowID. On macOS 26 the menu bar windows belong to Control
    /// Center and the app-side number can be out of range (measured: larger than UInt32), so callers fall back to
    /// matching the icon's frame.
    var windowID: UInt32? {
        statusItem.button?.window.flatMap { UInt32(exactly: $0.windowNumber) }
    }

    /// Whisky Bar opened or closed: pour the glass full, or empty it.
    func setBarOpen(_ open: Bool) {
        statusItem.button?.highlight(open)
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
        guard let menu = menuProvider?() else { return }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
