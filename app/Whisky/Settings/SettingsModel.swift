import AppKit
import Observation
import WhiskyCore

/// What the settings window shows. The owner refreshes it when the window opens (and every few seconds while it is
/// open, for the permissions) and wires the actions.
@MainActor
@Observable
final class SettingsModel {
    struct Actions {
        var setHotKey: (HotKeyShortcut?) -> Void = { _ in }
        /// Recording a shortcut: the current one is released meanwhile, so pressing it records it instead of firing.
        var setRecordingHotKey: (Bool) -> Void = { _ in }
        var setLaunchAtLogin: (Bool) -> Void = { _ in }
        var setOpensFromNotch: (Bool) -> Void = { _ in }
        var setGlassInNotch: (Bool) -> Void = { _ in }
        var setAnnouncesChanges: (Bool) -> Void = { _ in }
        var setShowsRealImages: (Bool) -> Void = { _ in }
        /// Returns a problem to show, or nil.
        var setSpacer: (Bool) async -> String? = { _ in nil }
        var setWatchesLayout: (Bool) -> Void = { _ in }
        var keepCurrentLayout: () async -> Void = {}
        var showEditor: () -> Void = {}
        var requestAccessibility: () -> Void = {}
        var requestScreenRecording: () -> Void = {}
        var openLoginItems: () -> Void = {}
        var revealLog: () -> Void = {}
        var refresh: () -> Void = {}
        /// Assigns (or with nil, removes) an item's shortcut. Returns a problem to show, or nil.
        var setItemHotKey: (_ key: String, _ name: String, HotKeyShortcut?) -> String? = { _, _, _ in nil }
    }

    /// An item with (or about to get) its own shortcut.
    struct ItemShortcut: Identifiable, Equatable {
        let key: String
        let name: String
        let icon: NSImage?
        var shortcut: HotKeyShortcut?

        var id: String { key }
    }

    var hotKey: HotKeyShortcut?
    /// The shortcut couldn't be registered (another app has it).
    var hotKeyProblem: String?
    var launchAtLogin = false
    var loginNeedsApproval = false
    var showsRealImages = false
    var opensFromNotch = true
    var glassInNotch = false
    var announcesChanges = true
    var hasNotch = false
    var spacerOn = false
    var spacerBusy = false
    var spacerProblem: String?
    var watchesLayout = true
    var savedLayoutCount: Int?
    var hasAccessibility = false
    var hasScreenRecording = false
    var itemShortcuts: [ItemShortcut] = []
    /// Items in the menu bar now, for "Add".
    var assignableItems: [ItemShortcut] = []
    /// Rows added but not recorded yet (kept across refreshes).
    var pendingItemKeys: [String] = []
    var itemShortcutProblem: String?
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    @ObservationIgnored var actions = Actions()
}
