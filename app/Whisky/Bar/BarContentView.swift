import SwiftUI

/// Colours for the two places Whisky Bar appears: poured out of the notch (white on the notch's black), or in a
/// glass panel under Whisky's icon on a screen without a notch (follows the system appearance).
enum BarStyle {
    case notch
    case glass

    var primary: Color { self == .notch ? .white : .primary }
    var secondary: Color { self == .notch ? .white.opacity(0.62) : .secondary }
    var tertiary: Color { self == .notch ? .white.opacity(0.4) : Color(nsColor: .tertiaryLabelColor) }
    var highlight: Color { self == .notch ? .white.opacity(0.16) : .primary.opacity(0.09) }
    var rule: Color { self == .notch ? .white.opacity(0.12) : .primary.opacity(0.1) }
}

/// What the panel's items and buttons do; the controller fills it in.
struct BarActions {
    var open: (BarItem) -> Void = { _ in }
    var press: (BarItem) -> Void = { _ in }
    var activateApp: (BarItem) -> Void = { _ in }
    var pin: (BarItem) -> Void = { _ in }
    var requestAccessibility: () -> Void = {}
    var restoreLayout: () -> Void = {}
    var keepLayout: () -> Void = {}
    var assignShortcut: (BarItem) -> Void = { _ in }
}

/// Whisky Bar's content: a search line, the hidden items and the ones not in the menu bar (drawn the way the menu bar
/// draws them, wrapped to the panel's width), and a footer naming the item under the pointer.
struct BarContentView: View {
    static let width: CGFloat = 372

