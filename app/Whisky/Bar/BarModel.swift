import AppKit
import Observation
import WhiskyCore

struct BarItem: Identifiable {
    let scanned: ScannedItem
    let appIcon: NSImage?
    var glyph: Glyph?

    var id: String { scanned.id }

    var isOff: Bool { scanned.placement == .off }

    /// An SF Symbol for Apple's own items, whose owners' app icons say nothing about them.
    var symbol: String? {
        SystemItemSymbols.symbol(key: scanned.key, bundleID: scanned.bundleID)
            .flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil ? nil : $0 }
    }

    /// "iStat Menus · Memory", "Siri", "Surge": the app name, plus the item's own label when it says more.
    var displayName: String {
        ItemNaming.displayName(appName: scanned.appName, label: scanned.label,
                               systemName: SystemItemSymbols.name(key: scanned.key, bundleID: scanned.bundleID))
    }

    var tooltip: String { isOff ? "\(displayName)（不在選單列上）" : displayName }
}

/// The items macOS didn't draw, refreshed from AX scans.
@MainActor
@Observable
final class BarModel {
    private(set) var items: [BarItem] = []
    /// Third-party items macOS draws right now (what "send behind the notch" can act on).
    private(set) var shownItems: [ScannedItem] = []
    @ObservationIgnored private(set) var lastScan: [ScannedItem] = []
    private(set) var hasScanned = false
    /// Set by `LayoutMemory` when the run isn't as the user arranged it.
    var layoutDrift: LayoutDriftNotice?
    /// Typed while Whisky Bar is open: filters the items by app name, label or bundle ID.
    var query = "" { didSet { selection = 0 } }
    /// The highlighted item in `filteredItems` once the keyboard is used.
    var selection = 0
    var isUsingKeyboard = false
    /// The item under the pointer, named in the panel's footer.
    var hoveredID: String?
    /// The shortcut that opens Whisky Bar, shown in its search line (nil: none).
    var shortcutDisplay: String?

    /// What the footer names: the item under the pointer, else the keyboard's choice.
    var focusedItem: BarItem? {
        if let hoveredID, let item = items.first(where: { $0.id == hoveredID }) { return item }
        return isUsingKeyboard ? selectedItem : nil
    }

