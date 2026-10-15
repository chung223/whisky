// Renders Whisky's app icon into an asset catalog: the menu bar's whisky glass, full, in white on an amber squircle.
// Usage (swiftc only allows top-level code in a file named main.swift):
//   cp scripts/make-icon.swift /tmp/main.swift && swiftc -o /tmp/make-icon Whisky/MenuBar/GlassIcon.swift /tmp/main.swift
//   /tmp/make-icon Whisky/Assets.xcassets/AppIcon.appiconset
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Whisky/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let side = CGFloat(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: the shape is 824/1024 of the canvas, centred.
    let inset = side * 100 / 1024
    let shape = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let path = NSBezierPath(roundedRect: shape, xRadius: shape.width * 0.225, yRadius: shape.width * 0.225)
    NSGradient(colors: [
        NSColor(red: 0.98, green: 0.72, blue: 0.30, alpha: 1),
        NSColor(red: 0.72, green: 0.36, blue: 0.08, alpha: 1),
    ])!.draw(in: path, angle: -90)

    let glass = GlassIcon.image(fill: 1)
    let glassSide = shape.width * 0.78
    let white = NSImage(size: NSSize(width: glassSide, height: glassSide), flipped: false) { rect in
        glass.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    white.draw(in: NSRect(x: (side - glassSide) / 2, y: (side - glassSide) / 2 + side * 0.02, width: glassSide, height: glassSide))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: output.appending(path: name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: output.appending(path: "Contents.json"))
let catalog = output.deletingLastPathComponent().appending(path: "Contents.json")
if !FileManager.default.fileExists(atPath: catalog.path) {
    try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!.write(to: catalog)
}
print("wrote \(images.count) icons to \(output.path)")
