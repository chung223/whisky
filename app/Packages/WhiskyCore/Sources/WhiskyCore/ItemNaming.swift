import Foundation

/// Readable names for menu bar items. The AX label is often a live readout ("Memory 67%", "CPU 35%",
/// "Wi-Fi，3 格", or just "0"), which makes a poor name; the part before the first number or separator is kept when
/// it says something the app name doesn't.
public enum ItemNaming {
    /// The descriptive part of an AX label: cut at the first digit or separator, trimmed. nil when nothing useful is
    /// left (empty, a single character, or the app name again).
    public static func meaningfulLabel(_ label: String, appName: String) -> String? {
        let separators = CharacterSet(charactersIn: "，,:：;；|·•()（）[]")
        var kept = ""
        for scalar in label.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) || separators.contains(scalar) { break }
            kept.unicodeScalars.append(scalar)
        }
        let trimmed = kept.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—%")))
        guard trimmed.count >= 2, trimmed.caseInsensitiveCompare(appName) != .orderedSame else { return nil }
        return trimmed
    }

    /// The full name: "iStat Menus · Memory", or just the app name.
    /// - Parameter systemName: for Apple's own items, the name `SystemItemSymbols` knows.
    public static func displayName(appName: String, label: String, systemName: String? = nil) -> String {
        if let systemName { return systemName }
        guard let detail = meaningfulLabel(label, appName: appName) else { return appName }
        return "\(appName) · \(detail)"
    }

    /// A short name for a tile: the label's detail when the app has several items, otherwise the app name.
    public static func shortName(appName: String, label: String, systemName: String? = nil, appHasSeveralItems: Bool) -> String {
        if let systemName { return systemName }
        if appHasSeveralItems, let detail = meaningfulLabel(label, appName: appName) { return detail }
        return appName
    }
}
