import AppKit
@preconcurrency import ScreenCaptureKit
import WhiskyCore

struct Glyph {
    let image: NSImage
    /// Drawn for a dark menu bar (light) or a light one (dark).
    let isLight: Bool
    /// For mask-like glyphs (grey ink on transparency), the glyph redrawn in white and in black, so it can follow the
    /// panel's colours the way the menu bar draws template images. nil for coloured glyphs, which keep their colours.
    let white: NSImage?
    let black: NSImage?
    /// A small grey thumbnail, for noticing when the item's look changes (`ChangeTracker`).
    let fingerprint: [UInt8]

    var isMonochrome: Bool { white != nil }
}

/// Captures status item images with ScreenCaptureKit. An item macOS didn't draw because of the notch
/// still has a live backing store, so its window can be captured even though it is off screen.
/// Items pushed entirely off the display can't be captured (SCK returns -3811).
@MainActor
enum GlyphCapture {
    private static var loggedFailures: Set<UInt32> = []
    static func capture(_ requests: [(id: String, windowID: UInt32)]) async -> [String: Glyph] {
        guard Permissions.hasScreenRecording, !requests.isEmpty else { return [:] }
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            Log.write("glyph capture: shareable content failed: \(error.localizedDescription)")
            return [:]
        }
        var windows: [CGWindowID: SCWindow] = [:]
        for window in content.windows { windows[window.windowID] = window }
        let scale = NSScreen.main?.backingScaleFactor ?? 2

        var glyphs: [String: Glyph] = [:]
        for request in requests {
            guard let window = windows[request.windowID] else { continue }
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(window.frame.width * scale))
            configuration.height = max(1, Int(window.frame.height * scale))
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            configuration.captureResolution = .best
            do {
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: SCContentFilter(desktopIndependentWindow: window),
                    configuration: configuration
                )
                if let glyph = makeGlyph(image, scale: scale) { glyphs[request.id] = glyph }
            } catch {
                // Once per window: the change watcher asks again every half minute.
                if loggedFailures.insert(request.windowID).inserted {
                    Log.write("glyph capture: window \(request.windowID) failed: \(error.localizedDescription)")
                }
            }
        }
        return glyphs
    }

    private static func makeGlyph(_ image: CGImage, scale: CGFloat) -> Glyph? {
        guard let bounds = GlyphAnalysis.opaqueBounds(of: image) else { return nil }
        let padded = bounds.insetBy(dx: -scale, dy: -scale).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let cropped = image.cropping(to: padded) else { return nil }
        let size = NSSize(width: CGFloat(cropped.width) / scale, height: CGFloat(cropped.height) / scale)
        let luminance = GlyphAnalysis.meanLuminance(of: cropped) ?? 0
        let image = NSImage(cgImage: cropped, size: size)
        // Tinted copies rather than a template image: inside Liquid Glass, template images are drawn with a vibrancy
        // blend, which this keeps out of the way.
        let monochrome = GlyphAnalysis.isMonochrome(cropped)
        return Glyph(image: image, isLight: luminance > 0.6,
                     white: monochrome ? tinted(image, .white) : nil, black: monochrome ? tinted(image, .black) : nil,
                     fingerprint: GlyphAnalysis.fingerprint(of: cropped))
    }

    private static func tinted(_ image: NSImage, _ colour: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            colour.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
