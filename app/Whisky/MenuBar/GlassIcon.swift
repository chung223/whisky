import AppKit

/// Whisky's menu bar icon: a rocks glass that fills when Whisky Bar opens and empties when it closes.
/// Drawn as a template image, so it follows the menu bar's colour like any system icon.
enum GlassIcon {
    static let size = NSSize(width: 18, height: 18)

    /// One frame of the icon.
    /// - Parameters:
    ///   - fill: liquid level, 0 (empty) to 1 (full).
    ///   - pour: 0 no bottle; 0…1 the bottle tips in and the stream runs; it is drawn while `pour > 0`.
    ///   - wave: phase of the ripple on the surface (radians); `waveAmount` scales it (0 = flat).
    static func image(fill: CGFloat, pour: CGFloat = 0, wave: CGFloat = 0, waveAmount: CGFloat = 0) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            draw(fill: min(max(fill, 0), 1), pour: min(max(pour, 0), 1), wave: wave, waveAmount: min(max(waveAmount, 0), 1))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Whisky"
        return image
    }

    // Glass outline: a tumbler a little narrower at the base, with a thick bottom.
    private static let topY: CGFloat = 13.6
    private static let bottomY: CGFloat = 2.6
    private static let topLeft: CGFloat = 3.2, topRight: CGFloat = 14.8
    private static let bottomLeft: CGFloat = 4.4, bottomRight: CGFloat = 13.6
    private static let innerBottom: CGFloat = 4.4
    private static let fullLevel: CGFloat = 11.2

    private static func wallX(at y: CGFloat, left: Bool) -> CGFloat {
        let t = (y - bottomY) / (topY - bottomY)
        return left ? bottomLeft + (topLeft - bottomLeft) * t : bottomRight + (topRight - bottomRight) * t
    }

    private static func draw(fill: CGFloat, pour: CGFloat, wave: CGFloat, waveAmount: CGFloat) {
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let level = innerBottom + (fullLevel - innerBottom) * fill

        // Liquid, clipped to the inside of the glass, with a rippling surface while it is poured.
        if fill > 0.01 {
            let inset: CGFloat = 0.9
            let liquid = NSBezierPath()
            liquid.move(to: NSPoint(x: wallX(at: innerBottom, left: true) + inset, y: innerBottom))
            liquid.line(to: NSPoint(x: wallX(at: innerBottom, left: false) - inset, y: innerBottom))
            let right = wallX(at: level, left: false) - inset
            let left = wallX(at: level, left: true) + inset
            liquid.line(to: NSPoint(x: right, y: level))
            let steps = 12
            for step in stride(from: steps, through: 0, by: -1) {
                let x = left + (right - left) * CGFloat(step) / CGFloat(steps)
                let ripple = sin(x * 0.9 + wave) * 0.55 * waveAmount
                liquid.line(to: NSPoint(x: x, y: level + ripple))
            }
            liquid.close()
            liquid.fill()

            // An ice cube floating at the surface once the glass is mostly full: cut out of the liquid.
            if fill > 0.55 {
                let appear = min(1, (fill - 0.55) / 0.3)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.compositingOperation = .clear
                let cube = NSBezierPath(roundedRect: NSRect(x: -1.6, y: -1.6, width: 3.2, height: 3.2), xRadius: 0.7, yRadius: 0.7)
                var transform = AffineTransform(translationByX: 10.6, byY: level - 1.5)
                transform.rotate(byDegrees: 14)
                transform.scale(appear)
                cube.transform(using: transform)
                cube.fill()
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // The glass itself.
        let glass = NSBezierPath()
        glass.move(to: NSPoint(x: topLeft, y: topY))
        glass.line(to: NSPoint(x: bottomLeft, y: bottomY))
        glass.line(to: NSPoint(x: bottomRight, y: bottomY))
        glass.line(to: NSPoint(x: topRight, y: topY))
        glass.lineWidth = 1.3
        glass.lineJoinStyle = .round
        glass.lineCapStyle = .round
        glass.stroke()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: wallX(at: innerBottom, left: true) + 0.3, y: innerBottom - 0.6))
        base.line(to: NSPoint(x: wallX(at: innerBottom, left: false) - 0.3, y: innerBottom - 0.6))
        base.lineWidth = 1.0
        base.lineCapStyle = .round
        base.stroke()

        // A bottle tipping in at the top right (mostly outside the icon), and the stream running from its mouth.
        if pour > 0 {
            let tip = min(1, pour / 0.25)          // the bottle slides in during the first quarter
            let mouth = NSPoint(x: 11.9 + (1 - tip) * 6, y: 14.3 + (1 - tip) * 5)
            let bottle = NSBezierPath()
            // Pointing down from the mouth: neck, shoulder, body.
            bottle.move(to: NSPoint(x: -0.85, y: 0))
            bottle.line(to: NSPoint(x: 0.85, y: 0))
            bottle.line(to: NSPoint(x: 0.85, y: 2.6))
            bottle.curve(to: NSPoint(x: 2.5, y: 4.6), controlPoint1: NSPoint(x: 0.85, y: 3.4), controlPoint2: NSPoint(x: 2.5, y: 3.6))
            bottle.line(to: NSPoint(x: 2.5, y: 12))
            bottle.line(to: NSPoint(x: -2.5, y: 12))
            bottle.line(to: NSPoint(x: -2.5, y: 4.6))
            bottle.curve(to: NSPoint(x: -0.85, y: 2.6), controlPoint1: NSPoint(x: -2.5, y: 3.6), controlPoint2: NSPoint(x: -0.85, y: 3.4))
            bottle.close()
            var transform = AffineTransform(translationByX: mouth.x, byY: mouth.y)
            transform.rotate(byDegrees: -62)
            bottle.transform(using: transform)
            bottle.fill()

            // The stream: full while pouring, thinning out at the end.
            let flow = pour < 0.85 ? min(1, max(0, (pour - 0.1) / 0.15)) : max(0, (1 - pour) / 0.15)
            if flow > 0 {
                let streamEnd = max(level, innerBottom) // lands on the surface
                let stream = NSBezierPath()
                let endX: CGFloat = 11.0
                stream.move(to: NSPoint(x: mouth.x - 0.3, y: mouth.y - 0.4))
                stream.curve(to: NSPoint(x: endX, y: streamEnd + 0.3),
                             controlPoint1: NSPoint(x: mouth.x - 1.2, y: mouth.y - 1.0),
                             controlPoint2: NSPoint(x: endX, y: (mouth.y + streamEnd) / 2))
                stream.lineWidth = 0.6 + 0.8 * flow
                stream.lineCapStyle = .round
                stream.stroke()
            }
        }
    }
}

