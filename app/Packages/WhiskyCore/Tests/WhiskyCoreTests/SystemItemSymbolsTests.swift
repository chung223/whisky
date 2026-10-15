import Testing
@testable import WhiskyCore

@Suite("System item symbols")
struct SystemItemSymbolsTests {
    @Test("Control Center modules, with and without a repeat number")
    func controlCenter() {
        #expect(SystemItemSymbols.symbol(key: "com.apple.controlcenter-WiFi", bundleID: "com.apple.controlcenter") == "wifi")
        #expect(SystemItemSymbols.symbol(key: "com.apple.controlcenter-BentoBox-0", bundleID: "com.apple.controlcenter") == "switch.2")
    }

    @Test("SystemUIServer extras and whole agents")
    func systemUIServer() {
        #expect(SystemItemSymbols.symbol(key: "com.apple.systemuiserver-com.apple.menuextra.TimeMachine", bundleID: "com.apple.systemuiserver") == "clock.arrow.circlepath")
        #expect(SystemItemSymbols.symbol(key: "com.apple.TextInputMenuAgent-Item-0", bundleID: "com.apple.TextInputMenuAgent") == "keyboard")
    }

    @Test("Unknown modules and third-party apps keep their app icon")
    func fallback() {
        #expect(SystemItemSymbols.symbol(key: "com.apple.systemuiserver-Siri", bundleID: "com.apple.systemuiserver") == nil)
        #expect(SystemItemSymbols.symbol(key: "com.bjango.istatmenus-setapp.status-com.bjango.istatmenus.cpu", bundleID: "com.bjango.istatmenus-setapp.status") == nil)
        #expect(SystemItemSymbols.symbol(key: "x-WiFi", bundleID: nil) == nil)
    }
}

@Suite("Item naming")
struct ItemNamingTests {
    @Test("Live readouts are cut at the first number or separator")
    func readouts() {
        #expect(ItemNaming.meaningfulLabel("Memory 67%", appName: "iStat Menus") == "Memory")
        #expect(ItemNaming.meaningfulLabel("CPU 35%", appName: "iStat Menus") == "CPU")
        #expect(ItemNaming.meaningfulLabel("Wi-Fi，3 格", appName: "控制中心") == "Wi-Fi")
    }

    @Test("Nothing useful left: the app name is used")
    func nothingLeft() {
        #expect(ItemNaming.meaningfulLabel("0", appName: "MenuBarUSB") == nil)
        #expect(ItemNaming.meaningfulLabel("Plaud", appName: "Plaud") == nil)
        #expect(ItemNaming.displayName(appName: "MenuBarUSB", label: "0") == "MenuBarUSB")
    }

    @Test("Display and short names")
    func names() {
        #expect(ItemNaming.displayName(appName: "iStat Menus", label: "Memory 67%") == "iStat Menus · Memory")
        #expect(ItemNaming.shortName(appName: "iStat Menus", label: "Memory 67%", appHasSeveralItems: true) == "Memory")
        #expect(ItemNaming.shortName(appName: "Surge", label: "Surge Dashboard", appHasSeveralItems: false) == "Surge")
        #expect(ItemNaming.displayName(appName: "SystemUIServer", label: "Siri", systemName: "Siri") == "Siri")
    }

    @Test("Apple's items have readable names")
    func systemNames() {
        #expect(SystemItemSymbols.name(key: "com.apple.systemuiserver-Siri", bundleID: "com.apple.systemuiserver") == "Siri")
        #expect(SystemItemSymbols.name(key: "com.apple.controlcenter-AudioVideoModule", bundleID: "com.apple.controlcenter") == "麥克風與相機")
        #expect(SystemItemSymbols.symbol(key: "com.apple.systemuiserver-Siri", bundleID: "com.apple.systemuiserver") == nil)
    }
}
