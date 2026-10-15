import SwiftUI

/// What the welcome window shows; the owner keeps the permission states fresh.
@MainActor
@Observable
final class WelcomeModel {
    var hasAccessibility = false
    var hasScreenRecording = false
    var hasNotch = false
    var shortcut: String?

    @ObservationIgnored var requestAccessibility: () -> Void = {}
    @ObservationIgnored var requestScreenRecording: () -> Void = {}
    @ObservationIgnored var showEditor: () -> Void = {}
    @ObservationIgnored var finish: () -> Void = {}
}

/// First launch: what Whisky is for, the one permission it needs, and where it lives (the notch).
struct WelcomeView: View {
    let model: WelcomeModel
    /// The glass pours once, when the window opens (not again on every refresh).
    @State private var pourStart = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                PouringGlass(start: pourStart)
                    .frame(width: 44, height: 44)
                    .padding(10)
                    .background(.black, in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("歡迎使用 Whisky")
                        .font(.title2.weight(.semibold))
                    Text("把被瀏海擋住的選單列圖示找回來。")
                        .foregroundStyle(.secondary)
                }
            }

            step(number: 1, title: "授權「輔助使用」", done: model.hasAccessibility) {
                Text("Whisky 要靠它讀出選單列上的圖示和它們的選單，也要靠它幫你排列。授權後不用重開。")
                if !model.hasAccessibility {
                    Button("打開系統設定…", action: model.requestAccessibility)
                }
            }

            step(number: 2, title: model.hasNotch ? "瀏海就是 Whisky" : "選單列上的酒杯就是 Whisky", done: false) {
                if model.hasNotch {
                    Label("游標移到瀏海：長出一點，告訴你藏了幾個圖示", systemImage: "cursorarrow.motionlines")
                    Label("點一下瀏海：打開 Whisky Bar，點圖示就能用它", systemImage: "cursorarrow.click")
                    Label("右鍵點瀏海：設定、排列選單列", systemImage: "contextualmenu.and.cursorarrow")
                } else {
                    Label("點酒杯：打開 Whisky Bar", systemImage: "cursorarrow.click")
                    Label("右鍵點酒杯：設定、排列選單列", systemImage: "contextualmenu.and.cursorarrow")
                }
                if let shortcut = model.shortcut {
                    Label("或按 \(shortcut)，在哪裡都能打開", systemImage: "keyboard")
                }
            }

            step(number: 3, title: "選用：「螢幕錄製」", done: model.hasScreenRecording) {
                Text("讓 Whisky Bar 顯示圖示真正的樣子，並在藏起來的圖示有變化時提醒你。不給也能用，只是顯示 App 圖示。")
                if !model.hasScreenRecording {
                    Button("授權…", action: model.requestScreenRecording)
                }
            }

            HStack {
                Button("排列選單列…", action: model.showEditor)
                    .disabled(!model.hasAccessibility)
                Spacer()
                Button("開始使用", action: model.finish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func step<Content: View>(number: Int, title: String, done: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : Color.accentColor.opacity(0.15))
                if done {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.callout.weight(.semibold)).foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                content()
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