    var filteredItems: [BarItem] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return items }
        return items.filter { item in
            [item.scanned.appName, item.scanned.label, item.scanned.bundleID ?? ""].contains { $0.lowercased().contains(needle) }
        }
    }

    /// What Whisky Bar shows, in order: the most used items first, then the hidden ones, then the ones not in the
    /// menu bar. Each item appears once.
    struct Sections {
        var frequent: [BarItem] = []
        var hidden: [BarItem] = []
        var off: [BarItem] = []

        var all: [BarItem] { frequent + hidden + off }
    }

    var sections: Sections {
        let list = filteredItems
        let frequent = frequentKeys.compactMap { key in list.first { $0.scanned.key == key } }
        let frequentIDs = Set(frequent.map(\.id))
        let rest = list.filter { !frequentIDs.contains($0.id) }
        return Sections(frequent: frequent, hidden: rest.filter { !$0.isOff }, off: rest.filter(\.isOff))
    }

    var selectedItem: BarItem? {
        let list = sections.all
        return list.indices.contains(selection) ? list[selection] : nil
    }

    func moveSelection(by offset: Int) {
        let count = filteredItems.count
        guard count > 0 else { return }
        isUsingKeyboard = true
        selection = (selection + offset + count) % count
    }

    func resetSearch() {
        query = ""
        selection = 0
        isUsingKeyboard = false
        hoveredID = nil
    }
    var isAccessibilityTrusted = AXIsProcessTrusted()
    var showsRealImages: Bool {
        didSet { UserDefaults.standard.set(showsRealImages, forKey: "showsRealImages") }
    }

    /// The items opened most (and most recently) from Whisky Bar, shown first.
    private(set) var frequentKeys: [String] = []
    @ObservationIgnored private var uses: [String: [Date]] = [:]
    private static let usesKey = "itemUses"

    func recordUse(_ key: String) {
        uses[key] = UsageRanking.recording(Date(), in: uses[key] ?? [])
        let stored = uses.mapValues { $0.map(\.timeIntervalSince1970) }
        UserDefaults.standard.set(stored, forKey: Self.usesKey)
        updateFrequent()
    }

    private func updateFrequent() {
        let keys = Set(items.map(\.scanned.key))
        let top = UsageRanking.top(uses, among: keys, now: Date())
        // Only worth a row of its own when there's a crowd to skip.
        frequentKeys = items.count > 8 ? top : []
    }

    @ObservationIgnored private let scanner = MenuBarScanner()
    @ObservationIgnored private var isScanning = false
    @ObservationIgnored private var glyphCache: [String: (width: CGFloat, glyph: Glyph)] = [:]

    init() {
        showsRealImages = UserDefaults.standard.bool(forKey: "showsRealImages")
        if let stored = UserDefaults.standard.dictionary(forKey: Self.usesKey) as? [String: [Double]] {
            uses = stored.mapValues { $0.map(Date.init(timeIntervalSince1970:)) }
        }
    }

    func refresh(captureGlyphs: Bool) async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        isAccessibilityTrusted = AXIsProcessTrusted()
        guard isAccessibilityTrusted else {
            items = []
            return
        }
        let apps = Self.runningApps()
        let geometry = MenuBarGeometry.current()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let scanner = scanner
        let scanned = await Task.detached(priority: .userInitiated) {
            scanner.scan(apps: apps, geometry: geometry, ownPID: ownPID).items
        }.value

        lastScan = scanned
        shownItems = scanned.filter { $0.placement == .shown && !Self.isSystemOwned($0) && $0.windowID != nil }
        var icons: [pid_t: NSImage] = [:]
        items = scanned.filter { $0.placement != .shown }.map { item in
            let icon = icons[item.pid] ?? NSRunningApplication(processIdentifier: item.pid)?.icon
            icons[item.pid] = icon
            var glyph: Glyph?
            if showsRealImages, let cached = glyphCache[item.id], abs(cached.width - item.frame.width) < 0.5 {
                glyph = cached.glyph
            }
            return BarItem(scanned: item, appIcon: icon, glyph: glyph)
        }
        hasScanned = true
        updateFrequent()

        if captureGlyphs, showsRealImages {
            await captureMissingGlyphs()
        }
    }

    private func captureMissingGlyphs() async {
        let requests = items.compactMap { item -> (id: String, windowID: UInt32)? in
            guard item.glyph == nil, let windowID = item.scanned.windowID else { return nil }
            return (item.id, windowID)
        }
        let glyphs = await GlyphCapture.capture(requests)
        guard !glyphs.isEmpty else { return }
        for index in items.indices {
            guard let glyph = glyphs[items[index].id] else { continue }
            items[index].glyph = glyph
            glyphCache[items[index].id] = (items[index].scanned.frame.width, glyph)
        }
    }

    /// Writes a full scan (background-only processes included) to ~/Library/Logs/Whisky/diagnose.json.
    func writeDiagnostics() async {
        struct Entry: Encodable {
            let key: String
            let app: String
            let bundleID: String?
            let pid: Int32
            let frame: CGRect
            let placement: Placement
            let windowID: UInt32?
            let label: String
            /// The AX actions offered, and (only for items macOS didn't draw) the menu titles mirroring would show.
            let actions: [String]?
            let menu: [String]?
        }
        struct Report: Encodable {
            let date: Date
            let accessibility: Bool
            let screenRecording: Bool
            let displays: [String]
            let hiddenCount: Int
            let notInMenuBar: [String]
            let items: [Entry]
        }
        let apps = Self.runningApps()
        let geometry = MenuBarGeometry.current()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let (result, entries) = await Task.detached(priority: .utility) { () -> (ScanResult, [Entry]) in
            let result = MenuBarScanner().scan(apps: apps, geometry: geometry, ownPID: ownPID, includeBackgroundOnly: true)
            let entries = result.items.map { item -> Entry in
                // Reading a menu doesn't open it or press anything.
                let menu = item.placement == .shown ? nil : MenuMirror.read(item.element).map { entries in
                    entries.map { $0.kind == .separator ? "—" : ($0.kind == .unsupported ? "（自訂）" : $0.title) }
                }
                return Entry(
                    key: item.key, app: item.appName, bundleID: item.bundleID, pid: item.pid, frame: item.frame, placement: item.placement,
                    windowID: item.windowID, label: item.label,
                    actions: item.element.actionNames, menu: menu
                )
            }
            return (result, entries)
        }.value
        let scanned = result.items
        let report = Report(
            date: Date(),
            accessibility: AXIsProcessTrusted(),
            screenRecording: Permissions.hasScreenRecording,
            displays: geometry.displays.map { "frame \($0.frame) bar \($0.barHeight) drawableMinX \($0.drawableMinX)" },
            hiddenCount: scanned.filter { $0.placement != .shown }.count,
            notInMenuBar: result.notInMenuBar,
            items: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(report).write(to: Log.directory.appending(path: "diagnose.json"))
            Log.write("diagnostics: \(scanned.count) items, \(report.hiddenCount) hidden")
        } catch {
            Log.write("diagnostics failed: \(error.localizedDescription)")
        }
    }

    func item(forKey key: String) -> ScannedItem? {
        lastScan.first { $0.key == key }
    }

    /// Control Center's own modules (Wi-Fi, Control Center, the clock) and our own icon are not offered for moving.
    static func isSystemOwned(_ item: ScannedItem) -> Bool {
        item.bundleID == "com.apple.controlcenter"
    }

    private static func runningApps() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications.map { app in
            RunningAppInfo(
                pid: app.processIdentifier,
                bundleID: app.bundleIdentifier,
                name: app.localizedName ?? app.bundleIdentifier ?? "pid \(app.processIdentifier)",
                isBackgroundOnly: app.activationPolicy == .prohibited
            )
        }
    }
}
