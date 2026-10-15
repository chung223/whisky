import AppKit
import SwiftUI

/// The settings window (⌘, from Whisky's menu).
@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    let model = SettingsModel()
    private var window: NSWindow?
    private var timer: Timer?

    func show() {
        model.actions.refresh()
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // Permissions change in System Settings while the window is open.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.actions.refresh() }
        }
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView(model: model))
        controller.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        window.title = "Whisky 設定"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
    }
}
