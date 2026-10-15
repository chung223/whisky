/// Pure pieces of menu mirroring: turning what AX reports about a menu item into what NSMenu needs.

/// A key equivalent read from `AXMenuItemCmdChar` and `AXMenuItemCmdModifiers`.
public struct MenuShortcut: Sendable, Equatable {
    public var key: String
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool

    /// AX modifier bits (HIToolbox `kMenu*Modifier`): shift 1, option 2, control 4, and 8 means *no* command.
    public init?(cmdChar: String?, axModifiers: Int?) {
        guard let cmdChar, let scalar = cmdChar.unicodeScalars.first,
              scalar.value > 0x20, scalar.value != 0x7F
        else { return nil }
        let mask = axModifiers ?? 0
        key = cmdChar.lowercased()
        shift = mask & 1 != 0
        option = mask & 2 != 0
        control = mask & 4 != 0
        command = mask & 8 == 0
    }
}

public enum MenuItemKind: Sendable, Equatable {
    case item
    case separator
    /// A custom view (empty title, but with child elements): it can't be reproduced in a mirror.
    case unsupported

    /// Separators are untitled menu items with nothing inside them. An untitled item that does have
    /// children is a custom view, which a plain-title mirror would get wrong.
    public static func classify(title: String, hasSubmenu: Bool, childCount: Int) -> MenuItemKind {
        if !title.isEmpty || hasSubmenu { return .item }
        return childCount == 0 ? .separator : .unsupported
    }
}
