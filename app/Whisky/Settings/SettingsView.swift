import SwiftUI
import WhiskyCore

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Whisky")
                            .font(.title2.weight(.semibold))
                        Text("給瀏海 Mac 的選單列工具 · \(model.version)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Link("GitHub", destination: URL(string: "https://github.com/chung223/whisky")!)
                        Button("記錄檔", action: model.actions.revealLog)
                            .buttonStyle(.link)
                    }
                    .font(.callout)
                }
                .padding(.vertical, 4)
                Toggle("登入時自動開啟", isOn: binding(\.launchAtLogin, model.actions.setLaunchAtLogin))
                if model.loginNeedsApproval {
                    LabeledContent {
                        Button("打開登入項目設定…", action: model.actions.openLoginItems)
                    } label: {
                        note("要在「系統設定 › 一般 › 登入項目」允許 Whisky。", warning: true)
                    }
                }
            }

            if !model.movesItems {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(model.platformName) 還沒完整支援")
                                .font(.headline)
                            Text("這版 macOS 的選單列整個重寫了。Whisky 現在只會幫你打開被藏起來的圖示（重建選單、直接點按），不會移動任何圖示：排列、分隔項目、自動排回、酒杯住在瀏海裡都暫時停用。")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
            }

            Section("Whisky Bar") {
                LabeledContent("打開 Whisky Bar 的快捷鍵") {
                    ShortcutRecorder(
                        shortcut: model.hotKey,
                        onChange: { model.actions.setHotKey($0) },
                        onRecordingChange: { model.actions.setRecordingHotKey($0) }
                    )
                }
                if let problem = model.hotKeyProblem {
                    note(problem, warning: true)
                }
                Toggle(isOn: binding(\.opensFromNotch, model.actions.setOpensFromNotch)) {
                    Text("從瀏海打開")
                    Text(model.hasNotch
                         ? "游標移到瀏海會提示藏了幾個圖示，點一下展開。"
                         : "這個螢幕沒有瀏海，從酒杯下方打開。")
                }
                .disabled(!model.hasNotch)
                Toggle(isOn: binding(\.glassInNotch, model.actions.setGlassInNotch)) {
                    Text("酒杯住在瀏海裡")
                    Text(!model.movesItems
                         ? "\(model.platformName) 暫不支援。"
                         : model.spacerOn
                         ? "選單列上不放酒杯，多一格給排好的圖示；只有搬移圖示時酒杯才出來。右鍵點瀏海打開 Whisky 的選單。"
                         : "要先打開下面的「只顯示排好的圖示」：沒有它的話，酒杯一離開，macOS 就會重排瀏海旁的圖示。")
                }
                .disabled(!model.hasNotch || !model.opensFromNotch || !model.spacerOn || !model.movesItems)
                Toggle(isOn: binding(\.announcesChanges, model.actions.setAnnouncesChanges)) {
                    Text("藏起來的圖示有變化時提醒我")
                    Text(model.hasScreenRecording
                         ? "例如出現通知標記：瀏海會長出來幾秒顯示它，點一下打開。一直在變的數字（CPU、網速）不算。"
                         : "需要「螢幕錄製」權限。")
                }
                .disabled(!model.hasNotch || !model.opensFromNotch || !model.hasScreenRecording || !model.movesItems)
                Toggle(isOn: binding(\.showsRealImages, model.actions.setShowsRealImages)) {
                    Text("顯示圖示的真實圖案")
                    Text(model.hasScreenRecording
                         ? "照圖示在選單列上的樣子顯示。"
                         : "需要「螢幕錄製」權限；沒有的話顯示 App 圖示。")
                }
            }

            Section {
                ForEach(model.itemShortcuts) { row in
                    LabeledContent {
                        ShortcutRecorder(
                            shortcut: row.shortcut,
                            onChange: { shortcut in
                                model.itemShortcutProblem = model.actions.setItemHotKey(row.key, row.name, shortcut)
                                if shortcut == nil || model.itemShortcutProblem == nil {
                                    model.pendingItemKeys.removeAll { $0 == row.key }
                                }
                                model.actions.refresh()
                            },
                            onRecordingChange: { model.actions.setRecordingHotKey($0) },
                            offersDefault: false
                        )
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = row.icon {
                                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                            }
                            Text(row.name)
                        }
                    }
                }
                if let problem = model.itemShortcutProblem {
                    note(problem, warning: true)
                }
                Menu("新增圖示快捷鍵…") {
                    ForEach(model.assignableItems.filter { item in !model.itemShortcuts.contains { $0.key == item.key } }) { item in
                        Button(item.name) {
                            model.pendingItemKeys.append(item.key)
                            model.actions.refresh()
                        }
                    }
                }
                .menuStyle(.button)
                .fixedSize()
            } header: {
                Text("圖示快捷鍵")
            } footer: {
                Text("按下就直接打開那個圖示，不用先開 Whisky Bar。也可以在 Whisky Bar 對圖示按右鍵指定。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("選單列") {
                Toggle(isOn: Binding(
                    get: { model.spacerOn },
                    set: { on in
                        model.spacerBusy = true
                        model.spacerProblem = nil
                        Task {
                            model.spacerProblem = await model.actions.setSpacer(on)
                            model.spacerBusy = false
                            model.actions.refresh()
                        }
                    }
                )) {
                    HStack(spacing: 6) {
                        Text("只顯示排好的圖示（分隔項目）")
                        if model.spacerBusy { ProgressView().controlSize(.mini) }
                    }
                    Text("其他圖示推到螢幕外，不會因為某個圖示變寬而被補位。")
                }
                .disabled(model.spacerBusy || !model.hasAccessibility || !model.movesItems)
                if let problem = model.spacerProblem {
                    note(problem, warning: true)
                }
                if model.spacerOn {
                    Toggle(isOn: binding(\.placesRunAtLaunch, model.actions.setPlacesRunAtLaunch)) {
                        Text("重新啟動後自動排回來")
                        Text("開機或更新後，分隔項目偶爾會被放錯位置。等你停下滑鼠幾秒後自動排好；關掉的話只提醒你。")
                    }
                }

                Toggle(isOn: binding(\.watchesLayout, model.actions.setWatchesLayout)) {
                    Text("版面跑掉時提醒我")
                    Text("App 重開或更新後圖示換了位置時提醒你，按一下排回來。")
                }
                .disabled(!model.hasAccessibility)
                if model.watchesLayout, let count = model.savedLayoutCount {
                    LabeledContent("記住的版面：\(count) 個圖示") {
                        Button("改成目前的版面") { Task { await model.actions.keepCurrentLayout(); model.actions.refresh() } }
                    }
                }
                LabeledContent("決定哪些圖示留在選單列上") {
                    Button("排列選單列…", action: model.actions.showEditor)
                }
                .disabled(!model.hasAccessibility || !model.movesItems)
            }

            PresetSection(model: model)

            Section("權限") {
                permission("輔助使用", granted: model.hasAccessibility, required: true,
                           purpose: "讀取與移動選單列圖示。", action: model.actions.requestAccessibility)
                permission("螢幕錄製", granted: model.hasScreenRecording, required: false,
                           purpose: "選用：顯示圖示的真實圖案。", action: model.actions.requestScreenRecording)
            }

        }
        .formStyle(.grouped)
        // Fits a 14-inch screen; the rest scrolls.
        .frame(width: 520, height: 740)
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<SettingsModel, Bool>, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { value in
                model[keyPath: keyPath] = value
                set(value)
                model.actions.refresh()
            }
        )
    }

    private func note(_ text: String, warning: Bool) -> some View {
        Label(text, systemImage: warning ? "exclamationmark.triangle.fill" : "info.circle")
            .font(.callout)
            .foregroundStyle(warning ? .orange : .secondary)
    }

    private func permission(_ name: String, granted: Bool, required: Bool, purpose: String, action: @escaping () -> Void) -> some View {
        LabeledContent {
            if granted {
                Label("已授權", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("授權…", action: action)
            }
        } label: {
            Text(name + (required ? "（必要）" : ""))
            Text(purpose)
        }
    }
}
