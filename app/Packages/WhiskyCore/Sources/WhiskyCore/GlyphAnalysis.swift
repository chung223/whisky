import CoreGraphics

/// Helpers for status item glyphs captured with ScreenCaptureKit.
public enum GlyphAnalysis {
    /// Bounds of pixels whose alpha exceeds `alphaThreshold`, in image pixel coordinates with a
    /// top-left origin (the space `CGImage.cropping(to:)` uses). nil when the image is fully transparent.
    public static func opaqueBounds(of image: CGImage, alphaThreshold: UInt8 = 8) -> CGRect? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var bounds: CGRect?
        withRGBA(image, width: width, height: height) { pixels in
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where pixels[(y * width + x) * 4 + 3] > alphaThreshold {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            if maxX >= 0 {
                bounds = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            }
        }
        return bounds
    }

    /// Alpha-weighted mean luminance (0...1) of the visible pixels, sampled at 32×32.
    /// nil when nothing is visible.
    public static func meanLuminance(of image: CGImage) -> Double? {
        let size = 32
        var result: Double?
        withRGBA(image, width: size, height: size) { pixels in
            var sum = 0.0, weight = 0.0
            for i in stride(from: 0, to: size * size * 4, by: 4) {
                let alpha = Double(pixels[i + 3]) / 255
                guard alpha > 0.3 else { continue }
                // Premultiplied: divide alpha back out to get the colour.
                let r = Double(pixels[i]) / 255 / alpha
                let g = Double(pixels[i + 1]) / 255 / alpha
                let b = Double(pixels[i + 2]) / 255 / alpha
                sum += (0.2126 * r + 0.7152 * g + 0.0722 * b) * alpha
                weight += alpha
            }
            if weight > 0 { result = min(1, sum / weight) }
        }
        return result
    }

    /// True when the glyph works as a mask: its visible pixels are grey and all about as light as each other (white
    /// or black ink on transparency), so it can be redrawn in any colour the way the menu bar draws template images.
    /// Coloured glyphs, and logos with dark detail on a light badge (which a mask would flatten into a blob), keep
    /// their own colours.
    public static func isMonochrome(_ image: CGImage, saturationThreshold: Double = 0.25, outlierShare: Double = 0.06) -> Bool {
        let size = 32
        var monochrome = true
        withRGBA(image, width: size, height: size) { pixels in
            var samples: [(luminance: Double, alpha: Double)] = []
            var visible = 0.0, coloured = 0.0, luminanceSum = 0.0
            for i in stride(from: 0, to: size * size * 4, by: 4) {
                let alpha = Double(pixels[i + 3]) / 255
                guard alpha > 0.3 else { continue }
                let r = Double(pixels[i]) / 255 / alpha
                let g = Double(pixels[i + 1]) / 255 / alpha
                let b = Double(pixels[i + 2]) / 255 / alpha
                let high = max(r, g, b), low = min(r, g, b)
                let saturation = high > 0 ? (high - low) / high : 0
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                visible += alpha
                luminanceSum += luminance * alpha
                samples.append((luminance, alpha))
                if saturation > saturationThreshold, high > 0.15 { coloured += alpha }
            }
            guard visible > 0 else { return }
            let mean = luminanceSum / visible
            let offTone = samples.filter { abs($0.luminance - mean) > 0.2 }.reduce(0) { $0 + $1.alpha }
            monochrome = coloured / visible < outlierShare && offTone / visible < outlierShare
        }
        return monochrome
    }

    /// A 16 × 16 grey thumbnail (alpha-weighted luminance), for telling whether an item's look changed.
    public static func fingerprint(of image: CGImage) -> [UInt8] {
        let size = 16
        var result = [UInt8](repeating: 0, count: size * size)
        withRGBA(image, width: size, height: size) { pixels in
            for index in 0..<(size * size) {
                let i = index * 4
                // Premultiplied, so this already weighs colour by coverage.
                let luminance = 0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])
                result[index] = UInt8(min(255, (luminance + Double(pixels[i + 3])) / 2))
            }
        }
        return result
    }

    /// How different two fingerprints are, 0 (same) to 1.
    public static func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1 }
        let total = zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(total) / Double(a.count * 255)
    }

    /// Draws `image` into an RGBA buffer of the given size; row 0 of the buffer is the image's top row.
    private static func withRGBA(_ image: CGImage, width: Int, height: Int, _ body: (UnsafeBufferPointer<UInt8>) -> Void) {
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        buffer.withUnsafeBufferPointer(body)
    }
}
