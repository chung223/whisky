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
    }

    var hotKey: HotKeyShortcut?
    /// The shortcut couldn't be registered (another app has it).
    var hotKeyProblem: String?
    var launchAtLogin = false
    var loginNeedsApproval = false
    var showsRealImages = false
    var spacerOn = false
    var spacerBusy = false
    var spacerProblem: String?
    var watchesLayout = true
    var savedLayoutCount: Int?
    var hasAccessibility = false
    var hasScreenRecording = false
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    @ObservationIgnored var actions = Actions()
}
