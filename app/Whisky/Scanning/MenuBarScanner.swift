import ApplicationServices
import CoreGraphics
import Synchronization
import WhiskyCore

struct RunningAppInfo: Sendable {
    let pid: pid_t
    let bundleID: String?
    let name: String
    let isBackgroundOnly: Bool
}

enum Placement: String, Sendable, Encodable {
    /// Drawn in the menu bar.
    case shown
    /// In the menu bar row but not drawn: behind the notch or out of room.
    case hidden
    /// Not in the menu bar at all: its frame is elsewhere on the screen (hidden by another menu bar
    /// manager such as Bartender, or switched off in System Settings).
    case off
}

/// One status item, as read from its owner's `AXExtrasMenuBar`.
struct ScannedItem: Sendable, Identifiable {
    let id: String
    /// `<bundle ID>-<autosave name>`, the same form Bartender uses, stable across launches when the window name is
    /// readable (falls back to the item's index in its app).
    let key: String
    let pid: pid_t
    let bundleID: String?
    let appName: String
    let element: AXElement
    let frame: CGRect
    let label: String
    let windowID: UInt32?
    let windowName: String?
    let placement: Placement
}

extension ScannedItem {
    /// The same item with its autosave name filled in (and its key rebuilt from it).
    func named(_ name: String) -> ScannedItem {
        ScannedItem(id: id, key: "\(bundleID ?? "pid\(pid)")-\(name)", pid: pid, bundleID: bundleID, appName: appName,
                    element: element, frame: frame, label: label, windowID: windowID, windowName: name, placement: placement)
    }
}

struct ScanResult: Sendable {
    var items: [ScannedItem] = []
    /// Apps with status items that aren't in the menu bar at all (`Placement.off`).
    var notInMenuBar: [String] = []
}

/// Reads every app's status items through Accessibility.
///
/// Most running apps have no status item, and asking each one on every scan is what makes a naive
/// scan slow, so apps that answered "none" are only asked again every `recheckAfter` scans, with
/// staggered starting points so the rechecks don't all land on the same scan. A timeout is not the
/// same as "none": a busy app is retried soon instead of being forgotten for half a minute.
final class MenuBarScanner: Sendable {
    private static let recheckAfter = 15
    private static let retryAfterTimeout = 3
    private let skipCounts = Mutex<[pid_t: Int]>([:])

    func scan(apps: [RunningAppInfo], geometry: MenuBarGeometry, ownPID: pid_t, includeBackgroundOnly: Bool = false) -> ScanResult {
        guard AXIsProcessTrusted() else { return ScanResult() }
        let windows = WindowList.statusWindows()
        let livePIDs = Set(apps.map(\.pid))
        var skips = skipCounts.withLock { $0 }.filter { livePIDs.contains($0.key) }
        var result = ScanResult()

        for app in apps where app.pid != ownPID && (includeBackgroundOnly || !app.isBackgroundOnly) {
            if let remaining = skips[app.pid], remaining > 0 {
                skips[app.pid] = remaining - 1
                continue
            }
            let appElement = AXElement.application(app.pid)
            appElement.setTimeout(0.1)
            let extras = appElement.copy("AXExtrasMenuBar")
            if extras.error == .cannotComplete {
                skips[app.pid] = Self.retryAfterTimeout
                continue
            }
            guard extras.error == .success, let barValue = extras.value,
                  CFGetTypeID(barValue) == AXUIElementGetTypeID()
            else {
                skips[app.pid] = Int.random(in: 1...Self.recheckAfter)
                continue
            }
            let bar = AXElement(raw: barValue as! AXUIElement)
            bar.setTimeout(0.1)
            let children = bar.children
            guard !children.isEmpty else {
                skips[app.pid] = Int.random(in: 1...Self.recheckAfter)
                continue
            }
            skips[app.pid] = nil

            for (index, child) in children.enumerated() {
                child.setTimeout(0.25)
                // Zero-sized items are ones switched off in System Settings, or Control Center's
                // placeholders for modules the user removed. Neither belongs in the bar.
                guard let frame = child.frame, frame.width > 0, frame.height > 0 else { continue }
                let window = StatusWindowMatcher.match(frame, in: windows)
                let placement: Placement
                if window == nil, !geometry.isInMenuBarRow(frame) {
                    placement = .off
                    result.notInMenuBar.append(app.name)
                } else {
                    placement = ItemVisibility.isDrawn(frame: frame, window: window, geometry: geometry) ? .shown : .hidden
                }
                let label = child.string("AXHelp") ?? child.string("AXDescription") ?? child.string("AXTitle") ?? app.name
                let owner = app.bundleID ?? "pid\(app.pid)"
                result.items.append(ScannedItem(
                    id: "\(owner)#\(index)",
                    key: "\(owner)-\(window?.name ?? "Item-\(index)")",
                    pid: app.pid,
                    bundleID: app.bundleID,
                    appName: app.name,
                    element: child,
                    frame: frame,
                    label: label,
                    windowID: window?.id,
                    windowName: window?.name,
                    placement: placement
                ))
            }
        }

        skipCounts.withLock { $0 = skips }
        // Items in the bar go in menu bar order; items that are off have no meaningful x.
        let items = Self.inferringAutosaveNames(Self.removingWrappers(result.items))
        result.items = items.filter { $0.placement != .off }.sorted { $0.frame.minX < $1.frame.minX }
            + items.filter { $0.placement == .off }.sorted { $0.appName.localizedStandardCompare($1.appName) == .orderedAscending }
        return result
    }

    /// Without Screen Recording, window titles (the autosave names) are unreadable. For an app with several items in
    /// the menu bar, recover them from its `NSStatusItem Preferred Position <name>` defaults (see
    /// `AutosaveNameInference`); leave them alone when the app's defaults can't be read or don't line up.
    private static func inferringAutosaveNames(_ items: [ScannedItem]) -> [ScannedItem] {
        var result = items
        let groups = Dictionary(grouping: items.indices.filter { items[$0].placement != .off && items[$0].windowName == nil }) {
            items[$0].bundleID ?? ""
        }
        for (bundleID, indices) in groups where !bundleID.isEmpty && indices.count > 1 {
            let domain = bundleID as CFString
            let keys = (CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? [])
                .filter { $0.hasPrefix(AutosaveNameInference.positionKeyPrefix) }
            guard !keys.isEmpty,
                  let values = CFPreferencesCopyMultiple(keys as CFArray, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any],
                  let names = AutosaveNameInference.names(positions: AutosaveNameInference.positions(fromDefaults: values),
                                                          itemMinXs: indices.map { items[$0].frame.minX })
            else { continue }
            for (index, name) in zip(indices, names) { result[index] = items[index].named(name) }
        }
        return result
    }

    /// Control Center's AX tree repeats some third-party items as wrappers around the same window.
    /// When two items land on one window, keep the real owner.
    private static func removingWrappers(_ items: [ScannedItem]) -> [ScannedItem] {
        let controlCenter = "com.apple.controlcenter"
        var kept: [ScannedItem] = []
        var indexByWindow: [UInt32: Int] = [:]
        for item in items {
            guard let windowID = item.windowID else {
                kept.append(item)
                continue
            }
            if let index = indexByWindow[windowID] {
                if kept[index].bundleID == controlCenter, item.bundleID != controlCenter { kept[index] = item }
                continue
            }
            indexByWindow[windowID] = kept.count
            kept.append(item)
        }
        return kept
    }
}
