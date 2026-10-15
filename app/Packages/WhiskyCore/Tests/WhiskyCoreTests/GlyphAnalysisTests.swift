import CoreGraphics
import Testing
@testable import WhiskyCore

/// A transparent image with one opaque square, drawn with a top-left origin.
private func image(width: Int, height: Int, square: CGRect, gray: CGFloat) throws -> CGImage {
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1))
    // Flip so `square` is in top-left coordinates.
    context.fill(CGRect(x: square.minX, y: CGFloat(height) - square.maxY, width: square.width, height: square.height))
    return try #require(context.makeImage())
}

@Suite("Glyph analysis")
struct GlyphAnalysisTests {
    @Test("Opaque bounds use a top-left origin")
    func bounds() throws {
        let glyph = try image(width: 40, height: 20, square: CGRect(x: 8, y: 3, width: 4, height: 5), gray: 1)
        #expect(GlyphAnalysis.opaqueBounds(of: glyph) == CGRect(x: 8, y: 3, width: 4, height: 5))
    }

    @Test("A fully transparent image has no bounds or luminance")
    func transparent() throws {
        let empty = try image(width: 10, height: 10, square: .zero, gray: 1)
        #expect(GlyphAnalysis.opaqueBounds(of: empty) == nil)
        #expect(GlyphAnalysis.meanLuminance(of: empty) == nil)
    }

    @Test("White and black glyphs are told apart")
    func luminance() throws {
        let white = try image(width: 32, height: 32, square: CGRect(x: 4, y: 4, width: 24, height: 24), gray: 1)
        let black = try image(width: 32, height: 32, square: CGRect(x: 4, y: 4, width: 24, height: 24), gray: 0)
        #expect(try #require(GlyphAnalysis.meanLuminance(of: white)) > 0.9)
        #expect(try #require(GlyphAnalysis.meanLuminance(of: black)) < 0.1)
    }
}
