import Carbon.HIToolbox

/// A system-wide keyboard shortcut through Carbon's `RegisterEventHotKey`, which needs no permission
/// (unlike a global key event monitor, which needs Accessibility and sees every keystroke).
@MainActor
final class GlobalHotKey {
    /// ⌃⌥⌘W: W for Whisky. Unclaimed by macOS and by the common apps.
    static let defaultKeyCode = UInt32(kVK_ANSI_W)
    static let defaultModifiers = UInt32(cmdKey | optionKey | controlKey)
    static let defaultDisplay = "⌃⌥⌘W"

    private static var actions: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false
    private static var nextID: UInt32 = 1

    private var ref: EventHotKeyRef?
    private let id: UInt32

    init?(keyCode: UInt32 = defaultKeyCode, modifiers: UInt32 = defaultModifiers, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        id = Self.nextID
        Self.nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5748_534B), id: id) // "WHSK"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.write("hotkey: registering failed (\(status)); another app may own this shortcut")
            return nil
        }
        self.ref = ref
        Self.actions[id] = action
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.actions[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            // Carbon delivers hot key events on the main thread.
            MainActor.assumeIsolated { GlobalHotKey.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