/// Plays the fill and empty animations on a status bar button.
@MainActor
final class GlassAnimator {
    private weak var button: NSStatusBarButton?
    private var timer: Timer?
    private(set) var isFull = false

    init(button: NSStatusBarButton?) {
        self.button = button
        button?.image = GlassIcon.image(fill: 0)
    }

    /// Pours (Whisky Bar opens) or empties (it closes) the glass.
    func setFull(_ full: Bool) {
        guard full != isFull else { return }
        isFull = full
        timer?.invalidate()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            button?.image = GlassIcon.image(fill: full ? 1 : 0)
            return
        }
        let duration: Double = full ? 0.65 : 0.35
        let start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step(full: full, start: start, duration: duration) }
        }
    }

    private func step(full: Bool, start: Date, duration: Double) {
        let t = min(1, Date().timeIntervalSince(start) / duration)
        button?.image = full ? Self.pourFrame(CGFloat(t)) : Self.emptyFrame(CGFloat(t))
        if t >= 1 {
            timer?.invalidate()
            timer = nil
            button?.image = GlassIcon.image(fill: full ? 1 : 0)
        }
    }

    /// Bottle tips in, the stream runs, the level rises with a ripple, the bottle leaves.
    static func pourFrame(_ t: CGFloat) -> NSImage {
        let rise = easeOut(min(1, max(0, (t - 0.15) / 0.7)))
        let ripple = t < 0.9 ? 1 - t * 0.6 : (1 - t) * 4
        return GlassIcon.image(fill: rise, pour: t < 0.97 ? t : 0, wave: t * 18, waveAmount: ripple)
    }

    /// The level drops, a little faster at the end.
    static func emptyFrame(_ t: CGFloat) -> NSImage {
        GlassIcon.image(fill: 1 - t * t, wave: t * 10, waveAmount: 0.4 * (1 - t))
    }

    private static func easeOut(_ t: CGFloat) -> CGFloat { 1 - (1 - t) * (1 - t) }
}
