import SwiftUI

struct LayoutEditorView: View {
    let draft: LayoutDraft
    let onImportBartender: () -> Void
    let onRevert: () -> Void
    let onApply: () -> Void

    private let tileColumns = [GridItem(.adaptive(minimum: 76), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            visibleSection
            Divider()
            hiddenSection
            if !draft.off.isEmpty {
                offSection
            }
            Divider()
            footer
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 520, alignment: .topLeading)
    }

    // MARK: - Sections

    private var visibleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("選單列上", detail: "從左到右排列，最右邊緊鄰 Whisky 圖示。放不下的會被瀏海擋住，還是能從 Whisky Bar 打開。")
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(draft.visible.enumerated()), id: \.element.id) { index, entry in
                        tile(entry, dimmed: index < draft.overflowCount)
                            .dropDestination(for: String.self) { keys, _ in
                                guard let key = keys.first else { return false }
                                draft.showItem(key, before: entry.id)
                                return true
                            }
                            .contextMenu {
                                Button("收進 Whisky Bar") { draft.hideItem(entry.id) }
                            }
                    }
                    dropSlot
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.visible)
            capacityLine
        }
    }

    /// Drop here to put an item at the right end, next to Whisky's icon.
    private var dropSlot: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .foregroundStyle(.tertiary)
            .frame(width: 70, height: 64)
            .overlay(Text("放到最右邊").font(.caption2).foregroundStyle(.secondary))
            .dropDestination(for: String.self) { keys, _ in
                guard let key = keys.first else { return false }
                draft.showItem(key)
                return true
            }
    }

    private var capacityLine: some View {
        let used = Int(draft.usedWidth.rounded())
        let capacity = Int(draft.capacity.rounded())
        return Text(draft.overflowCount > 0
                    ? "用了 \(used) / \(capacity) pt：最左邊 \(draft.overflowCount) 個會被瀏海擋住（變淡的那幾個）"
                    : "用了 \(used) / \(capacity) pt，全部放得下。剩下的空間由 Whisky 的分隔項目留白。")
            .font(.caption)
            .foregroundStyle(draft.overflowCount > 0 ? .orange : .secondary)
    }

    private var hiddenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("收進 Whisky Bar", detail: "把圖示拖到上面就會放回選單列；按右鍵也可以。")
            ScrollView {
                LazyVGrid(columns: tileColumns, alignment: .leading, spacing: 6) {
                    ForEach(draft.hidden) { entry in
                        tile(entry, dimmed: false)
                            .contextMenu {
                                Button("放到選單列（最右邊）") { draft.showItem(entry.id) }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 90, maxHeight: 220)
            .dropDestination(for: String.self) { keys, _ in
                guard let key = keys.first else { return false }
                draft.hideItem(key)
                return true
            }
        }
    }

    private var offSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            header("不在選單列上", detail: "這些 App 的圖示被關掉了（例如以前用 Bartender 隱藏），要先到「系統設定 › 選單列」打開才能排列。它們的選單仍可從 Whisky Bar 打開。")
            LazyVGrid(columns: tileColumns, alignment: .leading, spacing: 6) {
                ForEach(draft.off) { entry in
                    tile(entry, dimmed: true, draggable: false)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("從 Bartender 匯入", action: onImportBartender)
                .disabled(draft.isApplying)
            if let note = draft.note {
                Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            statusView
            Button("還原", action: onRevert)
                .disabled(draft.isApplying || !draft.hasChanges)
            Button("套用", action: onApply)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.isApplying || !draft.hasChanges)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch draft.status {
        case .idle:
            EmptyView()
        case .applying(let done, let total):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("移動中 \(done)/\(total)，請先不要動滑鼠").font(.caption)
            }
        case .finished(let moves):
            Text(moves == 0 ? "已經是這個順序了" : "完成，移動了 \(moves) 個圖示").font(.caption).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
        }
    }

    // MARK: - Pieces

    private func header(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func tile(_ entry: LayoutDraft.Entry, dimmed: Bool, draggable: Bool = true) -> some View {
        let content = VStack(spacing: 4) {
            Group {
                if let icon = entry.icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: "app.dashed").resizable().scaledToFit()
                }
            }
            .frame(width: 28, height: 28)
            Text(entry.title)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 70, height: 64)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
        .opacity(dimmed ? 0.45 : 1)
        .help(entry.tooltip)

        if draggable && !draft.isApplying {
            content.draggable(entry.id) {
                Image(nsImage: entry.icon ?? NSImage()).resizable().frame(width: 28, height: 28)
            }
        } else {
            content
        }
    }
}
