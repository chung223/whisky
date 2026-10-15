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
