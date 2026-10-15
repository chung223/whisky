import Testing
@testable import WhiskyCore

@Suite("Menu shortcuts")
struct MenuShortcutTests {
    @Test("Plain command shortcut")
    func command() throws {
        let shortcut = try #require(MenuShortcut(cmdChar: "Q", axModifiers: 0))
        #expect(shortcut == MenuShortcut(cmdChar: "q", axModifiers: nil))
        #expect(shortcut.key == "q")
        #expect(shortcut.command && !shortcut.shift && !shortcut.option && !shortcut.control)
    }

    @Test("Modifier bits map to flags")
    func modifiers() throws {
        let shortcut = try #require(MenuShortcut(cmdChar: ",", axModifiers: 1 | 2 | 4))
        #expect(shortcut.shift && shortcut.option && shortcut.control && shortcut.command)
        let noCommand = try #require(MenuShortcut(cmdChar: "x", axModifiers: 8 | 4))
        #expect(!noCommand.command && noCommand.control)
    }

    @Test("Empty and control characters are not shortcuts", arguments: [nil, "", " ", "\u{7F}", "\u{1B}"])
    func invalid(char: String?) {
        #expect(MenuShortcut(cmdChar: char, axModifiers: 0) == nil)
    }
}

@Suite("Menu item kinds")
struct MenuItemKindTests {
    @Test func titled() {
        #expect(MenuItemKind.classify(title: "Quit", hasSubmenu: false, childCount: 0) == .item)
    }

    @Test func submenuWithoutTitle() {
        #expect(MenuItemKind.classify(title: "", hasSubmenu: true, childCount: 1) == .item)
    }

    @Test func separator() {
        #expect(MenuItemKind.classify(title: "", hasSubmenu: false, childCount: 0) == .separator)
    }

    @Test func customView() {
        #expect(MenuItemKind.classify(title: "", hasSubmenu: false, childCount: 3) == .unsupported)
    }
}
