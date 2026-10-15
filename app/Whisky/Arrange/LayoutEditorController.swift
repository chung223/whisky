import AppKit
import SwiftUI
import WhiskyCore

/// The "Arrange Menu Bar" window.
@MainActor
final class LayoutEditorController: NSObject, NSWindowDelegate {
    private let model: BarModel
    private let arranger: Arranger
    private let draft = LayoutDraft()
    private var window: NSWindow?
    /// Called after an apply went through, to take the new run as the arrangement.
    var onApplied: (() async -> Void)?

    init(model: BarModel, arranger: Arranger) {
        self.model = model
        self.arranger = arranger
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        Task { await reload() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let view = LayoutEditorView(
            draft: draft,
            onImportBartender: { [weak self] in self?.importBartender() },
            onRevert: { [weak self] in Task { await self?.reload() } },
            onApply: { [weak self] in Task { await self?.apply() } }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "排列選單列"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 860, height: 600))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    private func reload() async {
        guard !draft.isApplying else { return }
        await model.refresh(captureGlyphs: false)
        let drawableMinX = MenuBarGeometry.current().displays.first?.drawableMinX ?? 0
        draft.load(scan: model.lastScan, anchorFrame: arranger.anchorWindowFrame(), drawableMinX: drawableMinX,
                   menuBarShown: arranger.isMenuBarShown())
        draft.status = .idle
        draft.note = nil
        await captureGlyphs()
    }

    /// The items' real images, for the preview and the tiles (needs Screen Recording; items pushed off the screen
    /// can't be captured and keep their symbol or app icon).
    private func captureGlyphs() async {
        let entries = draft.visible + draft.hidden + draft.fixed
        let requests = entries.compactMap { entry in entry.item.windowID.map { (id: entry.id, windowID: $0) } }
        let glyphs = await GlyphCapture.capture(requests)
        if !glyphs.isEmpty { draft.glyphs = glyphs }
    }

    private func importBartender() {
        guard let result = BartenderLayout.visibleKeys(for: model.lastScan) else {
            draft.note = "找不到 Bartender 的設定。"
            return
        }
        draft.setVisible(result.keys)
        let placed = draft.visible.count
        draft.note = "依 Bartender 的「顯示」清單排好了 \(placed) 個；\(result.unmatched) 筆沒在執行或對不上。確認後按「套用」。"
        Log.write("bartender import: \(placed) placed, \(result.unmatched) unmatched; visible \(draft.visible.map(\.id))")
    }

    private func apply() async {
        guard !draft.isApplying, draft.hasChanges else { return }
        let visible = draft.visible.map(\.item)
        let wanted = draft.visible.map(\.id)
        draft.status = .applying(done: 0, total: 0)
        let result = await arranger.apply(visible: visible) { [weak self] done, total in
            self?.draft.status = .applying(done: done, total: total)
        }
        let drawableMinX = MenuBarGeometry.current().displays.first?.drawableMinX ?? 0
        draft.load(scan: model.lastScan, anchorFrame: arranger.anchorWindowFrame(), drawableMinX: drawableMinX,
                   menuBarShown: arranger.isMenuBarShown())
        switch result {
        case .success(let moves):
            draft.status = .finished(moves: moves)
            await onApplied?()
        case .failure(let failure):
            // Keep what the user asked for so pressing Apply again retries from where the menu bar is now.
            draft.setVisible(wanted)
            draft.status = .failed("停在一半：\(failure)。可以再按一次「套用」從目前的狀態繼續。")
        }
    }

    func windowWillClose(_ notification: Notification) {
        draft.note = nil
    }
}
