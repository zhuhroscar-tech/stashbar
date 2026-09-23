import Foundation

/// Minimal file-based debug logger for spike/dev builds. Writes to a fixed
/// path so we can inspect behavior across multi-display setups without
/// depending on unified-logging visibility quirks.
func debugLog(_ message: String) {
    let line = "\(Date()) \(message)\n"
    let path = "/tmp/stashbar_debug.log"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path), let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
