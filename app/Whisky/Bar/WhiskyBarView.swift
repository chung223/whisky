import SwiftUI

struct WhiskyBarView: View {
    let model: BarModel
    let maxWidth: CGFloat
    let onOpen: (BarItem) -> Void
    let onPress: (BarItem) -> Void
    let onActivateApp: (BarItem) -> Void
    let onPin: (BarItem) -> Void
    let onRequestAccessibility: () -> Void
    let onSizeChange: (CGSize) -> Void

    private let cellWidth: CGFloat = 40

    var body: some View {
        content
            .padding(6)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
    }

    @ViewBuilder
    private var content: some View {
        if !model.isAccessibilityTrusted {
            VStack(alignment: .leading, spacing: 8) {
                Text("Whisky 需要「輔助使用」權限")
                    .font(.headline)
                Text("有了它才讀得到被瀏海擋住的圖示和它們的選單。授權後不用重開 Whisky。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("打開系統設定…", action: onRequestAccessibility)
            }
            .frame(width: 300, alignment: .leading)
            .padding(6)
        } else if model.items.isEmpty {
            Text(model.hasScanned ? "所有圖示都看得到" : "正在讀取選單列…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if !model.query.isEmpty {
                    searchLine
                }
                if model.filteredItems.isEmpty {
                    Text("找不到「\(model.query)」")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                } else {
                    rows
                }
            }
        }
    }

    private var searchLine: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
            Text(model.query)
            Spacer(minLength: 12)
            Text("\(model.filteredItems.count) 個 · Enter 打開 · Esc 清除")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 6)
    }

    /// Two rows: items behind the notch (menu bar order), then items that aren't in the menu bar at all.
    private var rows: some View {
        let hidden = model.filteredItems.filter { !$0.isOff }
        let off = model.filteredItems.filter(\.isOff)
        return VStack(alignment: .trailing, spacing: 4) {
            if !hidden.isEmpty { row(hidden) }
            if !hidden.isEmpty, !off.isEmpty { Divider() }
            if !off.isEmpty { row(off) }
        }
    }

    @ViewBuilder
    private func row(_ items: [BarItem]) -> some View {
        let cells = HStack(spacing: 2) { ForEach(items) { cell($0) } }
        if CGFloat(items.count) * cellWidth > maxWidth {
            ScrollView(.horizontal, showsIndicators: false) { cells }
                .frame(width: maxWidth)
        } else {
            cells
        }
    }

    private func cell(_ item: BarItem) -> some View {
        BarCell(
            item: item,
            isSelected: model.isUsingKeyboard && model.selectedItem?.id == item.id,
            open: { onOpen(item) },
            press: { onPress(item) },
            activateApp: { onActivateApp(item) },
            pin: item.scanned.placement == .hidden && item.scanned.windowID != nil ? { onPin(item) } : nil
        )
    }
}

private struct BarCell: View {
    let item: BarItem
    let isSelected: Bool
    let open: () -> Void
    let press: () -> Void
    let activateApp: () -> Void
    /// nil when the item can't be moved (it isn't in the menu bar at all).
    let pin: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            image
                .frame(minWidth: 26, minHeight: 26)
                .padding(.horizontal, 5)
                .background(chip, in: .rect(cornerRadius: 7))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(item.tooltip)
        .accessibilityLabel(item.tooltip)
        .contextMenu {
            if let pin {
                Button("放到選單列上", action: pin)
                Divider()
            }
            Button("直接點按", action: press)
            Button("切換到「\(item.scanned.appName)」", action: activateApp)
            if pin == nil, item.isOff {
                Divider()
                Text("這個圖示不在選單列上，要先到「系統設定 › 選單列」打開它")
            }
        }
    }

    @ViewBuilder
    private var image: some View {
        if let glyph = item.glyph {
            Image(nsImage: glyph.image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: min(18, glyph.image.size.height))
        } else if let icon = item.appIcon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.dashed")
                .frame(width: 20, height: 20)
        }
    }

    /// Captured glyphs keep the menu bar's colours, so give light glyphs a dark chip and dark ones a
    /// light chip; app icons carry their own colours and only need a hover highlight.
    private var chip: Color {
        guard let glyph = item.glyph else { return .primary.opacity(isHovered ? 0.14 : 0) }
        return glyph.isLight ? .black.opacity(isHovered ? 0.65 : 0.45) : .white.opacity(isHovered ? 0.9 : 0.7)
    }
}
