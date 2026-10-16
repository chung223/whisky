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
    private var itemHotKeys: [String: GlobalHotKey] = [:]
    private var diagnostics: Diagnostics?
    private var memory: LayoutMemory!
    private var watcher: ChangeWatcher!
    private let presets = PresetManager()
    private let settings = SettingsController()
    private let welcome = WelcomeController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        Log.write("launch Whisky \(version) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\(PlatformSupport.movesItems ? "" : "; moving items is off (\(PlatformSupport.versionName))")")

        permissions = Permissions { [weak self] trusted in
            guard let self else { return }
            model.isAccessibilityTrusted = trusted
            if trusted {
                Task {
                    await self.model.refresh(captureGlyphs: false)
                    await self.startSpacer()
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
        memory.onRemember = { [weak self] keys, afterPuttingBack in self?.presets.syncActive(keys, afterPuttingBack: afterPuttingBack) }
        presets.onSwitch = { [weak self] preset in self?.switchTo(preset) }
        presets.start()
        editor = LayoutEditorController(model: model, arranger: arranger)
        editor.isGlassInNotch = { [weak self] in self?.arranger.revealAnchor != nil }
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
        bar.onAssignShortcut = { [weak self] key, _ in
            guard let self else { return }
            if !self.settings.model.pendingItemKeys.contains(key) { self.settings.model.pendingItemKeys.append(key) }
            self.settings.show()
        }
        diagnostics = Diagnostics(model: model)
        spacer.onClick = { [weak self] in self?.bar.toggle() }
        spike = SpacerSpike(arranger: arranger, spacer: spacer)
        registerHotKey()
        registerItemHotKeys()
        wireSettings()
        memory.start()
        bar.onNotchMenu = { [weak self] in self?.showNotchMenu() }
        bar.onScreensChange = { [weak self] in self?.applyGlassPlacement() }
        bar.start()
        applyGlassPlacement()
        watcher = ChangeWatcher(model: model, arranger: arranger)
        watcher.canAnnounce = { [weak self] in self?.bar.canAnnounce ?? false }
        watcher.onChange = { [weak self] item in self?.bar.announce(item) }
        watcher.start()
        wireWelcome()
        if !WelcomeController.hasBeenSeen {
            // First launch: explain before asking for anything.
            welcome.show()
        }

        if permissions.isAccessibilityTrusted {
            Task {
                await model.refresh(captureGlyphs: false)
                await startSpacer()
                // The real images, ahead of the first time Whisky Bar opens.
                await model.refresh(captureGlyphs: true)
            }
        } else if WelcomeController.hasBeenSeen {
            permissions.requestAccessibility()
        }
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let shortcut = hotKey == nil ? "" : HotKeyPreference.shortcut.map { "（\($0.display)）" } ?? ""
        menu.addItem(item("打開 Whisky Bar\(shortcut)", #selector(toggleBar)))
        if PlatformSupport.movesItems {
            menu.addItem(item("排列選單列…", #selector(showEditor)))
            menu.addItem(sendBehindNotchItem())
        }
        if let drift = model.layoutDrift {
            let restore = item("排回你排好的版面", #selector(restoreLayoutFromMenu))
            restore.image = NSImage(systemSymbolName: "arrow.uturn.backward.circle", accessibilityDescription: nil)
            restore.toolTip = drift.summary
            menu.addItem(restore)
        }
        menu.addItem(.separator())

        if PlatformSupport.movesItems { menu.addItem(presetsMenuItem()) }

        if PlatformSupport.movesItems {
            let spacerItem = item("只顯示排好的圖示（分隔項目）", #selector(toggleSpacer))
            spacerItem.state = spacer.isActive ? .on : .off
            spacerItem.toolTip = "在排好的圖示左邊放一個分隔項目，把其他圖示推到螢幕外；它們仍可從 Whisky Bar 打開。"
            menu.addItem(spacerItem)
        } else {
            let note = NSMenuItem(title: "\(PlatformSupport.versionName) 還不支援排列與分隔項目", action: nil, keyEquivalent: "")
            note.isEnabled = false
            menu.addItem(note)
        }
        menu.addItem(item("設定…", #selector(showSettings), key: ","))

        if !permissions.isAccessibilityTrusted {
            menu.addItem(item("授權「輔助使用」…", #selector(requestAccessibility)))
        }

        menu.addItem(.separator())
        menu.addItem(item("關於 Whisky", #selector(showAbout)))
        menu.addItem(item("結束 Whisky", #selector(quit), key: "q"))
        return menu
    }

    /// Layout presets: pick one by hand, or save the current arrangement as a new one (in Settings).
    private func presetsMenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "情境版面", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for preset in presets.presets {
            let entry = item(preset.name, #selector(pickPreset(_:)))
            entry.representedObject = preset.id.uuidString
            entry.state = preset.id == presets.activeID ? .on : .off
            entry.toolTip = preset.trigger.title
            submenu.addItem(entry)
        }
        if !presets.presets.isEmpty { submenu.addItem(.separator()) }
        submenu.addItem(item("把目前的版面存成情境…", #selector(showSettings)))
        parent.submenu = submenu
        return parent
    }

    @objc private func pickPreset(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? String).flatMap(UUID.init(uuidString:)) else { return }
        presets.activate(id)
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
        // Asked for now: it replaces any automatic put-back still waiting.
        let previous = putBackTask
        previous?.cancel()
        putBackTask = nil
        Task {
            await previous?.value
            if case .failure(let failure) = await restoreArrangement(automatic: false) {
                ArrangeAlert.show(action: "把圖示排回你排好的版面", failure: failure)
            }
        }
    }

    // MARK: - Shortcut

    private func registerHotKey() {
        hotKey?.unregister()
        hotKey = nil
        hotKeyFailed = false
        model.shortcutDisplay = nil
        guard let shortcut = HotKeyPreference.shortcut else { return }
        hotKey = GlobalHotKey(shortcut) { [weak self] in self?.bar.toggle() }
        hotKeyFailed = hotKey == nil
        model.shortcutDisplay = hotKeyFailed ? nil : shortcut.display
    }

    private func registerItemHotKeys() {
        itemHotKeys.values.forEach { $0.unregister() }
        itemHotKeys = [:]
        for (key, assignment) in ItemHotKeyPreference.all {
            itemHotKeys[key] = GlobalHotKey(assignment.shortcut) { [weak self] in self?.bar.openItem(key: key) }
        }
    }

    /// Assigns or removes an item's shortcut; refuses one already in use. Returns a problem to show, or nil.
    private func setItemHotKey(key: String, name: String, shortcut: HotKeyShortcut?) -> String? {
        var all = ItemHotKeyPreference.all
        if let shortcut {
            if shortcut == HotKeyPreference.shortcut { return "\(shortcut.display) 已經用來打開 Whisky Bar。" }
            if let other = all.first(where: { $0.key != key && $0.value.shortcut == shortcut }) {
                return "\(shortcut.display) 已經指定給「\(other.value.name)」。"
            }
            all[key] = ItemHotKeyPreference.Assignment(shortcut: shortcut, name: name)
        } else {
            all[key] = nil
        }
        ItemHotKeyPreference.all = all
        registerItemHotKeys()
        if let shortcut, itemHotKeys[key] == nil {
            return "\(shortcut.display) 被別的 App 用掉了，換一組試試。"
        }
        Log.write("item shortcut: \(key) → \(shortcut?.display ?? "none")")
        return nil
    }

    // MARK: - Welcome

    private func wireWelcome() {
        welcome.refresh = { [weak self] model in
            guard let self else { return }
            model.hasAccessibility = self.permissions.isAccessibilityTrusted
            model.hasScreenRecording = Permissions.hasScreenRecording
            model.hasNotch = NotchPresenter.isAvailable && self.bar.opensFromNotch
            model.shortcut = HotKeyPreference.shortcut?.display
        }
        welcome.model.requestAccessibility = { [weak self] in self?.requestAccessibility() }
        welcome.model.requestScreenRecording = { [weak self] in
            self?.model.showsRealImages = true
            Permissions.requestScreenRecording()
        }
        welcome.model.showEditor = { [weak self] in
            self?.welcome.close()
            self?.editor.show()
        }
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
                guard let self else { return }
                if recording {
                    // Every shortcut is released while recording, so pressing one records it instead of firing.
                    self.hotKey?.unregister()
                    self.hotKey = nil
                    self.itemHotKeys.values.forEach { $0.unregister() }
                    self.itemHotKeys = [:]
                } else {
                    self.registerHotKey()
                    self.registerItemHotKeys()
                }
            },
            setLaunchAtLogin: { LoginItem.setEnabled($0) },
            setOpensFromNotch: { [weak self] on in
                self?.bar.opensFromNotch = on
                self?.applyGlassPlacement()
            },
            setGlassInNotch: { [weak self] on in self?.glassInNotch = on },
            setAnnouncesChanges: { [weak self] on in self?.watcher.isEnabled = on },
            setPlacesRunAtLaunch: { [weak self] on in self?.placesRunAtLaunch = on },
            savePreset: { [weak self] name, trigger in
                guard let self, let keys = self.memory.saved, !keys.isEmpty else { return }
                self.presets.save(name: name, trigger: trigger, keys: keys)
            },
            deletePreset: { [weak self] id in self?.presets.delete(id) },
            setPresetTrigger: { [weak self] id, trigger in self?.presets.setTrigger(trigger, for: id) },
            renamePreset: { [weak self] id, name in self?.presets.rename(id, to: name) },
            activatePreset: { [weak self] id in self?.presets.activate(id) },
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
            refresh: { [weak self] in self?.refreshSettings() },
            setItemHotKey: { [weak self] key, name, shortcut in self?.setItemHotKey(key: key, name: name, shortcut: shortcut) }
        )
    }

    private func refreshSettings() {
        let model = settings.model
        model.hotKey = HotKeyPreference.shortcut
        model.hotKeyProblem = hotKeyFailed ? "這組快捷鍵被別的 App 用掉了，換一組試試。" : nil
        model.launchAtLogin = LoginItem.isEnabled || LoginItem.needsApproval
        model.loginNeedsApproval = LoginItem.needsApproval
        model.showsRealImages = self.model.showsRealImages
        model.hasNotch = NotchPresenter.isAvailable
        model.opensFromNotch = bar.opensFromNotch
        model.movesItems = PlatformSupport.movesItems
        model.platformName = PlatformSupport.versionName
        model.glassInNotch = glassInNotch
        model.announcesChanges = watcher.isEnabled
        model.placesRunAtLaunch = placesRunAtLaunch
        if model.presets != presets.presets { model.presets = presets.presets }
        model.activePresetID = presets.activeID
        if !model.spacerBusy { model.spacerOn = spacer.isActive }
        model.watchesLayout = memory.isWatching
        model.savedLayoutCount = memory.saved?.count
        model.hasAccessibility = permissions.isAccessibilityTrusted
        model.hasScreenRecording = Permissions.hasScreenRecording

        // Items with their own shortcut, then rows just added; names from the menu bar when the app is running.
        var icons: [pid_t: NSImage] = [:]
        func row(_ item: ScannedItem, shortcut: HotKeyShortcut?) -> SettingsModel.ItemShortcut {
            let icon = icons[item.pid] ?? NSRunningApplication(processIdentifier: item.pid)?.icon
            icons[item.pid] = icon
            let name = ItemNaming.displayName(appName: item.appName, label: item.label,
                                              systemName: SystemItemSymbols.name(key: item.key, bundleID: item.bundleID))
            return SettingsModel.ItemShortcut(key: item.key, name: name, icon: icon, shortcut: shortcut)
        }
        let scan = self.model.lastScan.filter { !BarModel.isSystemOwned($0) }
        let assigned = ItemHotKeyPreference.all
        var rows = assigned.map { key, assignment in
            scan.first { $0.key == key }.map { row($0, shortcut: assignment.shortcut) }
                ?? SettingsModel.ItemShortcut(key: key, name: assignment.name, icon: nil, shortcut: assignment.shortcut)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for key in model.pendingItemKeys where assigned[key] == nil {
            if let item = scan.first(where: { $0.key == key }) { rows.append(row(item, shortcut: nil)) }
        }
        if rows != model.itemShortcuts { model.itemShortcuts = rows }
        let assignable = scan.map { row($0, shortcut: nil) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if assignable.map(\.key) != model.assignableItems.map(\.key) { model.assignableItems = assignable }
    }

    /// Turns the spacer on or off and takes the result as the arrangement. Returns a problem to show, or nil.
    private func setSpacer(_ on: Bool) async -> String? {
        if on, !PlatformSupport.movesItems { return "\(PlatformSupport.versionName) 還不支援分隔項目。" }
        defer { applyGlassPlacement() }
        if !on {
            arranger.disableSpacer()
            applyGlassPlacement()
            // The arrangement stays what it was: without the spacer only what is drawn changes, and the notch
            // boundary may pick other items right away, which isn't the user's arrangement (measured 2026-10-16).
            memory.scheduleCheck(after: .seconds(3))
            return nil
        }
        // Keep the remembered arrangement visible (what is drawn right now may already be off, near the notch).
        await model.refresh(captureGlyphs: false)
        let remembered = memory.saved?.compactMap { model.item(forKey: $0) }.filter { $0.placement != .off }.compactMap(\.windowID)
        if case .failure(let failure) = await arranger.enableSpacer(keeping: remembered?.isEmpty == false ? remembered : nil) {
            arranger.disableSpacer()
            return "沒辦法打開分隔項目：\(failure)。選單列已經還原。"
        }
        await memory.remember()
        return nil
    }

    // MARK: - The glass

    private static let glassInNotchKey = "glassInNotch"

    /// The glass lives in the notch: it leaves the menu bar (one more item fits beside the notch) and only shows up
    /// while items are moved. Needs a notch and Whisky Bar opening from it; otherwise the glass stays in the menu bar.
    private var glassInNotch: Bool {
        get { UserDefaults.standard.object(forKey: Self.glassInNotchKey) as? Bool ?? false }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.glassInNotchKey)
            applyGlassPlacement()
        }
    }

    /// At launch AppKit puts the spacer back where it was, 1 pt wide. Expanding it is only safe when the items right
    /// of it are the arranged run; otherwise it stays collapsed (and the glass in the menu bar) and the drift notice
    /// offers to put things right. Whisky doesn't move items on its own.
    private func startSpacer() async {
        // The preset the conditions call for now: its arrangement is what the launch check compares with.
        if let preset = presets.selectForLaunch(), !preset.keys.isEmpty, preset.keys != memory.saved {
            memory.saved = preset.keys
        }
        await spacer.start()
        if spacer.isActive {
            // Let the menu bar finish laying out the new spacer before judging (measured: a second after creation
            // a neighbour was still on the wrong side; two seconds later it was right), and look twice. While the
            // menu bar is hidden (a full-screen app) nothing can be judged: wait for it.
            try? await Task.sleep(for: .milliseconds(1500))
            var check = await memory.checkRunAtLaunch()
            if check == .differs {
                try? await Task.sleep(for: .milliseconds(1500))
                check = await memory.checkRunAtLaunch()
            }
            var waited = 0
            while check == .undecided, waited < 300 {
                try? await Task.sleep(for: .seconds(2))
                waited += 2
                check = await memory.checkRunAtLaunch()
            }
            switch check {
            case .matches:
                if !spacer.isExpanded { spacer.setExpanded(true) }
                presets.confirmPending()
            case .differs where placesRunAtLaunch:
                applyGlassPlacement()
                requestPutBack(status: "正在排回你的版面，先別動滑鼠")
            case .differs, .undecided:
                // Fail open: arranged items AppKit put left of the spacer must not stay off the screen.
                spacer.setExpanded(false)
                Log.write("spacer: left collapsed until the arrangement is put back")
                memory.scheduleCheck(after: .seconds(2))
            }
        }
        applyGlassPlacement()
    }

    private static let placesRunAtLaunchKey = "placesRunAtLaunch"

    /// Put the arrangement back by itself after a relaunch (once the user is idle), rather than only point it out.
    private var placesRunAtLaunch: Bool {
        get { UserDefaults.standard.object(forKey: Self.placesRunAtLaunchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.placesRunAtLaunchKey) }
    }

    /// Waits until the mouse and keyboard have been still for 3 s (moving items takes the pointer over for a few
    /// seconds) and the menu bar is showing, then puts the arrangement back the reliable way. Gives up after ten
    /// minutes and leaves the drift notice instead.
    /// The one automatic put-back under way (or waiting for the user to be idle). A new request replaces it: two at
    /// once would interleave their drags, and one finishing late would overwrite the arrangement asked for since.
    private var putBackTask: Task<Void, Never>?

    private func requestPutBack(status: String) {
        let previous = putBackTask
        previous?.cancel()
        putBackTask = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled else { return }
            await self?.putBackWhenIdle(status: status)
        }
    }

    /// Waits until the user has left the mouse and keyboard alone for 5 s (and the menu bar shows, nothing else is
    /// moving, Whisky Bar is closed), then puts the remembered arrangement in place. Gives up after ten minutes and
    /// leaves the drift notice instead.
    private func putBackWhenIdle(status: String) async {
        Log.write("layout: will put the arrangement in place once the user is idle")
        let deadline = ContinuousClock.now + .seconds(600)
        var ready = false
        while !Task.isCancelled, ContinuousClock.now < deadline {
            guard await Arranger.waitUntilUserIdle(5, timeout: deadline - ContinuousClock.now) else { break }
            if arranger.isMenuBarShown(), !arranger.isBusy, !bar.isOpen {
                ready = true
                break
            }
            try? await Task.sleep(for: .seconds(1))
        }
        guard ready, !Task.isCancelled else {
            if !Task.isCancelled {
                Log.write("layout: still not put back after ten minutes; the drift notice offers it")
                memory.scheduleCheck(after: .zero)
            }
            return
        }
        Log.write("layout: putting the arrangement in place (idle \(Int(Arranger.userIdleSeconds)) s)")
        await restoreArrangement(automatic: true, status: status)
    }

    /// The conditions changed, or the user picked a preset: its arrangement becomes the one to keep.
    private func switchTo(_ preset: LayoutPreset) {
        guard !preset.keys.isEmpty else { return }
        memory.saved = preset.keys
        requestPutBack(status: "換成「\(preset.name)」版面，先別動滑鼠")
    }

    /// Puts the remembered arrangement back, showing it at the notch while it happens.
    @discardableResult
    private func restoreArrangement(automatic: Bool, status: String = "正在排回你的版面，先別動滑鼠") async -> Result<Int, ItemMover.Failure> {
        bar.showStatus(status)
        arranger.pausesForUser = automatic
        let result = await memory.restore(automatic: automatic)
        arranger.pausesForUser = false
        bar.showStatus(nil)
        applyGlassPlacement()
        if case .failure(let failure) = result { Log.write("layout: putting it back failed: \(failure)") }
        return result
    }

    private func applyGlassPlacement() {
        // Only with the spacer: without it, macOS reshuffles the items beside the notch whenever the glass leaves
        // (measured 2026-10-15), which would undo the user's arrangement every time.
        // And only once the spacer is expanded: put back by AppKit at launch it is 1 pt wide and does nothing yet.
        let inNotch = PlatformSupport.movesItems && glassInNotch && bar.opensFromNotch && NotchPresenter.isAvailable
            && spacer.isActive && spacer.isExpanded
        if inNotch {
            arranger.revealAnchor = { [weak self] in self?.statusItem.setShown(true) }
            arranger.concealAnchor = { [weak self] in self?.statusItem.setShown(false) }
            // Not while an operation needs the glass (showing an item for a moment can hold it for minutes).
            if !arranger.isHoldingAnchor { arranger.rememberGlassNeighbour(); statusItem.setShown(false) }
        } else {
            arranger.revealAnchor = nil
            arranger.concealAnchor = nil
            statusItem.setShown(true)
        }
    }

    /// Whisky's menu from the notch (right click), for when the glass isn't in the menu bar.
    private func showNotchMenu() {
        guard let notch = NotchGeometry.current() else { return }
        makeMenu().popUp(positioning: nil, at: NSPoint(x: notch.rect.minX + 8, y: notch.rect.minY - 2), in: nil)
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
            case ("spike", _):
                // whisky://spike?glass=notch runs it with the glass living in the notch (shown only while moving).
                let inNotch = url.query()?.contains("glass=notch") == true
                Task {
                    if inNotch {
                        // The test brings its own spacer, so set the glass up directly rather than through the setting.
                        arranger.revealAnchor = { [weak self] in self?.statusItem.setShown(true) }
                        arranger.concealAnchor = { [weak self] in self?.statusItem.setShown(false) }
                        statusItem.setShown(false)
                    }
                    await spike?.run(isGlassShown: { [weak self] in self?.statusItem.isShown ?? true },
                                     includesWideRun: url.query()?.contains("wide=1") == true)
                    applyGlassPlacement()
                }
            // The same as the switches in Settings (the layout is remembered, the glass follows).
            case ("spacer-on", _): Task { Log.write("url spacer-on: \(await setSpacer(true) ?? "done")") }
            case ("spacer-off", _): Task { _ = await setSpacer(false) }
            case ("glass-in-notch", _): glassInNotch = url.query()?.contains("on=1") == true
            case ("move", _):
                // Debugging: whisky://move?item=<window ID>&leftOf=<window ID> (or rightOf=).
                let query = Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
                guard let item = query["item"].flatMap(UInt32.init) else { break }
                let destination: MoveDestination? = query["leftOf"].flatMap(UInt32.init).map { .leftOf($0) } ?? query["rightOf"].flatMap(UInt32.init).map { .rightOf($0) }
                if let destination { Task { _ = await arranger.moveRaw(item, to: destination) } }
            case ("arrange", _): editor.show()
            case ("settings", _): settings.show()
            case ("welcome", _): welcome.show()
            case ("save-preset", _):
                // whisky://save-preset?name=<name>&trigger=otherwise|externalDisplay|onBattery|manual
                let query = Dictionary((URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
                if let name = query["name"], !name.isEmpty, let keys = memory.saved, !keys.isEmpty {
                    presets.save(name: name, trigger: LayoutPreset.Trigger(rawValue: query["trigger"] ?? "") ?? .manual, keys: keys)
                }
            case ("preset", _):
                // whisky://preset?name=<name>: switch to it by hand.
                let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "name" }?.value
                if let preset = presets.presets.first(where: { $0.name == name }) { presets.activate(preset.id) }
            case ("login-item", _):
                // The same as the switch in Settings: whisky://login-item?on=1 or on=0.
                LoginItem.setEnabled(url.query()?.contains("on=1") == true)
                Log.write("login item: \(LoginItem.isEnabled ? "on" : LoginItem.needsApproval ? "needs approval" : "off")")
            case ("notch-peek", _): bar.showNotchPeekForTesting()
            case ("notch-alert", _):
                // Testing: points out the first hidden item as if it had changed.
                if let item = model.items.first(where: { !$0.isOff }) { bar.announce(item) }
            case ("glass", _):
                // Testing: whisky://glass?shown=0 or 1 hides or shows the glass in the menu bar.
                statusItem.setShown(url.query()?.contains("shown=1") == true)
            case ("snapshot", _):
                WindowSnapshot.writeVisibleWindows(scrolledToBottom: url.query()?.contains("scroll=bottom") == true)
                // whisky://snapshot?close=1 closes the windows afterwards (testing without leaving them open).
                if url.query()?.contains("close=1") == true {
                    bar.close()
                    NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }.forEach { $0.performClose(nil) }
                }
            case ("check-layout", _): Task { await memory.check() }
            case ("remember-layout", _): Task { await memory.remember() }
            case ("restore-layout", _): restoreLayout()
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
