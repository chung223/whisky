import AppKit
import Observation
import SwiftUI

/// The notch of a built-in display, in screen coordinates (bottom-left origin). Read from public `NSScreen` API: the
/// unobscured areas left and right of it, and the top safe-area inset (the menu bar is as tall as the notch).
struct NotchGeometry: Equatable {
    let screenFrame: NSRect
    let rect: NSRect

    static func current() -> NotchGeometry? {
        for screen in NSScreen.screens where screen.safeAreaInsets.top > 0 {
            guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { continue }
            let minX = screen.frame.minX + left.width
            let maxX = screen.frame.maxX - right.width
            let height = screen.safeAreaInsets.top
            guard maxX - minX > 40 else { continue }
            return NotchGeometry(screenFrame: screen.frame, rect: NSRect(x: minX, y: screen.frame.maxY - height, width: maxX - minX, height: height))
        }
        return nil
    }
}

/// Whisky Bar poured out of the notch. Closed, a black shape sits inside the notch (where the display has no pixels,
/// so it can't be seen) and watches the pointer. Hovering grows it a little below the notch with the number of hidden
/// items; a click pours the whole panel out. Black like the notch, so the panel reads as part of it, and the menu
/// bar's white template glyphs look as they do in a dark menu bar whatever the wallpaper.
@MainActor
final class NotchPresenter: BarPresenter {
    private let model: BarModel
    private let actions: BarActions
    private let onOpenRequest: () -> Void
    /// While Whisky is moving items (the pointer sweeps across the notch), hovering does nothing.
    private let isHoverSuppressed: () -> Bool
    private let state = NotchState()
    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private var hoverTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?
    /// Right click (or ⌃-click) on the notch: Whisky's menu, which the glass used to carry.
    var onMenuRequest: (() -> Void)?
    var onScreensChange: (() -> Void)?

    init(model: BarModel, actions: BarActions, isHoverSuppressed: @escaping () -> Bool, onOpenRequest: @escaping () -> Void) {
        self.model = model
        self.actions = actions
        self.isHoverSuppressed = isHoverSuppressed
        self.onOpenRequest = onOpenRequest
    }

    static var isAvailable: Bool { NotchGeometry.current() != nil }

    var isOpen: Bool { state.phase == .open }
    var window: NSWindow? { panel }

    // MARK: - Installing

