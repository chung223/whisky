import AppKit
import ApplicationServices

/// Accessibility is required (reading other apps' status items); Screen Recording is optional
/// (real item images instead of app icons).
@MainActor
final class Permissions: NSObject {
    private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    private let onChange: @MainActor (Bool) -> Void
    private var pollTimer: Timer?

    init(onChange: @escaping @MainActor (Bool) -> Void) {
        self.onChange = onChange
        super.init()
        // `.deliverImmediately`: an accessory app is never frontmost, and the default suspension
        // behaviour would hold the notification until it is.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(accessibilityChanged),
            name: Notification.Name("com.apple.accessibility.api"), object: nil,
            suspensionBehavior: .deliverImmediately
        )
        if !isAccessibilityTrusted { startPolling() }
    }

    /// Shows the system prompt that offers to open Privacy & Security › Accessibility.
    func requestAccessibility() {
        // The string, not `kAXTrustedCheckOptionPrompt`: Swift imports that constant as a mutable global.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    static func requestScreenRecording() {
        if !CGRequestScreenCaptureAccess() {
            Permissions.openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        }
    }

    @objc private func accessibilityChanged() {
        // AXIsProcessTrusted() caches its answer; read too soon after the notification and you get
        // the old value.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            self.refresh()
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
    }

    private func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted { pollTimer?.invalidate(); pollTimer = nil } else if pollTimer == nil { startPolling() }
        guard trusted != isAccessibilityTrusted else { return }
        isAccessibilityTrusted = trusted
        Log.write("accessibility trusted: \(trusted)")
        onChange(trusted)
    }

    private func open(_ string: String) { Self.openURL(string) }

    private static func openURL(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
