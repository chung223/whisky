import Testing
@testable import WhiskyCore

@Suite("Menu bar restriction (macOS 27)")
struct MenuBarRestrictionTests {
    private let installed: Set<String> = [
        "com.bjango.istatmenus-setapp.status", "app.keysmith.Keysmith-setapp", "com.apple.controlcenter", "com.chung.shot",
    ]

    @Test("A key's app: the longest prefix installed on this Mac, dashes in bundle IDs included")
    func bundleIDs() {
        let isBundleID = { installed.contains($0) }
        #expect(MenuBarRestriction.bundleID(ofKey: "com.bjango.istatmenus-setapp.status-com.bjango.istatmenus.memory", isBundleID: isBundleID)
            == "com.bjango.istatmenus-setapp.status")
        #expect(MenuBarRestriction.bundleID(ofKey: "app.keysmith.Keysmith-setapp-Item-0", isBundleID: isBundleID) == "app.keysmith.Keysmith-setapp")
        #expect(MenuBarRestriction.bundleID(ofKey: "com.apple.controlcenter-WiFi", isBundleID: isBundleID) == "com.apple.controlcenter")
        #expect(MenuBarRestriction.bundleID(ofKey: "com.chung.shot-my-item", isBundleID: isBundleID) == "com.chung.shot")
    }

    @Test("Apps not on this Mac: before AppKit's default name, else before the last dash")
    func uninstalled() {
        let none: (String) -> Bool = { _ in false }
        #expect(MenuBarRestriction.bundleID(ofKey: "com.lightpillar.Mosaic-setapp-Item-0", isBundleID: none) == "com.lightpillar.Mosaic-setapp")
        #expect(MenuBarRestriction.bundleID(ofKey: "com.example.app-status", isBundleID: none) == "com.example.app")
        #expect(MenuBarRestriction.bundleID(ofKey: "nodash", isBundleID: none) == nil)
        #expect(MenuBarRestriction.bundleID(ofKey: "-Item-0", isBundleID: none) == nil)
    }

    @Test("Arranged apps, apps never seen with an item, and the menu bar's agent are allowed; Control Center isn't listed")
    func allowed() {
        let allowed = MenuBarRestriction.allowed(
            arranged: ["rafael.MenuBarUSB", "com.chung.shot", "com.apple.controlcenter"],
            known: ["rafael.MenuBarUSB", "com.chung.shot", "com.chung.presence", "com.llmwiki.app"],
            running: ["com.chung.presence", "com.llmwiki.app", "com.apple.finder", "com.nssurge.surge-mac"]
        )
        #expect(allowed == ["rafael.MenuBarUSB", "com.chung.shot", "com.apple.finder", "com.nssurge.surge-mac",
                            "com.apple.MenuBarAgent", "com.chung.whisky"])
    }

    @Test("Hidden: known apps left out, never Whisky or Control Center")
    func hidden() {
        let known: Set<String> = ["rafael.MenuBarUSB", "com.chung.presence", "com.chung.whisky", "com.apple.controlcenter"]
        let allowed = MenuBarRestriction.allowed(arranged: ["rafael.MenuBarUSB"], known: known, running: [])
        #expect(MenuBarRestriction.hidden(known: known, allowed: allowed) == ["com.chung.presence"])
    }

    @Test("Item names: the app's own autosave name, not AppKit's default")
    func itemNames() {
        let istat = "com.bjango.istatmenus-setapp.status"
        #expect(MenuBarRestriction.itemName(ofKey: "\(istat)-com.bjango.istatmenus.memory", bundleID: istat) == "memory")
        #expect(MenuBarRestriction.itemName(ofKey: "com.chung.shot-Item-0", bundleID: "com.chung.shot") == nil)
        #expect(MenuBarRestriction.itemName(ofKey: "com.chung.shot-Item-0", bundleID: istat) == nil)
    }
}
