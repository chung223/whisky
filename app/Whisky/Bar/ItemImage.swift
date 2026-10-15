import SwiftUI

/// A menu bar item drawn the way the menu bar draws it: its captured glyph (mask-like glyphs in white or black to suit
/// the background), else an SF Symbol for Apple's items, else the owner's app icon.
struct ItemImage: View {
    let glyph: Glyph?
    let symbol: String?
    let appIcon: NSImage?
    /// The background is dark whatever the appearance (the notch panel, the menu bar preview).
    var onDark = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = onDark || colorScheme == .dark
        if let glyph {
            let height = min(18, glyph.image.size.height)
            if let white = glyph.white, let black = glyph.black {
                Image(nsImage: dark ? white : black)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: height)
            } else {
                // Drawn for a dark menu bar: its white parts need something dark behind them on a light background.
                let backed = glyph.isLight && !dark
                Image(nsImage: glyph.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: height)
                    .padding(backed ? 2 : 0)
                    .background(backed ? Color.black.opacity(0.55) : .clear, in: .rect(cornerRadius: 4))
            }
        } else if let symbol {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(dark ? Color.white : Color.primary)
                .frame(width: 18, height: 18)
        } else if let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(dark ? Color.white : Color.primary)
                .frame(width: 18, height: 18)
        }
    }
}
