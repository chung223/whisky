import AppKit
import SwiftUI

private final class BarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The panel under the menu bar that lists the items macOS didn't draw.
@MainActor
final class WhiskyBarController {
    var onVisibilityChange: ((Bool) -> Void)?

    private let model: BarModel
    private let permissions: Permissions
    private let anchor: () -> NSRect?
    private let arranger: Arranger
    private lazy var activator = ItemActivator(arranger: arranger)
    private var panel: BarPanel?
    private var monitors: [Any] = []
    private var refreshTimer: Timer?

    init(model: BarModel, permissions: Permissions, arranger: Arranger, anchor: @escaping () -> NSRect?) {
        self.model = model
        self.permissions = permissions
        self.arranger = arranger
        self.anchor = anchor
    }

    var isOpen: Bool { panel?.isVisible == true }

    func toggle() {
        isOpen ? close() : open()
    }

    func open() {
        model.resetSearch()
        let panel = panel ?? makePanel()
        self.panel = panel
        place(panel, size: panel.frame.size)
        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitors()
        Task { await model.refresh(captureGlyphs: true) }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.model.refresh(captureGlyphs: false) }
            }
        }
        onVisibilityChange?(true)
    }

    func close() {
        guard isOpen else { return }
        panel?.orderOut(nil)
        removeMonitors()
        refreshTimer?.invalidate()
        refreshTimer = nil
        onVisibilityChange?(false)
    }

    // MARK: - Actions

    private func open(_ item: BarItem, fromKeyboard: Bool = false) {
        // Drop the menu just under the panel: lined up with the pointer, or with the panel's left edge when the
        // keyboard chose the item.
        let panelFrame = panel?.frame ?? .zero
        let x = fromKeyboard ? panelFrame.minX + 12 : NSEvent.mouseLocation.x
        let location = NSPoint(x: x, y: (panel?.frame.minY ?? NSEvent.mouseLocation.y) - 2)
        activator.open(item.scanned, at: location) { [weak self] in self?.close() }
    }

    /// Typing filters the items; arrows move the highlight; Return opens it; Esc clears, then closes.
    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        switch Int(event.keyCode) {
        case 53: // Esc
            if model.query.isEmpty { close() } else { model.resetSearch() }
            return true
        case 51: // Delete
            if !model.query.isEmpty { model.query.removeLast() }
            return true
        case 36, 76: // Return, Enter
            if let item = model.selectedItem { open(item, fromKeyboard: true) }
            return true
        case 123, 126: // ←, ↑
            model.moveSelection(by: -1)
            return true
        case 124, 125: // →, ↓
            model.moveSelection(by: 1)
            return true
        default:
            guard flags.isEmpty, let characters = event.characters, !characters.isEmpty,
                  // Function and arrow keys arrive as private-use characters; they aren't text.
                  characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.properties.generalCategory != .privateUse })
            else { return false }
            model.query += characters
            model.isUsingKeyboard = true
            return true
        }
    }

    private func press(_ item: BarItem) {
        close()
        Task { await activator.press(item.scanned) }
    }

    private func activateApp(_ item: BarItem) {
        close()
        activator.activateApp(item.scanned)
    }

    private func pin(_ item: BarItem) {
        close()
        let key = item.scanned.key
        let name = item.tooltip
        Task {
            if case .failure(let failure) = await arranger.pin(key: key) {
                ArrangeAlert.show(action: "把「\(name)」放到選單列上", failure: failure)
            }
        }
    }

    // MARK: - Panel

    private func makePanel() -> BarPanel {
        let panel = BarPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 40), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.animationBehavior = .utilityWindow

        let maxWidth = (screen()?.frame.width ?? 1440) - 32
        let view = WhiskyBarView(
            model: model,
            maxWidth: maxWidth,
            onOpen: { [weak self] in self?.open($0) },
            onPress: { [weak self] in self?.press($0) },
            onActivateApp: { [weak self] in self?.activateApp($0) },
            onPin: { [weak self] in self?.pin($0) },
            onRequestAccessibility: { [weak self] in
                self?.permissions.requestAccessibility()
                self?.permissions.openAccessibilitySettings()
            },
            onSizeChange: { [weak self] size in
                guard let self, let panel = self.panel else { return }
                self.place(panel, size: size)
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }

    /// Hangs the panel just below the menu bar, right-aligned with the Whisky icon.
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

    // MARK: - Dismissal

    private func installMonitors() {
        removeMonitors()
        // Clicks in other apps close the panel. Clicks on the Whisky icon are our own events and
        // go through toggle() instead.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }) {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}
