import Foundation

/// A keyboard shortcut as Carbon's `RegisterEventHotKey` takes it: a virtual key code and Carbon modifier flags,
/// plus the key's printed name, read from the keyboard layout when the shortcut was recorded.
public struct HotKeyShortcut: Codable, Equatable, Sendable {
    // Carbon's modifier flags (Events.h), so this package doesn't need Carbon.
    public static let command: UInt32 = 1 << 8
    public static let shift: UInt32 = 1 << 9
    public static let option: UInt32 = 1 << 11
    public static let control: UInt32 = 1 << 12

    public var keyCode: UInt32
    public var modifiers: UInt32
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers & (Self.command | Self.shift | Self.option | Self.control)
        self.keyLabel = keyLabel
    }

    /// ⌃⌥⌘W: W for Whisky. Unclaimed by macOS and by the common apps.
    public static let `default` = HotKeyShortcut(keyCode: 13, modifiers: control | option | command, keyLabel: "W")

    /// Modifier symbols in the order macOS menus print them, then the key.
    public var display: String {
        var text = ""
        if modifiers & Self.control != 0 { text += "⌃" }
        if modifiers & Self.option != 0 { text += "⌥" }
        if modifiers & Self.shift != 0 { text += "⇧" }
        if modifiers & Self.command != 0 { text += "⌘" }
        return text + keyLabel
    }

    /// A system-wide shortcut needs ⌘, ⌃ or ⌥ (Shift alone would swallow capital letters everywhere), except on
    /// function keys, which type nothing.
    public var isUsable: Bool {
        modifiers & (Self.command | Self.option | Self.control) != 0 || Self.functionKeyCodes[keyCode] != nil
    }

    // MARK: - Key names

    private static let functionKeyCodes: [UInt32: Int] = [
        122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9, 109: 10,
        103: 11, 111: 12, 105: 13, 107: 14, 113: 15, 106: 16, 64: 17, 79: 18, 80: 19, 90: 20,
    ]

    private static let namedKeys: [UInt32: String] = [
        36: "↩", 76: "⌤", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]

    /// The printed name of a key: a symbol for keys that type no visible character, otherwise what the current
    /// keyboard layout types for it (`typed`, as `charactersIgnoringModifiers` reports it), capitalised.
    public static func label(forKeyCode keyCode: UInt32, typed: String?) -> String {
        if let number = functionKeyCodes[keyCode] { return "F\(number)" }
        if let name = namedKeys[keyCode] { return name }
        let text = (typed ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "#\(keyCode)" : text.uppercased()
    }
}
