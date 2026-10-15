import AppKit
import WhiskyCore

/// One entry of a status item's menu, read through AX without opening the menu.
final class MirrorEntry: @unchecked Sendable {
    let element: AXElement
    let kind: MenuItemKind
    let title: String
    let isEnabled: Bool
    let isChecked: Bool
    let shortcut: MenuShortcut?
    let submenu: [MirrorEntry]?

    init(element: AXElement, kind: MenuItemKind, title: String, isEnabled: Bool, isChecked: Bool, shortcut: MenuShortcut?, submenu: [MirrorEntry]?) {
        self.element = element
        self.kind = kind
        self.title = title
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.shortcut = shortcut
        self.submenu = submenu
    }
}

/// Reads a status item's menu out of its owner app. A status item macOS didn't draw can't open its
/// own menu (there is nothing on screen to anchor it to), but the menu's entries can still be listed
/// and pressed one by one, so we rebuild the menu ourselves and forward the choice.
enum MenuMirror {
    private static let maxDepth = 4

    /// The menu's entries, or nil when the item has no menu (popover-style items) or it is empty.
    static func read(_ item: AXElement, budget: Duration = .milliseconds(1500)) -> [MirrorEntry]? {
        let deadline = ContinuousClock.now + budget
        item.setTimeout(0.3)
        guard let menu = item.children.first(where: { $0.role == "AXMenu" }) else { return nil }
        let entries = read(menu: menu, depth: 0, deadline: deadline)
        return entries.contains(where: { $0.kind == .item }) ? entries : nil
    }

    private static func read(menu: AXElement, depth: Int, deadline: ContinuousClock.Instant) -> [MirrorEntry] {
        menu.setTimeout(0.3)
        var entries: [MirrorEntry] = []
        for element in menu.children {
            guard ContinuousClock.now < deadline else { break }
            element.setTimeout(0.3)
            guard element.role == "AXMenuItem" else { continue }
            let title = (element.string("AXTitle") ?? "").trimmingCharacters(in: .whitespaces)
            let children = element.children
            let submenuElement = children.first { $0.role == "AXMenu" }
            let kind = MenuItemKind.classify(title: title, hasSubmenu: submenuElement != nil, childCount: children.count)
            var submenu: [MirrorEntry]?
            if let submenuElement, depth < maxDepth {
                submenu = read(menu: submenuElement, depth: depth + 1, deadline: deadline)
            }
            entries.append(MirrorEntry(
                element: element,
                kind: kind,
                title: title,
                isEnabled: element.bool("AXEnabled") ?? true,
                isChecked: !(element.string("AXMenuItemMarkChar") ?? "").isEmpty,
                shortcut: MenuShortcut(cmdChar: element.string("AXMenuItemCmdChar"), axModifiers: element.int("AXMenuItemCmdModifiers")),
                submenu: submenu
            ))
        }
        return entries
    }
}

/// Builds the NSMenu copy and presses the real entry when one is chosen.
@MainActor
final class MirroredMenuController: NSObject {
    private final class Item: NSMenuItem {
        var entry: MirrorEntry?
    }

    func makeMenu(appName: String, entries: [MirrorEntry]) -> NSMenu {
        let menu = NSMenu(title: appName)
        // Copy the owner app's enabled states as they are; AppKit's own validation would grey out
        // everything whose action it can't find here.
        menu.autoenablesItems = false
        let header = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        populate(menu, with: entries)
        return menu
    }

    private func populate(_ menu: NSMenu, with entries: [MirrorEntry]) {
        menu.autoenablesItems = false
        for entry in entries {
            switch entry.kind {
            case .separator:
                if menu.items.last?.isSeparatorItem == false { menu.addItem(.separator()) }
            case .unsupported:
                let item = NSMenuItem(title: "（無法顯示的自訂項目）", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            case .item:
                let item = Item(title: entry.title.isEmpty ? "—" : entry.title, action: nil, keyEquivalent: "")
                item.entry = entry
                item.state = entry.isChecked ? .on : .off
                if let shortcut = entry.shortcut {
                    item.keyEquivalent = shortcut.key
                    var flags: NSEvent.ModifierFlags = []
                    if shortcut.command { flags.insert(.command) }
                    if shortcut.shift { flags.insert(.shift) }
                    if shortcut.option { flags.insert(.option) }
                    if shortcut.control { flags.insert(.control) }
                    item.keyEquivalentModifierMask = flags
                }
                if let submenu = entry.submenu, !submenu.isEmpty {
                    let child = NSMenu(title: entry.title)
                    populate(child, with: submenu)
                    item.submenu = child
                    item.isEnabled = true
                } else {
                    item.isEnabled = entry.isEnabled
                    item.target = self
                    item.action = #selector(choose(_:))
                }
                menu.addItem(item)
            }
        }
        if menu.items.last?.isSeparatorItem == true { menu.removeItem(at: menu.items.count - 1) }
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard let entry = (sender as? Item)?.entry else { return }
        let element = entry.element
        let title = entry.title
        Task.detached(priority: .userInitiated) {
            element.setTimeout(1)
            let error = element.perform("AXPress")
            Log.write("mirror press \"\(title)\": \(error == .success ? "ok" : "AXError \(error.rawValue)")")
            if error != .success {
                await MainActor.run { NSSound.beep() }
            }
        }
    }
}
