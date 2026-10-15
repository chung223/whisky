import Foundation
import Testing
@testable import WhiskyCore

@Suite("Hot key shortcut")
struct HotKeyShortcutTests {
    @Test("The default is ⌃⌥⌘W")
    func defaultDisplay() {
        #expect(HotKeyShortcut.default.display == "⌃⌥⌘W")
        #expect(HotKeyShortcut.default.isUsable)
    }

    @Test("Modifiers print in menu order, whatever order they were given in")
    func modifierOrder() {
        let shortcut = HotKeyShortcut(keyCode: 0, modifiers: HotKeyShortcut.command | HotKeyShortcut.shift | HotKeyShortcut.control, keyLabel: "A")
        #expect(shortcut.display == "⌃⇧⌘A")
    }

    @Test("A letter needs ⌘, ⌃ or ⌥; Shift alone isn't enough")
    func usable() {
        #expect(!HotKeyShortcut(keyCode: 0, modifiers: 0, keyLabel: "A").isUsable)
        #expect(!HotKeyShortcut(keyCode: 0, modifiers: HotKeyShortcut.shift, keyLabel: "A").isUsable)
        #expect(HotKeyShortcut(keyCode: 0, modifiers: HotKeyShortcut.option, keyLabel: "A").isUsable)
    }

    @Test("A function key works on its own")
    func functionKey() {
        let f5 = HotKeyShortcut(keyCode: 96, modifiers: 0, keyLabel: HotKeyShortcut.label(forKeyCode: 96, typed: "\u{F708}"))
        #expect(f5.isUsable)
        #expect(f5.display == "F5")
    }

    @Test("Key names: symbols for keys that type nothing visible, the typed character otherwise")
    func labels() {
        #expect(HotKeyShortcut.label(forKeyCode: 49, typed: " ") == "Space")
        #expect(HotKeyShortcut.label(forKeyCode: 123, typed: "\u{F702}") == "←")
        #expect(HotKeyShortcut.label(forKeyCode: 13, typed: "w") == "W")
        #expect(HotKeyShortcut.label(forKeyCode: 41, typed: ";") == ";")
        #expect(HotKeyShortcut.label(forKeyCode: 200, typed: nil) == "#200")
    }

    @Test("Unrelated modifier bits (Caps Lock) are dropped")
    func stripsOtherBits() {
        let capsLock: UInt32 = 1 << 10
        let shortcut = HotKeyShortcut(keyCode: 13, modifiers: HotKeyShortcut.command | capsLock, keyLabel: "W")
        #expect(shortcut.modifiers == HotKeyShortcut.command)
    }

    @Test("Survives a round trip through JSON (how it is stored)")
    func codable() throws {
        let data = try JSONEncoder().encode(HotKeyShortcut.default)
        #expect(try JSONDecoder().decode(HotKeyShortcut.self, from: data) == .default)
    }
}
