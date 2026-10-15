import SwiftUI
import WhiskyCore

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
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
                         ? "游標移到瀏海會長出一點、顯示藏了幾個圖示，點一下就從瀏海展開。關掉的話從選單列的酒杯下方打開。"
                         : "這個螢幕沒有瀏海，Whisky Bar 從選單列的酒杯下方打開。")
                }
                .disabled(!model.hasNotch)
                Toggle(isOn: binding(\.showsRealImages, model.actions.setShowsRealImages)) {
                    Text("顯示圖示的真實圖案")
                    Text(model.hasScreenRecording
                         ? "被瀏海擋住的圖示照它在選單列上的樣子顯示。被分隔項目推到螢幕外的圖示截不到，仍顯示 App 圖示。"
                         : "需要「螢幕錄製」權限；沒有的話顯示 App 圖示（Apple 的系統圖示用對應的符號）。")
                }
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
                    Text("在排好的圖示左邊放一個分隔項目，把其他圖示推到螢幕外，不會因為某個圖示變寬就被別的圖示補位。被推走的圖示一樣能從 Whisky Bar 打開。")
                }
                .disabled(model.spacerBusy || !model.hasAccessibility)
                if let problem = model.spacerProblem {
                    note(problem, warning: true)
                }

                Toggle(isOn: binding(\.watchesLayout, model.actions.setWatchesLayout)) {
                    Text("版面跑掉時提醒我")
                    Text("App 更新或重開後，圖示有時會換位置。Whisky 記住你排好的版面，跑掉時在 Whisky Bar 提醒你，按一下就排回來；不會自己移動圖示。")
                }
                .disabled(!model.hasAccessibility)
                if model.watchesLayout, let count = model.savedLayoutCount {
                    LabeledContent("記住的版面：\(count) 個圖示") {
                        Button("改成目前的版面") { Task { await model.actions.keepCurrentLayout(); model.actions.refresh() } }
                    }
                }
                LabeledContent("決定哪些圖示留在選單列上、順序如何") {
                    Button("排列選單列…", action: model.actions.showEditor)
                }
                .disabled(!model.hasAccessibility)
            }

            Section("一般") {
                Toggle("登入時自動開啟", isOn: binding(\.launchAtLogin, model.actions.setLaunchAtLogin))
                if model.loginNeedsApproval {
                    LabeledContent {
                        Button("打開登入項目設定…", action: model.actions.openLoginItems)
                    } label: {
                        note("要在「系統設定 › 一般 › 登入項目」允許 Whisky。", warning: true)
                    }
                }
            }

            Section("權限") {
                permission("輔助使用", granted: model.hasAccessibility, required: true,
                           purpose: "讀取選單列圖示與它們的選單、移動圖示。", action: model.actions.requestAccessibility)
                permission("螢幕錄製", granted: model.hasScreenRecording, required: false,
                           purpose: "選用：在 Whisky Bar 顯示圖示的真實圖案。", action: model.actions.requestScreenRecording)
            }

            Section {
                HStack {
                    Text("Whisky \(model.version)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Link("GitHub", destination: URL(string: "https://github.com/chung223/whisky")!)
                    Button("記錄檔", action: model.actions.revealLog)
                        .buttonStyle(.link)
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
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
