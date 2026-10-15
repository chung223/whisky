import SwiftUI
import WhiskyCore

/// Settings › 情境版面: the saved arrangements, when each one takes over, and saving the current one.
struct PresetSection: View {
    @Bindable var model: SettingsModel

    @State private var newName = ""
    @State private var newTrigger: LayoutPreset.Trigger = .externalDisplay

    var body: some View {
        Section {
            if model.presets.isEmpty {
                Text("把目前排好的圖示存成一個情境，再指定什麼時候自動換過去，例如接上外接螢幕時多顯示幾個。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.presets) { preset in
                row(preset)
            }
            HStack(spacing: 8) {
                TextField("新情境的名稱", text: $newName, prompt: Text("新情境的名稱"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                Picker("", selection: $newTrigger) {
                    ForEach(LayoutPreset.Trigger.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
                Button("存成新情境") {
                    model.actions.savePreset(newName.trimmingCharacters(in: .whitespaces), newTrigger)
                    newName = ""
                    model.actions.refresh()
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("情境版面")
        } footer: {
            Text("存的是目前排好的圖示。在某個情境下重新排列，會存回那個情境。切換時會等你停下滑鼠再搬。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ preset: LayoutPreset) -> some View {
        let isActive = preset.id == model.activePresetID
        return HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.green : Color.secondary)
                .help(isActive ? "現在用的情境" : "")
            Text(preset.name)
            Text("\(preset.keys.count) 個圖示")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: Binding(
                get: { preset.trigger },
                set: { trigger in
                    model.actions.setPresetTrigger(preset.id, trigger)
                    model.actions.refresh()
                }
            )) {
                ForEach(LayoutPreset.Trigger.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            if !isActive {
                Button("換成這個") {
                    model.actions.activatePreset(preset.id)
                    model.actions.refresh()
                }
            }
            Button {
                model.actions.deletePreset(preset.id)
                model.actions.refresh()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("刪除這個情境")
        }
    }
}
