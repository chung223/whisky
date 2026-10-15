import AppKit
@preconcurrency import ScreenCaptureKit
import WhiskyCore

struct Glyph {
    let image: NSImage
    /// Light glyphs (drawn for a dark menu bar) need a dark chip behind them, and vice versa.
    let isLight: Bool
}

/// Captures status item images with ScreenCaptureKit. An item macOS didn't draw because of the notch
/// still has a live backing store, so its window can be captured even though it is off screen.
/// Items pushed entirely off the display can't be captured (SCK returns -3811).
@MainActor
enum GlyphCapture {
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
                Log.write("glyph capture: window \(request.windowID) failed: \(error.localizedDescription)")
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
        return Glyph(image: NSImage(cgImage: cropped, size: size), isLight: luminance > 0.6)
    }
}
