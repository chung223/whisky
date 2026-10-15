import SwiftUI

/// The "Arrange Menu Bar" window: a preview of the menu bar right of the notch (drag to reorder), and a tray of the
/// items kept in Whisky Bar (drag up to show one). Nothing moves until Apply.
struct LayoutEditorView: View {
    let draft: LayoutDraft
    let onImportBartender: () -> Void
    let onRevert: () -> Void
    let onApply: () -> Void

    @State private var showsOff = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if draft.isMenuBarHidden {
                    hiddenMenuBarNotice
                } else {
                    menuBarPreview
                    capacityLine
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tray
                    if !draft.off.isEmpty { offSection }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dropDestination(for: String.self) { keys, _ in
                guard let key = keys.first else { return false }
                draft.hideItem(key)
                return true
            }

            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(minWidth: 780, minHeight: 480, alignment: .topLeading)
    }

    private var hiddenMenuBarNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "menubar.dock.rectangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("選單列現在是隱藏的")
                    .font(.headline)
                Text("可能是在全螢幕 App 裡，或打開了「自動隱藏選單列」。讓選單列出現後再重新讀取。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("重新讀取", action: onRevert)
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
    }

    // MARK: - Menu bar preview

    /// The menu bar as it will look: app menus, the notch, the arranged items (the leftmost ones dimmed when they
    /// won't fit beside the notch), Whisky's glass, and the fixed items right of it.
    private var menuBarPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("選單列")
                .font(.headline)
            HStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "apple.logo")
                    Text("檔案")
                    Text("編輯")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 14)
                Spacer(minLength: 16)
                notch
                HStack(spacing: 2) {
                    ForEach(Array(draft.visible.enumerated()), id: \.element.id) { index, entry in
                        previewItem(entry, overflow: index < draft.overflowCount)
                    }
                    endSlot
                }
                .padding(.horizontal, 6)
                if !draft.glassInNotch { whiskyGlass }
                HStack(spacing: 2) {
                    ForEach(draft.fixed) { entry in
                        ItemImage(glyph: draft.glyphs[entry.id], symbol: entry.symbol, appIcon: entry.icon, onDark: true)
                            .padding(.horizontal, 4)
                            .opacity(0.5)
                            .help("\(entry.tooltip)（系統管理，不能移動）")
                    }
                }
                .padding(.trailing, 10)
            }
            .frame(height: 34)
            .background(Color(white: 0.13), in: .rect(cornerRadius: 10))
            .environment(\.colorScheme, .dark)
            Text("拖曳圖示調整順序；拖到下面就收進 Whisky Bar。右鍵也可以。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var notch: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9)
            .fill(.black)
            .frame(width: 120, height: 34)
            .overlay(alignment: .bottom) {
                HStack(spacing: 4) {
                    if draft.glassInNotch {
                        Image(nsImage: GlassIcon.image(fill: 1))
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    Text("瀏海")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.white.opacity(draft.glassInNotch ? 0.55 : 0.3))
                .padding(.bottom, 4)
                .help(draft.glassInNotch ? "酒杯住在瀏海裡：排好的圖示從控制中心左邊往左排" : "")
            }
    }

    private var whiskyGlass: some View {
        Image(nsImage: GlassIcon.image(fill: 1))
            .renderingMode(.template)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .help("Whisky：排好的圖示從這裡往左排")
    }

    private func previewItem(_ entry: LayoutDraft.Entry, overflow: Bool) -> some View {
        ItemImage(glyph: draft.glyphs[entry.id], symbol: entry.symbol, appIcon: entry.icon, onDark: true)
            .frame(minWidth: 20, minHeight: 24)
            .padding(.horizontal, 4)
            .contentShape(.rect)
            .opacity(overflow ? 0.3 : 1)
            .help(overflow ? "\(entry.tooltip)（放不下，會被瀏海擋住）" : entry.tooltip)
            .modifier(Draggable(id: entry.id, enabled: !draft.isApplying) {
                ItemImage(glyph: draft.glyphs[entry.id], symbol: entry.symbol, appIcon: entry.icon, onDark: true)
            })
            .dropDestination(for: String.self) { keys, _ in
                guard let key = keys.first else { return false }
                draft.showItem(key, before: entry.id)
                return true
            }
            .contextMenu {
                Button("收進 Whisky Bar") { draft.hideItem(entry.id) }
            }
    }

    /// Drop here to put an item at the right end, next to Whisky's icon.
    private var endSlot: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
            .foregroundStyle(.white.opacity(0.25))
            .frame(width: 18, height: 22)
            .help("拖到這裡：放在最右邊，緊鄰 Whisky")
            .dropDestination(for: String.self) { keys, _ in
                guard let key = keys.first else { return false }
                draft.showItem(key)
                return true
            }
    }

    private var capacityLine: some View {
        let used = draft.usedWidth
        let capacity = max(draft.capacity, 1)
        let over = draft.overflowCount > 0
        return HStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(over ? Color.orange : Color.accentColor)
                        .frame(width: proxy.size.width * min(1, used / capacity))
                }
            }
            .frame(width: 160, height: 5)
            Text(over
                 ? "超出 \(Int((used - capacity).rounded())) pt：最左邊 \(draft.overflowCount) 個會被瀏海擋住"
                 : "瀏海右邊還有 \(Int((capacity - used).rounded())) pt")
                .font(.caption)
                .foregroundStyle(over ? .orange : .secondary)
        }
    }

    // MARK: - Tray

    private var tray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("收在 Whisky Bar")
                    .font(.headline)
                Text("\(draft.hidden.count)")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("拖上去就放回選單列")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if draft.hidden.isEmpty {
                Text("所有圖示都在選單列上。把上面的圖示拖到這裡就會收進 Whisky Bar。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(draft.hidden) { entry in
                        tile(entry)
                            .modifier(Draggable(id: entry.id, enabled: !draft.isApplying) {
                                ItemImage(glyph: draft.glyphs[entry.id], symbol: entry.symbol, appIcon: entry.icon)
                            })
                            .contextMenu {
                                Button("放到選單列（最右邊）") { draft.showItem(entry.id) }
                            }
                    }
                }
            }
        }
    }

    private var offSection: some View {
        DisclosureGroup(isExpanded: $showsOff) {
            VStack(alignment: .leading, spacing: 10) {
                Text("這些 App 的圖示被關掉了（例如以前用 Bartender 隱藏），要先到「系統設定 › 選單列」打開才能排列。它們的選單一樣能從 Whisky Bar 打開。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(draft.off) { entry in
                        tile(entry).opacity(0.6)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text("不在選單列上")
                    .font(.headline)
                Text("\(draft.off.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tile(_ entry: LayoutDraft.Entry) -> some View {
        VStack(spacing: 5) {
            ItemImage(glyph: draft.glyphs[entry.id], symbol: entry.symbol, appIcon: entry.icon)
                .frame(height: 22)
            Text(entry.title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 76, height: 56)
        .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 9))
        .help(entry.tooltip)
    }

    // MARK: - Footer

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
                .disabled(draft.isApplying || !draft.hasChanges || draft.isMenuBarHidden)
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
                Text("移動中 \(done)/\(total)，先不要動滑鼠").font(.caption)
            }
        case .finished(let moves):
            Text(moves == 0 ? "已經是這個順序了" : "完成，移動了 \(moves) 個圖示").font(.caption).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
        }
    }
}

/// `.draggable` only while dragging is allowed (not while Apply is moving items).
private struct Draggable<Preview: View>: ViewModifier {
    let id: String
    let enabled: Bool
    @ViewBuilder let preview: () -> Preview

    func body(content: Content) -> some View {
        if enabled {
            content.draggable(id, preview: preview)
        } else {
            content
        }
    }
}
