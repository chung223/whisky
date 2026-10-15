import AppKit
import SwiftUI
import WhiskyCore

/// Click, then press the new shortcut. Esc cancels; Delete clears it (no shortcut at all).
struct ShortcutRecorder: View {
    let shortcut: HotKeyShortcut?
    let onChange: (HotKeyShortcut?) -> Void
    let onRecordingChange: (Bool) -> Void
    /// Offer "Restore" to ⌃⌥⌘W (Whisky Bar's own shortcut only).
    var offersDefault = true

    @State private var isRecording = false
    @State private var held: NSEvent.ModifierFlags = []
    @State private var hint: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: toggle) {
                    Text(label)
                        .foregroundStyle(isRecording || shortcut == nil ? .secondary : .primary)
                        .frame(minWidth: 130)
                }
                .help(isRecording ? "按下新的快捷鍵；Esc 取消，Delete 清除" : "按一下錄製新的快捷鍵")
                if !isRecording, shortcut != nil {
                    Button { onChange(nil) } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("不要快捷鍵")
                }
                if offersDefault, !isRecording, shortcut != .default {
                    Button("還原") { onChange(.default) }
                        .buttonStyle(.borderless)
                        .help("還原成 \(HotKeyShortcut.default.display)")
                }
            }
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if isRecording {
            let modifiers = Self.symbols(held)
            return modifiers.isEmpty ? "按下新的快捷鍵…" : modifiers + "…"
        }
        return shortcut?.display ?? "沒有快捷鍵"
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        hint = nil
        held = []
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            MainActor.assumeIsolated { handle(event) } ? nil : event
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        held = []
        onRecordingChange(false)
    }

    /// Returns true when the event was used.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.type == .flagsChanged {
            held = flags
            return true
        }
        switch Int(event.keyCode) {
        case 53 where flags.isEmpty: // Esc
            stop()
        case 51 where flags.isEmpty, 117 where flags.isEmpty: // Delete, Forward Delete
            stop()
            onChange(nil)
        default:
            let candidate = HotKeyShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: Self.carbonModifiers(flags),
                keyLabel: HotKeyShortcut.label(forKeyCode: UInt32(event.keyCode), typed: event.charactersIgnoringModifiers)
            )
            guard candidate.isUsable else {
                hint = "要加上 ⌘、⌃ 或 ⌥（F1–F20 可以單獨用）"
                NSSound.beep()
                return true
            }
            hint = nil
            stop()
            onChange(candidate)
        }
        return true
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= HotKeyShortcut.command }
        if flags.contains(.shift) { modifiers |= HotKeyShortcut.shift }
        if flags.contains(.option) { modifiers |= HotKeyShortcut.option }
        if flags.contains(.control) { modifiers |= HotKeyShortcut.control }
        return modifiers
    }

    private static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        HotKeyShortcut(keyCode: 0, modifiers: carbonModifiers(flags), keyLabel: "").display
    }
}