    let model: BarModel
    let style: BarStyle
    let actions: BarActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isAccessibilityTrusted {
                searchLine
                rule
                sections
                    .padding(.vertical, 4)
                if let drift = model.layoutDrift {
                    rule
                    driftLine(drift)
                }
                rule
                footer
            } else {
                permissionPrompt
            }
        }
        .frame(width: Self.width, alignment: .leading)
        .foregroundStyle(style.primary)
    }

    private var rule: some View {
        Rectangle().fill(style.rule).frame(height: 0.5)
    }

    // MARK: - Search

    private var searchLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(model.query.isEmpty ? style.tertiary : style.secondary)
            if model.query.isEmpty {
                Text("輸入名稱搜尋")
                    .foregroundStyle(style.tertiary)
            } else {
                Text(model.query)
                Text("\(model.filteredItems.count) 個")
                    .foregroundStyle(style.tertiary)
            }
            Spacer(minLength: 8)
            if let shortcut = model.shortcutDisplay {
                Text(shortcut)
                    .foregroundStyle(style.tertiary)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    // MARK: - Items

    @ViewBuilder
    private var sections: some View {
        let sections = model.sections
        if !model.hasScanned {
            message("正在讀取選單列…")
        } else if model.items.isEmpty {
            message("所有圖示都看得到")
        } else if sections.all.isEmpty {
            message("找不到「\(model.query)」")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                if !sections.frequent.isEmpty { section("常用", sections.frequent) }
                if !sections.hidden.isEmpty { section(style == .notch ? "瀏海後面" : "藏起來的", sections.hidden) }
                if !sections.off.isEmpty { section("不在選單列上", sections.off) }
            }
        }
    }

    /// Poured out of the notch, items flow in one after another (top row first), unless searching or with Reduce
    /// Motion on.
    private func cascadeIndex(of item: BarItem) -> Int? {
        guard style == .notch, model.query.isEmpty, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return nil }
        return model.sections.all.firstIndex { $0.id == item.id }
    }

    private func section(_ title: String, _ items: [BarItem]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title) · \(items.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(style.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 4)
            FlowLayout(spacing: 1, lineSpacing: 1) {
                ForEach(items) { item in
                    BarCell(
                        item: item,
                        style: style,
                        cascadeIndex: cascadeIndex(of: item),
                        isSelected: model.isUsingKeyboard && model.selectedItem?.id == item.id,
                        actions: actions,
                        onHover: { hovering in
                            if hovering { model.hoveredID = item.id } else if model.hoveredID == item.id { model.hoveredID = nil }
                        }
                    )
                }
            }
            .padding(.horizontal, 5)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(style.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
    }

    // MARK: - Footer and notices

    private var footer: some View {
        HStack(spacing: 8) {
            if let item = model.focusedItem {
                Text(item.displayName)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(item.isOff ? "不在選單列上 · 點一下打開" : "點一下打開 · 右鍵更多")
                    .foregroundStyle(style.tertiary)
            } else {
                Text(summary)
                    .foregroundStyle(style.secondary)
                Spacer(minLength: 8)
                Text("←→ 選擇 · Enter 打開")
                    .foregroundStyle(style.tertiary)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var summary: String {
        let hidden = model.items.filter { !$0.isOff }.count
        return hidden > 0 ? "\(hidden) 個圖示被藏起來" : "Whisky"
    }

    private func driftLine(_ drift: LayoutDriftNotice) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.orange)
            Text(drift.summary)
                .lineLimit(1)
                .help(drift.names.joined(separator: "、"))
            Spacer(minLength: 6)
            Button("保留現在的", action: actions.keepLayout)
                .buttonStyle(.plain)
                .foregroundStyle(style.secondary)
            Button("排回來", action: actions.restoreLayout)
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Whisky 需要「輔助使用」權限")
                .font(.system(size: 13, weight: .semibold))
            Text("有了它才讀得到被瀏海擋住的圖示和它們的選單。授權後不用重開 Whisky。")
                .font(.system(size: 12))
                .foregroundStyle(style.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("打開系統設定…", action: actions.requestAccessibility)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(12)
    }
}

/// One item, drawn the way the menu bar draws it: no tile, a rounded highlight under the pointer.
private struct BarCell: View {
    let item: BarItem
    let style: BarStyle
    let isSelected: Bool
    let actions: BarActions
    let onHover: (Bool) -> Void
    /// Its turn in the pour (nil: shown at once).
    let cascadeIndex: Int?

    @State private var isHovered = false
    @State private var hasAppeared: Bool

    init(item: BarItem, style: BarStyle, cascadeIndex: Int?, isSelected: Bool, actions: BarActions, onHover: @escaping (Bool) -> Void) {
        self.item = item
        self.style = style
        self.cascadeIndex = cascadeIndex
        self.isSelected = isSelected
        self.actions = actions
        self.onHover = onHover
        _hasAppeared = State(initialValue: cascadeIndex == nil)
    }

    var body: some View {
        Button { actions.open(item) } label: {
            image
                .frame(minWidth: 22, minHeight: 24)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(isHovered || isSelected ? style.highlight : .clear))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -5)
        .onAppear {
            guard !hasAppeared, let cascadeIndex else { return }
            withAnimation(.easeOut(duration: 0.22).delay(0.08 + Double(min(cascadeIndex, 40)) * 0.012)) { hasAppeared = true }
        }
        .onHover { hovering in
            isHovered = hovering
            onHover(hovering)
        }
        .help(item.tooltip)
        .accessibilityLabel(item.tooltip)
        .contextMenu {
            if item.scanned.placement == .hidden, item.scanned.windowID != nil, PlatformSupport.movesItems {
                Button("放到選單列上") { actions.pin(item) }
                Divider()
            }
            Button("直接點按") { actions.press(item) }
            Button("切換到「\(item.scanned.appName)」") { actions.activateApp(item) }
            Divider()
            Button("指定快捷鍵…") { actions.assignShortcut(item) }
            if item.isOff {
                Divider()
                Button("在「系統設定 › 選單列」打開它…") { Permissions.openMenuBarSettings() }
            }
        }
    }

    private var image: some View {
        ItemImage(glyph: item.glyph, symbol: item.symbol, appIcon: item.appIcon, onDark: style == .notch)
    }
}
