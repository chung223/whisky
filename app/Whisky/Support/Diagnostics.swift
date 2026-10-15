import AppKit

/// `kill -USR1 <pid>` writes a full scan to ~/Library/Logs/Whisky/diagnose.json.
/// The scan has to run inside Whisky: Accessibility trust belongs to Whisky, not to a terminal.
@MainActor
final class Diagnostics {
    private let source: DispatchSourceSignal

    init(model: BarModel) {
        signal(SIGUSR1, SIG_IGN)
        source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                _ = Task { await model.writeDiagnostics() }
            }
        }
        source.resume()
    }
}

/// Draws Whisky's own open windows into PNGs next to the log (`whisky://snapshot`), so their layout can be checked
/// without Screen Recording. Materials such as Liquid Glass don't render this way; text and controls do.
@MainActor
enum WindowSnapshot {
    static func writeVisibleWindows() {
        for (index, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let view = window.contentView, view.bounds.width > 4,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let name = window.title.isEmpty ? String(describing: type(of: window)) : window.title
            let url = Log.directory.appending(path: "snapshot-\(index)-\(name).png")
            do {
                try rep.representation(using: .png, properties: [:])?.write(to: url)
                Log.write("snapshot: \(url.lastPathComponent) \(Int(view.bounds.width))×\(Int(view.bounds.height))")
            } catch {
                Log.write("snapshot failed: \(error.localizedDescription)")
            }
        }
    }
}