    /// Puts the closed shape in the notch and follows display changes (lid closed, external display arranged).
    func install() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateGeometry()
                self?.onScreensChange?()
            }
        }
        updateGeometry()
    }

    func uninstall() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        hoverTask?.cancel()
        settleTask?.cancel()
        state.phase = .closed
        panel?.orderOut(nil)
    }

    private func updateGeometry() {
        geometry = NotchGeometry.current()
        guard let geometry else {
            panel?.orderOut(nil)
            return
        }
        state.notchSize = geometry.rect.size
        Log.write("notch: \(Int(geometry.rect.minX))–\(Int(geometry.rect.maxX)) × \(Int(geometry.rect.height)) pt")
        let panel = panel ?? makePanel()
        self.panel = panel
        setWindowSize(state.shapeSize(for: state.phase))
        panel.orderFrontRegardless()
    }

    // MARK: - Opening and closing

    func present() {
        guard let panel, geometry != nil else { return }
        hoverTask?.cancel()
        panel.allowsKey = true
        setPhase(.open)
        panel.makeKey()
    }

    func dismiss() {
        guard state.phase != .closed else { return }
        panel?.allowsKey = false
        setPhase(.closed)
    }

    /// Testing: shows the hover state without moving the pointer (`whisky://notch?phase=peek`).
    func showPeekForTesting() {
        state.hiddenCount = model.items.filter { !$0.isOff }.count
        setPhase(.peek)
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            await self?.collapseWhenPointerLeaves()
        }
    }

    // MARK: - Pointer

    private func pointerEntered() {
        guard state.phase == .closed, !isHoverSuppressed() else { return }
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            // A pointer passing by on its way to a menu shouldn't set it off.
            try? await Task.sleep(for: .milliseconds(120))
            guard let self, !Task.isCancelled, self.state.phase == .closed, self.isPointerInside else { return }
            self.state.hiddenCount = self.model.items.filter { !$0.isOff }.count
            self.setPhase(.peek)
            Task {
                // Capture the real images now, so they are ready if the click comes.
                await self.model.refresh(captureGlyphs: true)
                self.state.hiddenCount = self.model.items.filter { !$0.isOff }.count
            }
            await self.collapseWhenPointerLeaves()
        }
    }

    private func pointerExited() {
        // Handled by `collapseWhenPointerLeaves`, which doesn't depend on exit events (they can go missing while the
        // window is resized under the pointer).
    }

    /// While peeking, checks the pointer four times a second and closes once it has been outside twice in a row.
    private func collapseWhenPointerLeaves() async {
        var outside = 0
        while state.phase == .peek, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
            outside = isPointerInside ? 0 : outside + 1
            if outside >= 2, state.phase == .peek {
                setPhase(.closed)
                return
            }
        }
    }

    private func clicked() {
        guard state.phase != .open else { return }
        onOpenRequest()
    }

    private var isPointerInside: Bool {
        panel?.frame.insetBy(dx: -1, dy: -1).contains(NSEvent.mouseLocation) == true
    }

    // MARK: - Shape and window

    /// Grows the window at once (the shape animates inside it) and shrinks it once the shape has finished shrinking.
    private func setPhase(_ phase: NotchState.Phase) {
        if phase == .peek, state.phase != .peek { state.pourStart = Date() }
        let old = state.shapeSize(for: state.phase)
        state.phase = phase
        panel?.hasShadow = phase == .open
        resize(from: old)
    }

    private func resize(from old: CGSize) {
        let new = state.shapeSize(for: state.phase)
        setWindowSize(CGSize(width: max(old.width, new.width), height: max(old.height, new.height)))
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(420))
            guard let self, !Task.isCancelled else { return }
            self.setWindowSize(self.state.shapeSize(for: self.state.phase))
            if self.state.phase == .closed, let panel = self.panel, panel.isKeyWindow {
                // Hand the keyboard back to the app the user was in.
                panel.orderOut(nil)
                panel.orderFrontRegardless()
            }
        }
    }

    private func setWindowSize(_ size: CGSize) {
        guard let panel, let geometry else { return }
        let frame = NSRect(x: (geometry.rect.midX - size.width / 2).rounded(), y: geometry.screenFrame.maxY - size.height,
                           width: size.width.rounded(.up), height: size.height.rounded(.up))
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 30), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Whisky Notch"
        // Above the menu bar and its items, below menus (a mirrored menu opens over it).
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.animationBehavior = .none

        let container = NotchContainerView()
        container.passesClicksToContent = { [weak self] in self?.state.phase == .open }
        container.onEnter = { [weak self] in self?.pointerEntered() }
        container.onExit = { [weak self] in self?.pointerExited() }
        container.onClick = { [weak self] in self?.clicked() }
        container.onRightClick = { [weak self] in
            guard let self, self.state.phase != .open else { return }
            self.onMenuRequest?()
        }
        let hosting = NSHostingView(rootView: NotchRootView(state: state, model: model, actions: actions) { [weak self] size in
            guard let self, self.state.contentSize != size else { return }
            let old = self.state.shapeSize(for: self.state.phase)
            self.state.contentSize = size
            if self.state.phase == .open { self.resize(from: old) }
        })
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        panel.contentView = container
        hosting.frame = container.bounds
        return panel
    }
}

// MARK: - State and views

@MainActor
@Observable
final class NotchState {
    enum Phase { case closed, peek, open }

    var phase: Phase = .closed
    var notchSize = CGSize(width: 185, height: 32)
    /// Whisky Bar's content, measured while open.
    var contentSize = CGSize(width: BarContentView.width, height: 160)
    var hiddenCount = 0
    /// When the hover state began: the glass in it pours from then.
    var pourStart = Date.distantPast

    var bottomRadius: CGFloat {
        switch phase {
        case .closed: 10
        case .peek: 12
        case .open: 22
        }
    }

    /// The black shape's size in each phase; the window is sized to it.
    func shapeSize(for phase: Phase) -> CGSize {
        switch phase {
        case .closed:
            // A little inside the notch, so none of it is drawn on real pixels around the notch's rounded corners.
            CGSize(width: max(20, notchSize.width - 8), height: max(10, notchSize.height - 3))
        case .peek:
            // The notch, a little taller.
            CGSize(width: notchSize.width, height: notchSize.height + 22)
        case .open:
            CGSize(width: max(contentSize.width + 16, notchSize.width + 40),
                   height: notchSize.height + contentSize.height + 8)
        }
    }
}

