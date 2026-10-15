import AppKit
import SwiftUI

/// The welcome window, shown once on first launch (and again with `whisky://welcome`).
@MainActor
final class WelcomeController: NSObject, NSWindowDelegate {
    private static let seenKey = "hasSeenWelcome"

    let model = WelcomeModel()
    /// Fills in the permission states and the like (called while the window is open).
    var refresh: (WelcomeModel) -> Void = { _ in }
    private var window: NSWindow?
    private var timer: Timer?

    static var hasBeenSeen: Bool {
        get { UserDefaults.standard.bool(forKey: seenKey) }
        set { UserDefaults.standard.set(newValue, forKey: seenKey) }
    }

    func show() {
        refresh(model)
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // Permissions are granted in System Settings while the window is open.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refresh(self.model)
            }
        }
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let previousFinish = model.finish
        model.finish = { [weak self] in
            previousFinish()
            self?.close()
        }
        let controller = NSHostingController(rootView: WelcomeView(model: model))
        controller.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        window.title = "歡迎使用 Whisky"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        Self.hasBeenSeen = true
    }
}
