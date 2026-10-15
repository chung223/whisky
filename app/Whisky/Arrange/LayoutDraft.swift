import AppKit
import Observation
import WhiskyCore

/// The arrangement being edited: which items should be visible (left to right) and which go behind the notch.
/// Nothing moves until it is applied.
@MainActor
@Observable
final class LayoutDraft {
    struct Entry: Identifiable, Equatable {
        let item: ScannedItem
        let width: CGFloat
        let icon: NSImage?
        /// A tile's caption: the app name, or the item's own label when the app has several items ("Memory").
        let title: String
        /// "iStat Menus · Memory", for tooltips.
        let tooltip: String
        let symbol: String?

        var id: String { item.key }

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    }

    enum Status: Equatable {
        case idle
        case applying(done: Int, total: Int)
        case finished(moves: Int)
        case failed(String)
    }

    private(set) var visible: [Entry] = []
    private(set) var hidden: [Entry] = []
    private(set) var off: [Entry] = []
    /// Right of Whisky's icon (Control Center, the clock): shown for context, can't be moved.
    private(set) var fixed: [Entry] = []
    /// Captured images by item key (with Screen Recording); tiles fall back to symbols and app icons.
    var glyphs: [String: Glyph] = [:]
    /// Points between the notch and Whisky's icon.
    private(set) var capacity: CGFloat = 0
    var status: Status = .idle
    var note: String?
    /// The menu bar was hidden when this was read (a full-screen app): every item looks hidden, so nothing can be
    /// arranged until it shows again.
    private(set) var isMenuBarHidden = false

    @ObservationIgnored private var savedVisible: [String] = []

    var usedWidth: CGFloat { visible.reduce(0) { $0 + $1.width } }
    var overflowCount: Int { LayoutPlanner.overflowCount(widths: visible.map(\.width), capacity: capacity) }
    var hasChanges: Bool { visible.map(\.id) != savedVisible }
    var isApplying: Bool { if case .applying = status { true } else { false } }

    /// Builds the draft from a fresh scan: items left of Whisky's icon are editable; items right of it (Control
    /// Center, the clock) are fixed; items not in the menu bar at all are listed but can't be placed.
    func load(scan: [ScannedItem], anchorFrame: CGRect?, drawableMinX: CGFloat, menuBarShown: Bool = true) {
        isMenuBarHidden = !menuBarShown
        let frames = WindowList.statusFrames(inMenuBarRowOnly: true)
        var icons: [pid_t: NSImage] = [:]
        let itemsPerApp = Dictionary(grouping: scan, by: \.pid).mapValues(\.count)
        func entry(_ item: ScannedItem) -> Entry {
            let icon = icons[item.pid] ?? NSRunningApplication(processIdentifier: item.pid)?.icon
            icons[item.pid] = icon
            let width = item.windowID.flatMap { frames[$0]?.width } ?? item.frame.width
            let systemName = SystemItemSymbols.name(key: item.key, bundleID: item.bundleID)
            return Entry(
                item: item, width: width, icon: icon,
                title: ItemNaming.shortName(appName: item.appName, label: item.label, systemName: systemName,
                                            appHasSeveralItems: (itemsPerApp[item.pid] ?? 0) > 1),
                tooltip: ItemNaming.displayName(appName: item.appName, label: item.label, systemName: systemName),
                symbol: SystemItemSymbols.symbol(key: item.key, bundleID: item.bundleID)
                    .flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil ? nil : $0 }
            )
        }
        let anchorMinX = anchorFrame?.minX ?? .infinity
        let movable = scan.filter { $0.placement != .off && $0.windowID != nil && $0.frame.minX < anchorMinX }
        visible = movable.filter { $0.placement == .shown }.sorted { $0.frame.minX < $1.frame.minX }.map(entry)
        hidden = movable.filter { $0.placement == .hidden }.sorted { $0.frame.minX < $1.frame.minX }.map(entry)
        off = scan.filter { $0.placement == .off }.map(entry)
        fixed = scan.filter { $0.placement == .shown && $0.frame.minX >= anchorMinX - 1 }.sorted { $0.frame.minX < $1.frame.minX }.map(entry)
        capacity = anchorFrame.map { max(0, $0.minX - drawableMinX) } ?? 0
        savedVisible = visible.map(\.id)
    }

    /// Puts the item in the visible run, just left of `beforeKey` (nil: at the right end, next to Whisky's icon).
    func showItem(_ key: String, before beforeKey: String? = nil) {
        guard !isApplying, key != beforeKey, let entry = take(key) else { return }
        if let beforeKey, let index = visible.firstIndex(where: { $0.id == beforeKey }) {
            visible.insert(entry, at: index)
        } else {
            visible.append(entry)
        }
    }

    func hideItem(_ key: String) {
        guard !isApplying, visible.contains(where: { $0.id == key }), let entry = take(key) else { return }
        hidden.insert(entry, at: 0)
    }

    /// Replaces the visible run with these keys, in order (unknown keys are skipped); everything else is hidden.
    func setVisible(_ keys: [String]) {
        guard !isApplying else { return }
        let all = visible + hidden
        let chosen = keys.compactMap { key in all.first { $0.id == key } }
        let chosenKeys = Set(chosen.map(\.id))
        visible = chosen
        hidden = all.filter { !chosenKeys.contains($0.id) }.sorted { $0.item.frame.minX < $1.item.frame.minX }
    }

    private func take(_ key: String) -> Entry? {
        if let index = visible.firstIndex(where: { $0.id == key }) { return visible.remove(at: index) }
        if let index = hidden.firstIndex(where: { $0.id == key }) { return hidden.remove(at: index) }
        return nil
    }
}

/// Reads the layout Bartender saved: `ProfileSettings.activeProfile.Show`, a list of `<bundle ID>-<autosave name>`.
/// 【推論】The list runs right to left (its first entry is the rightmost item): on the machine it was read from, the
/// items still in place appeared in exactly the reverse order.
enum BartenderLayout {
    private static let domains = ["com.surteesstudios.Bartender-setapp", "com.surteesstudios.Bartender"]

    static func shownEntries() -> [String]? {
        for domain in domains {
            guard let profiles = CFPreferencesCopyAppValue("ProfileSettings" as CFString, domain as CFString) as? [String: Any],
                  let active = profiles["activeProfile"] as? [String: Any],
                  let show = active["Show"] as? [String]
            else { continue }
            return show
        }
        return nil
    }

    /// The draft's keys for Bartender's shown items, left to right, and how many entries found no item.
    static func visibleKeys(for items: [ScannedItem]) -> (keys: [String], unmatched: Int)? {
        guard let entries = shownEntries() else { return nil }
        let candidates = items.compactMap { item -> BartenderMatcher.Candidate? in
            guard let bundleID = item.bundleID else { return nil }
            return BartenderMatcher.Candidate(key: item.key, bundleID: bundleID, windowName: item.windowName, label: item.label)
        }
        let matches = BartenderMatcher.match(entries, candidates: candidates)
        let keys = matches.compactMap { $0 }
        return (Array(keys.reversed()), matches.count - keys.count)
    }
}
