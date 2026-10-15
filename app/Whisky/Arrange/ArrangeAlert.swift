import AppKit

@MainActor
enum ArrangeAlert {
    static func show(action: String, failure: ItemMover.Failure) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "沒辦法\(action)"
        alert.informativeText = "\(failure)。詳細過程記在記錄檔裡（右鍵點 Whisky 圖示 › 在 Finder 顯示記錄檔）。"
        NSApp.activate()
        alert.runModal()
    }
}
