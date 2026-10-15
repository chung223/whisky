import AppKit
import SwiftUI

/// Whisky Bar: lists the items macOS didn't draw. It pours out of the notch on a notched display (unless that is
/// turned off) and otherwise hangs under Whisky's icon. Either way this controller owns what it does: search,
/// keyboard, refreshing, dismissal and the item actions.
@MainActor
final class WhiskyBarController {
    var onVisibilityChange: ((Bool) -> Void)?
    var onRestoreLayout: (() -> Void)?
    /// Called after the user put an item on the menu bar from here.
    var onArranged: (() async -> Void)?
    var onKeepLayout: (() -> Void)?

    private static let notchKey = "opensFromNotch"

    private let model: BarModel
    private let permissions: Permissions
    private let anchor: () -> NSRect?
    private let arranger: Arranger
    private lazy var activator = ItemActivator(arranger: arranger)
    private lazy var floating = FloatingBarPresenter(model: model, actions: actions, anchor: anchor)
    private lazy var notch = NotchPresenter(
        model: model, actions: actions,
        isHoverSuppressed: { [weak self] in self?.arranger.isBusy ?? false },
        onOpenRequest: { [weak self] in self?.open() }
    )
    private var presenter: BarPresenter?
    private var monitors: [Any] = []
    private var refreshTimer: Timer?

    init(model: BarModel, permissions: Permissions, arranger: Arranger, anchor: @escaping () -> NSRect?) {
        self.model = model
        self.permissions = permissions
        self.arranger = arranger
        self.anchor = anchor
    }

    /// Pour Whisky Bar out of the notch (when there is one). On by default.
    var opensFromNotch: Bool {
        get { UserDefaults.standard.object(forKey: Self.notchKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.notchKey)
            close()
            newValue ? notch.install() : notch.uninstall()
        }
    }

    func start() {
        if opensFromNotch { notch.install() }
    }

    var isOpen: Bool { presenter?.isOpen == true }

    func showNotchPeekForTesting() { notch.showPeekForTesting() }

    func toggle() {
        isOpen ? close() : open()
    }

    func open() {
        guard !isOpen else { return }
        model.resetSearch()
        let presenter: BarPresenter = opensFromNotch && NotchPresenter.isAvailable ? notch : floating
        self.presenter = presenter
        Log.write("bar: open (\(presenter is NotchPresenter ? "notch" : "under the icon"))")
        presenter.present()
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
        Log.write("bar: close")
        presenter?.dismiss()
        removeMonitors()
        refreshTimer?.invalidate()
        refreshTimer = nil
        model.hoveredID = nil
        onVisibilityChange?(false)
    }

    private var actions: BarActions {
        BarActions(
            open: { [weak self] in self?.open($0) },
            press: { [weak self] in self?.press($0) },
            activateApp: { [weak self] in self?.activateApp($0) },
            pin: { [weak self] in self?.pin($0) },
            requestAccessibility: { [weak self] in
                self?.permissions.requestAccessibility()
                self?.permissions.openAccessibilitySettings()
            },
            restoreLayout: { [weak self] in
                self?.close()
                self?.onRestoreLayout?()
            },
            keepLayout: { [weak self] in self?.onKeepLayout?() }
        )
    }

    // MARK: - Actions

    private func open(_ item: BarItem, fromKeyboard: Bool = false) {
        model.recordUse(item.scanned.key)
        // Drop the menu from the menu bar, as the item itself would: under the pointer, or under the panel's left edge
        // when the keyboard chose the item.
        let panelFrame = presenter?.window?.frame ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: panelFrame.midX, y: panelFrame.maxY - 1)) } ?? NSScreen.main
        let barHeight = (screen?.safeAreaInsets.top ?? 0) > 0 ? screen?.safeAreaInsets.top ?? 0 : NSStatusBar.system.thickness
        let x = fromKeyboard ? panelFrame.minX + 16 : NSEvent.mouseLocation.x
        let location = NSPoint(x: x, y: (screen?.frame.maxY ?? panelFrame.maxY) - barHeight - 2)
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
        model.recordUse(item.scanned.key)
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
            switch await arranger.pin(key: key) {
            case .success: await onArranged?()
            case .failure(let failure): ArrangeAlert.show(action: "把「\(name)」放到選單列上", failure: failure)
            }
        }
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
