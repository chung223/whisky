import AppKit
import SwiftUI

/// Where Whisky Bar appears: poured out of the notch, or in a glass panel under Whisky's icon.
@MainActor
protocol BarPresenter: AnyObject {
    var isOpen: Bool { get }
    /// The panel, which takes the keyboard while it is open (for search).
    var window: NSWindow? { get }
    func present()
    func dismiss()
}

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The glass panel under Whisky's icon, for screens without a notch (or with the notch turned off in Settings).
@MainActor
final class FloatingBarPresenter: BarPresenter {
    private let model: BarModel
    private let actions: BarActions
    private let anchor: () -> NSRect?
    private var panel: KeyPanel?

    init(model: BarModel, actions: BarActions, anchor: @escaping () -> NSRect?) {
        self.model = model
        self.actions = actions
        self.anchor = anchor
    }

    var isOpen: Bool { panel?.isVisible == true }
    var window: NSWindow? { panel }

    func present() {
        let panel = panel ?? makePanel()
        self.panel = panel
        place(panel, size: panel.frame.size)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> KeyPanel {
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 40), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.animationBehavior = .utilityWindow
        let view = BarContentView(model: model, style: .glass, actions: actions)
            .padding(.vertical, 2)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
                guard let self, let panel = self.panel else { return }
                self.place(panel, size: size)
            }
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }

    /// Hangs the panel just below the menu bar, right-aligned with Whisky's icon.
    private func place(_ panel: NSPanel, size: CGSize) {
        guard size.width > 0, size.height > 0, let screen = screen() else { return }
        let anchorFrame = anchor() ?? NSRect(x: screen.frame.maxX - 40, y: screen.frame.maxY - 1, width: 1, height: 1)
        let barHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : NSStatusBar.system.thickness
        let top = screen.frame.maxY - barHeight - 6
        let x = min(max(anchorFrame.maxX - size.width, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
    }

    private func screen() -> NSScreen? {
        if let anchorFrame = anchor(),
           let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: anchorFrame.midX, y: anchorFrame.minY)) }) {
            return screen
        }
        return NSScreen.main
    }
}