struct NotchRootView: View {
    let state: NotchState
    let model: BarModel
    let actions: BarActions
    let onContentSize: (CGSize) -> Void

    private let spring = Animation.spring(response: 0.34, dampingFraction: 0.84)

    var body: some View {
        let size = state.shapeSize(for: state.phase)
        ZStack(alignment: .top) {
            NotchShape(neckWidth: state.notchSize.width, neckHeight: state.notchSize.height, bottomRadius: state.bottomRadius)
                .fill(.black)
                .frame(width: size.width, height: size.height)
            if state.phase == .peek {
                HStack(spacing: 4) {
                    PouringGlass(start: state.pourStart)
                        .frame(width: 15, height: 15)
                    Text("\(state.hiddenCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .frame(height: 20)
                .padding(.top, state.notchSize.height - 1)
                .transition(.opacity)
            }
            if state.phase == .open {
                BarContentView(model: model, style: .notch, actions: actions)
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { onContentSize($0) }
                    .padding(.top, state.notchSize.height)
                    .transition(.opacity.combined(with: .offset(y: -12)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: state.phase)
        .animation(spring, value: state.contentSize)
    }
}

/// Whisky's glass being filled: the bottle tips in, the whisky rises with a ripple (the menu bar glass's animation).
struct PouringGlass: View {
    let start: Date
    private static let duration: TimeInterval = 0.65

    var body: some View {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            glass(GlassIcon.image(fill: 1))
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: Date().timeIntervalSince(start) > Self.duration + 0.1)) { context in
                let t = min(1, max(0, context.date.timeIntervalSince(start) / Self.duration))
                glass(t >= 1 ? GlassIcon.image(fill: 1) : GlassAnimator.pourFrame(CGFloat(t)))
            }
        }
    }

    private func glass(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(.white)
    }
}

/// The notch grown downward, like liquid poured from a bottle's neck: the neck is the notch itself (where the display
/// has no pixels), and only below the menu bar does the shape widen, so the menu bar on either side of the notch is
/// never covered. Narrower than the neck (closed), it is a plain shape with rounded bottom corners.
struct NotchShape: Shape {
    var neckWidth: CGFloat
    var neckHeight: CGFloat
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let neck = min(neckWidth, rect.width)
        let flare = (rect.width - neck) / 2
        let bottom = min(bottomRadius, rect.width / 2, rect.height / 2)
        var path = Path()
        guard flare >= 1, rect.height > neckHeight + 4 else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottom), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
        // Where the neck meets the body: a small concave curve; the body's own top corners are rounded.
        let fillet = min(8, flare / 2, neckHeight)
        let top = min(14, flare - fillet, (rect.height - neckHeight) / 2)
        let left = rect.midX - neck / 2, right = rect.midX + neck / 2
        let shoulder = rect.minY + neckHeight
        let body = min(bottom, (rect.height - neckHeight - top))
        path.move(to: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: right, y: rect.minY))
        path.addLine(to: CGPoint(x: right, y: shoulder - fillet))
        path.addQuadCurve(to: CGPoint(x: right + fillet, y: shoulder), control: CGPoint(x: right, y: shoulder))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: shoulder + top), control: CGPoint(x: rect.maxX, y: shoulder))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - body))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - body, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + body, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - body), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: shoulder + top))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: shoulder), control: CGPoint(x: rect.minX, y: shoulder))
        path.addLine(to: CGPoint(x: left - fillet, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: left, y: shoulder - fillet), control: CGPoint(x: left, y: shoulder))
        path.closeSubpath()
        return path
    }
}

// MARK: - Window

final class NotchPanel: NSPanel {
    /// Only while open (search takes typing); closed, the shape must never take the keyboard.
    var allowsKey = false
    override var canBecomeKey: Bool { allowsKey }
    // A window over the menu bar must not be pushed down below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Tracks the pointer even though Whisky is never the active app, and takes clicks itself until the panel is open.
final class NotchContainerView: NSView {
    var passesClicksToContent: () -> Bool = { false }
    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}
    var onClick: () -> Void = {}
    var onRightClick: () -> Void = {}
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if passesClicksToContent() { return super.hitTest(point) }
        return frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        event.modifierFlags.contains(.control) ? onRightClick() : onClick()
    }
    override func rightMouseDown(with event: NSEvent) { onRightClick() }
    override func mouseEntered(with event: NSEvent) { onEnter() }
    override func mouseExited(with event: NSEvent) { onExit() }
}
