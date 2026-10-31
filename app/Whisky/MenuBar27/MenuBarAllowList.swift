import AppKit
import WhiskyCore

/// macOS 27: restricts the menu bar to the apps Whisky allows, through WhiskyHolder (see its header). Everything else
/// is neither drawn nor put in the system's » overflow; Whisky opens those apps from Whisky Bar instead.
///
/// The restriction lives and dies with the holder process, so this is fail-open: Whisky quitting or crashing closes
/// the holder's stdin, it ends, and the whole menu bar comes back.
///
/// Measured on 27.2 (2026-10-31): two restrictions active at once (a second one in the same process, or in another
/// process) show the whole menu bar; a new list has to replace the old one, so the holder lifts the old one first.
@MainActor
final class MenuBarAllowList {
    /// The apps allowed now; nil while nothing is restricted.
    private(set) var allowed: Set<String>?
    private var holder: Process?
    private var input: FileHandle?
    private var replies: Replies?
    /// Requests go one at a time: each waits for the reply to the one before.
    private var last: Task<Bool, Never>?

    static var isAvailable: Bool {
        !PlatformSupport.movesItems && Bundle.main.url(forAuxiliaryExecutable: "WhiskyHolder") != nil
    }

    /// Restricts the menu bar to `bundles` (system items always stay). Returns false when it couldn't be applied; the
    /// whole menu bar is shown then.
    @discardableResult
    func apply(_ bundles: Set<String>) async -> Bool {
        await enqueue { [weak self] in
            guard let self else { return false }
            if bundles == self.allowed, self.holder?.isRunning == true { return true }
            guard await self.send("allow " + bundles.sorted().joined(separator: " ")) else {
                self.allowed = nil
                return false
            }
            self.allowed = bundles
            return true
        }
    }

    /// Shows the whole menu bar again.
    func lift() async {
        _ = await enqueue { [weak self] in
            guard let self, self.allowed != nil else { return true }
            self.allowed = nil
            return await self.send("lift")
        }
    }

    /// Ends the holder (Whisky is quitting): the whole menu bar comes back.
    func stop() {
        holder?.terminate()
        holder = nil
        input = nil
        replies = nil
        allowed = nil
    }

    private func enqueue(_ work: @escaping @MainActor () async -> Bool) async -> Bool {
        let previous = last
        let task = Task { @MainActor in
            _ = await previous?.value
            return await work()
        }
        last = task
        return await task.value
    }

    /// Sends one request and waits for its reply (starting the holder when needed). A holder that doesn't answer in
    /// time is ended, which lifts whatever it held.
    private func send(_ request: String) async -> Bool {
        guard startHolderIfNeeded(), let input else { return false }
        do {
            try input.write(contentsOf: Data((request + "\n").utf8))
        } catch {
            Log.write("menu bar 27: couldn't reach the holder: \(error.localizedDescription)")
            stop()
            return false
        }
        let reply = await nextLine(timeout: .seconds(3))
        guard reply == "ok" else {
            Log.write("menu bar 27: \(request.split(separator: " ").first ?? "") → \(reply ?? "no answer"); the whole menu bar shows")
            stop()
            return false
        }
        return true
    }

    private func startHolderIfNeeded() -> Bool {
        if holder?.isRunning == true { return true }
        // A holder that died between requests mustn't take Whisky with it: writing to its closed pipe would raise
        // SIGPIPE, which ends the process by default.
        signal(SIGPIPE, SIG_IGN)
        guard Self.isAvailable, let url = Bundle.main.url(forAuxiliaryExecutable: "WhiskyHolder") else { return false }
        let process = Process()
        process.executableURL = url
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        let replies = Replies()
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil } else { replies.append(data) }
        }
        do {
            try process.run()
        } catch {
            Log.write("menu bar 27: couldn't start the holder: \(error.localizedDescription)")
            return false
        }
        holder = process
        input = stdin.fileHandleForWriting
        self.replies = replies
        return true
    }

    private func nextLine(timeout: Duration) async -> String? {
        guard let replies else { return nil }
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let line = replies.next() { return line }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }
}

/// The holder's reply lines, as they arrive.
private final class Replies: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var lines: [String] = []

    func append(_ data: Data) {
        lock.withLock {
            buffer.append(data)
            while let newline = buffer.firstIndex(of: 0x0A) {
                lines.append(String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self))
                buffer.removeSubrange(buffer.startIndex...newline)
            }
        }
    }

    func next() -> String? {
        lock.withLock { lines.isEmpty ? nil : lines.removeFirst() }
    }
}
