import AppKit
import WhiskyCore

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var instance: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        instance = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private let model = BarModel()
    private var permissions: Permissions!
    private var statusItem: StatusItemController!
    private var bar: WhiskyBarController!
    private var arranger: Arranger!
    private var editor: LayoutEditorController!
    private let spacer = SpacerController()
    private var spike: SpacerSpike?
    private var hotKey: GlobalHotKey?
    private var hotKeyFailed = false
    private var diagnostics: Diagnostics?
    private var memory: LayoutMemory!
    private let settings = SettingsController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        Log.write("launch Whisky \(version) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        permissions = Permissions { [weak self] trusted in
            guard let self else { return }
            model.isAccessibilityTrusted = trusted
            if trusted {
                Task {
                    await self.model.refresh(captureGlyphs: false)
                    await self.spacer.start()
                }
            }
        }
        statusItem = StatusItemController()
        arranger = Arranger(
            model: model,
            anchorFrame: { [weak self] in self?.statusItem.buttonFrame },
            anchorNumber: { [weak self] in self?.statusItem.windowID }
        )
        arranger.spacer = spacer
        memory = LayoutMemory(model: model, arranger: arranger)
        editor = LayoutEditorController(model: model, arranger: arranger)
        editor.onApplied = { [weak self] in await self?.memory.remember() }
        bar = WhiskyBarController(model: model, permissions: permissions, arranger: arranger) { [weak self] in self?.statusItem.buttonFrame }
        statusItem.onToggleBar = { [weak self] in self?.bar.toggle() }
        statusItem.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        bar.onVisibilityChange = { [weak self] isOpen in
            self?.statusItem.setBarOpen(isOpen)
            if isOpen { self?.memory.scheduleCheck(after: .zero) }
        }
        bar.onArranged = { [weak self] in await self?.memory.remember() }
        bar.onRestoreLayout = { [weak self] in self?.restoreLayout() }
        bar.onKeepLayout = { [weak self] in Task { await self?.memory.remember() } }
        diagnostics = Diagnostics(model: model)
        spacer.onClick = { [weak self] in self?.bar.toggle() }
        spike = SpacerSpike(arranger: arranger, spacer: spacer)
        registerHotKey()
        wireSettings()
        memory.start()

        if permissions.isAccessibilityTrusted {
            Task {
                await model.refresh(captureGlyphs: false)
                await spacer.start()
            }
        } else {
            permissions.requestAccessibility()
        }
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let shortcut = hotKey == nil ? "" : HotKeyPreference.shortcut.map { "（\($0.display)）" } ?? ""
        menu.addItem(item("打開 Whisky Bar\(shortcut)", #selector(toggleBar)))
        menu.addItem(item("排列選單列…", #selector(showEditor)))
        menu.addItem(sendBehindNotchItem())
        if let drift = model.layoutDrift {
            let restore = item("排回你排好的版面", #selector(restoreLayoutFromMenu))
            restore.image = NSImage(systemSymbolName: "arrow.uturn.backward.circle", accessibilityDescription: nil)
            restore.toolTip = drift.summary
            menu.addItem(restore)
        }
        menu.addItem(.separator())

        let spacerItem = item("只顯示排好的圖示（分隔項目）", #selector(toggleSpacer))
        spacerItem.state = spacer.isActive ? .on : .off
        spacerItem.toolTip = "在排好的圖示左邊放一個分隔項目，把其他圖示推到螢幕外；它們仍可從 Whisky Bar 打開。"
        menu.addItem(spacerItem)
        menu.addItem(item("設定…", #selector(showSettings), key: ","))

        if !permissions.isAccessibilityTrusted {
            menu.addItem(item("授權「輔助使用」…", #selector(requestAccessibility)))
        }

        menu.addItem(.separator())
        menu.addItem(item("關於 Whisky", #selector(showAbout)))
        menu.addItem(item("結束 Whisky", #selector(quit), key: "q"))
        return menu
    }

    /// A submenu listing the third-party items macOS draws now; choosing one sends it behind the notch.
    private func sendBehindNotchItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "收到瀏海後面", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let shown = model.shownItems
        if shown.isEmpty {
            let empty = NSMenuItem(title: permissions.isAccessibilityTrusted ? "（沒有可以收起的圖示）" : "（需要「輔助使用」權限）", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        for scanned in shown {
            let title = scanned.label == scanned.appName ? scanned.appName : "\(scanned.appName)：\(scanned.label)"
            let entry = item(title, #selector(sendBehindNotch(_:)))
            entry.representedObject = scanned.key
            entry.image = NSRunningApplication(processIdentifier: scanned.pid)?.icon.map { icon in
                let copy = icon.copy() as! NSImage
                copy.size = NSSize(width: 16, height: 16)
                return copy
            }
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }

    @objc private func sendBehindNotch(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        let title = sender.title
        Task {
            switch await arranger.unpin(key: key) {
            case .success: await memory.remember()
            case .failure(let failure): ArrangeAlert.show(action: "把「\(title)」收到瀏海後面", failure: failure)
            }
        }
    }

    // MARK: - Layout memory

    @objc private func restoreLayoutFromMenu() { restoreLayout() }

    private func restoreLayout() {
        Task {
            if case .failure(let failure) = await memory.restore() {
                ArrangeAlert.show(action: "把圖示排回你排好的版面", failure: failure)
            }
        }
    }

    // MARK: - Shortcut

    private func registerHotKey() {
        hotKey?.unregister()
        hotKey = nil
        hotKeyFailed = false
        guard let shortcut = HotKeyPreference.shortcut else { return }
        hotKey = GlobalHotKey(shortcut) { [weak self] in self?.bar.toggle() }
        hotKeyFailed = hotKey == nil
    }

    // MARK: - Settings

    @objc private func showSettings() { settings.show() }

    private func wireSettings() {
        let model = settings.model
        model.actions = SettingsModel.Actions(
            setHotKey: { [weak self] shortcut in
                HotKeyPreference.shortcut = shortcut
                self?.registerHotKey()
                Log.write("hotkey: \(shortcut?.display ?? "none")")
            },
            setRecordingHotKey: { [weak self] recording in
                if recording {
                    self?.hotKey?.unregister()
                    self?.hotKey = nil
                } else {
                    self?.registerHotKey()
                }
            },
            setLaunchAtLogin: { LoginItem.setEnabled($0) },
            setShowsRealImages: { [weak self] on in
                self?.model.showsRealImages = on
                if on, !Permissions.hasScreenRecording { Permissions.requestScreenRecording() }
            },
            setSpacer: { [weak self] on in await self?.setSpacer(on) },
            setWatchesLayout: { [weak self] on in self?.memory.isWatching = on },
            keepCurrentLayout: { [weak self] in await self?.memory.remember() },
            showEditor: { [weak self] in self?.editor.show() },
            requestAccessibility: { [weak self] in self?.requestAccessibility() },
            requestScreenRecording: { Permissions.requestScreenRecording() },
            openLoginItems: { LoginItem.openSettings() },
            revealLog: { [weak self] in self?.revealLog() },
            refresh: { [weak self] in self?.refreshSettings() }
        )
    }

    private func refreshSettings() {
        let model = settings.model
        model.hotKey = HotKeyPreference.shortcut
        model.hotKeyProblem = hotKeyFailed ? "這組快捷鍵被別的 App 用掉了，換一組試試。" : nil
        model.launchAtLogin = LoginItem.isEnabled || LoginItem.needsApproval
        model.loginNeedsApproval = LoginItem.needsApproval
        model.showsRealImages = self.model.showsRealImages
        if !model.spacerBusy { model.spacerOn = spacer.isActive }
        model.watchesLayout = memory.isWatching
        model.savedLayoutCount = memory.saved?.count
        model.hasAccessibility = permissions.isAccessibilityTrusted
        model.hasScreenRecording = Permissions.hasScreenRecording
    }

    /// Turns the spacer on or off and takes the result as the arrangement. Returns a problem to show, or nil.
    private func setSpacer(_ on: Bool) async -> String? {
        if !on {
            arranger.disableSpacer()
            await memory.remember()
            return nil
        }
        if case .failure(let failure) = await arranger.enableSpacer() {
            arranger.disableSpacer()
            return "沒辦法打開分隔項目：\(failure)。選單列已經還原。"
        }
        await memory.remember()
        return nil
    }

    // MARK: - URL scheme (automation and testing)

    /// `whisky://pin?key=<key>`, `whisky://unpin?key=<key>`, `whisky://apply?keys=<k1,k2,…>`, `whisky://arrange`,
    /// `whisky://settings`, `whisky://plan-bartender`, `whisky://diagnose`, `whisky://check-layout`, `whisky://remember-layout`,
    /// `whisky://snapshot` (draws Whisky's open windows into PNGs next to the log). Keys are listed in diagnose.json.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "whisky" {
            let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "key" }?.value
            Log.write("url: \(url.absoluteString)")
            switch (url.host(), key) {
            case ("pin", let key?): Task { _ = await arranger.pin(key: key) }
            case ("unpin", let key?): Task { _ = await arranger.unpin(key: key) }
            case ("diagnose", _): Task { await model.writeDiagnostics() }
            case ("spike", _): Task { await spike?.run() }
            case ("spacer-on", _): Task { _ = await arranger.enableSpacer() }
            case ("spacer-off", _): arranger.disableSpacer()
            case ("move", _):
                // Debugging: whisky://move?item=<window ID>&leftOf=<window ID> (or rightOf=).
                let query = Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
                guard let item = query["item"].flatMap(UInt32.init) else { break }
                let destination: MoveDestination? = query["leftOf"].flatMap(UInt32.init).map { .leftOf($0) } ?? query["rightOf"].flatMap(UInt32.init).map { .rightOf($0) }
                if let destination { Task { _ = await arranger.moveRaw(item, to: destination) } }
            case ("arrange", _): editor.show()
            case ("settings", _): settings.show()
            case ("snapshot", _):
                WindowSnapshot.writeVisibleWindows()
                // whisky://snapshot?close=1 closes the windows afterwards (testing without leaving them open).
                if url.query()?.contains("close=1") == true {
                    bar.close()
                    NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }.forEach { $0.performClose(nil) }
                }
            case ("check-layout", _): Task { await memory.check() }
            case ("remember-layout", _): Task { await memory.remember() }
            case ("bar", _): bar.toggle()
            case ("apply", _):
                // keys: comma-separated, left to right; they become the visible run next to Whisky's icon.
                let keys = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "keys" }?.value ?? "")
                    .split(separator: ",").map(String.init)
                Task {
                    await model.refresh(captureGlyphs: false)
                    let items = keys.compactMap { model.item(forKey: $0) }
                    let result = await arranger.apply(visible: items) { _, _ in }
                    Log.write("url apply: \(items.count)/\(keys.count) keys found, result \(result)")
                }
            case ("plan-bartender", _): Task { await logBartenderPlan() }
            default: Log.write("url: not understood")
            }
        }
    }

    /// Dry run of "import from Bartender, then apply": logs the matched items and the moves, moves nothing.
    private func logBartenderPlan() async {
        await model.refresh(captureGlyphs: false)
        guard let result = BartenderLayout.visibleKeys(for: model.lastScan) else {
            Log.write("plan-bartender: no Bartender layout found")
            return
        }
        let items = result.keys.compactMap { model.item(forKey: $0) }
        let moves = await arranger.plan(visible: items).map { "send away \($0.sendAway), pin \($0.pin)" } ?? "no plan"
        Log.write("plan-bartender: visible \(items.map { "\($0.appName)[\($0.label)]" }); \(result.unmatched) unmatched; plan: \(moves)")
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleBar() { bar.toggle() }

    @objc private func showEditor() { editor.show() }

    @objc private func toggleSpacer() {
        let on = !spacer.isActive
        Task {
            if let problem = await setSpacer(on) {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = problem
                NSApp.activate()
                alert.runModal()
            }
        }
    }


    @objc private func requestAccessibility() {
        permissions.requestAccessibility()
        permissions.openAccessibilitySettings()
    }

    @objc private func revealLog() { NSWorkspace.shared.activateFileViewerSelecting([Log.fileURL]) }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
