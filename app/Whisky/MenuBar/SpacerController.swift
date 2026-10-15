import AppKit
import WhiskyCore

/// Whisky's spacer: an empty status item at the left end of the visible run, as long as AppKit allows (macOS 26 clamps
/// the window to about 5,000 pt). Everything left of it is pushed off the screen, so only the run is shown no matter
/// how much room there is. This is the separator Ice, Bartender and Frost use on macOS 26.
///
/// An earlier version sized the spacer to just fill the gap up to the notch; on a notched MacBook Pro that turned out
/// unstable (macOS repacks items around the notch and reports transient states while doing so), see
/// wiki/concepts/platform-verification.md. A fixed length needs no adjusting at all.
///
/// Safety: the spacer's window ID is learned when it is created (never guessed from positions). When Whisky quits the
/// spacer goes with it and every item comes back (fail-open). Clicking the empty part of it opens Whisky Bar.
@MainActor
final class SpacerController: NSObject {
    static let autosaveName = "WhiskySpacer"
    static let length: CGFloat = 10_000
    private static let enabledKey = "spacerEnabled"

    var onClick: (() -> Void)?

    private(set) var statusItem: NSStatusItem?
    private(set) var windowID: UInt32?

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var isActive: Bool { statusItem != nil && windowID != nil }

    /// At launch the spacer is created already expanded. Created 1 pt wide it landed at the notch boundary and macOS
    /// swapped it with its left neighbour, so every launch needed the run put back; created expanded it came back in
    /// place (measured 2026-10-16, two relaunches in a row, no moves). `spacerCreatedExpanded = false` restores the old way.
    static var createsExpandedAtLaunch: Bool { UserDefaults.standard.object(forKey: "spacerCreatedExpanded") as? Bool ?? true }

    /// Creates the spacer if it is enabled (its autosave position puts it back where it was).
    func start() async {
        if isEnabled, statusItem == nil { await create(expanded: Self.createsExpandedAtLaunch) }
    }

    func create(expanded: Bool = false) async {
        guard statusItem == nil else { return }
        // Normally created short, so learning its window doesn't push anything around; lengthened once known.
        let result = await OwnItems.create(length: expanded ? Self.length : 1, autosaveName: Self.autosaveName) { item in
            guard let button = item.button else { return }
            button.title = ""
            button.image = nil
            button.toolTip = "Whisky 分隔項目：點這裡打開 Whisky Bar"
            button.setAccessibilityLabel("Whisky 分隔項目")
            (button.cell as? NSButtonCell)?.highlightsBy = []
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = result.item
        windowID = result.windowID
        Log.write("spacer: created\(expanded ? " expanded" : ""), window \(result.windowID.map(String.init) ?? "unknown")")
    }

    /// Pushes everything left of the spacer off the screen (or, collapsed, lets it all back).
    func setExpanded(_ expanded: Bool) {
        guard let item = statusItem else { return }
        item.length = expanded ? Self.length : 1
        Log.write("spacer: \(expanded ? "expanded" : "collapsed")")
    }

    var isExpanded: Bool { (statusItem?.length ?? 0) > 1 }

    func remove() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        windowID = nil
        Log.write("spacer: removed")
    }

    @objc private func clicked() { onClick?() }

    /// The spacer's window if it is still listed.
    func currentWindowID(in windows: [StatusWindow] = WindowList.statusWindows()) -> UInt32? {
        guard let id = windowID, windows.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    var summary: String {
        "spacer window \(windowID.map(String.init) ?? "none"), length \(Int(statusItem?.length ?? 0))"
    }
}
