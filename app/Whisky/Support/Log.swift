import Foundation

/// Appends lines to ~/Library/Logs/Whisky/whisky.log (rotated at 2 MB, one old file kept).
enum Log {
    static let directory: URL = {
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Whisky", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let fileURL = directory.appending(path: "whisky.log")

    private static let queue = DispatchQueue(label: "com.chung.whisky.log")
    private static let maxBytes = 2 * 1024 * 1024

    static func write(_ message: String) {
        let line = "\(Date().formatted(.iso8601)) \(message)\n"
        queue.async {
            let manager = FileManager.default
            if let size = try? manager.attributesOfItem(atPath: fileURL.path)[.size] as? Int, size > maxBytes {
                let old = directory.appending(path: "whisky.old.log")
                try? manager.removeItem(at: old)
                try? manager.moveItem(at: fileURL, to: old)
            }
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
