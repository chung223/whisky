import Foundation

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
