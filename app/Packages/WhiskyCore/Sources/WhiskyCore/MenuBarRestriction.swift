import Foundation

/// macOS 27 draws the whole menu bar itself and lets no one move items, but it can be restricted to a list of apps
/// (system items always stay). Whisky's arrangement becomes that list: the apps with an item in the active preset are
/// allowed, the other apps Whisky knows to have items are left out and opened from Whisky Bar instead.
///
/// Apps Whisky has never seen with an item are allowed too: an app left out isn't drawn, and if Whisky doesn't know
/// it has an item, it couldn't list it in Whisky Bar either. Everything left out of the menu bar is in Whisky Bar.
public enum MenuBarRestriction {
    /// Allowed whatever the arrangement: the menu bar's own agent (without it the clock stops opening Notification
    /// Center) and Whisky.
    public static let alwaysAllowed: Set<String> = ["com.apple.MenuBarAgent", "com.chung.whisky"]
    /// Never put in the list: Control Center's modules are system items, allowed on their own, and listing Control
    /// Center itself as an app changes nothing for them.
    public static let neverListed: Set<String> = ["com.apple.controlcenter"]

    /// The app a key like `<bundle ID>-<autosave name>` belongs to. Bundle IDs can contain "-" themselves
    /// (`com.bjango.istatmenus-setapp.status-com.bjango.istatmenus.memory`), so the longest prefix that is a bundle
    /// ID on this Mac wins; failing that, the part before "-Item-" (AppKit's default autosave name), else the part
    /// before the last "-".
    public static func bundleID(ofKey key: String, isBundleID: (String) -> Bool) -> String? {
        guard !key.hasPrefix("-") else { return nil }
        let dashes = key.indices.filter { key[$0] == "-" }
        for dash in dashes.reversed() {
            let prefix = String(key[..<dash])
            if isBundleID(prefix) { return prefix }
        }
        if let range = key.range(of: "-Item-", options: .backwards), range.lowerBound > key.startIndex {
            return String(key[..<range.lowerBound])
        }
        guard let last = dashes.last, last > key.startIndex else { return nil }
        return String(key[..<last])
    }

    /// The apps the menu bar is restricted to.
    /// - Parameters:
    ///   - arranged: the apps with an item in the arrangement.
    ///   - known: every app Whisky has seen with an item.
    ///   - running: the apps running now (the ones never seen with an item stay allowed).
    public static func allowed(arranged: Set<String>, known: Set<String>, running: Set<String>) -> Set<String> {
        arranged.union(running.subtracting(known)).union(alwaysAllowed).subtracting(neverListed)
    }

    /// The apps left out of the menu bar: known to have an item and not allowed.
    public static func hidden(known: Set<String>, allowed: Set<String>) -> Set<String> {
        known.subtracting(allowed).subtracting(neverListed).subtracting(alwaysAllowed)
    }

    /// A name for a remembered item of a hidden app: the autosave name's last part when the app named it
    /// (`com.bjango.istatmenus.memory` → "memory"); nil for AppKit's default (`Item-0`).
    public static func itemName(ofKey key: String, bundleID: String) -> String? {
        guard key.hasPrefix(bundleID + "-") else { return nil }
        let autosave = String(key.dropFirst(bundleID.count + 1))
        guard !autosave.isEmpty, !autosave.hasPrefix("Item-") else { return nil }
        return autosave.split(separator: ".").last.map(String.init)
    }
}
