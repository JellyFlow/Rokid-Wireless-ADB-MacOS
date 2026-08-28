import AppKit
import Foundation

enum ResourceLocator {
    static func resourceURL(_ relativePath: String) -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent(relativePath)
    }

    static func image(named name: String) -> NSImage? {
        guard let url = resourceURL("assets/\(name)") else { return nil }
        return NSImage(contentsOf: url)
    }

    static func executable(named name: String) -> URL? {
        let bundled = resourceURL("bin/\(name)")
        if let bundled, FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        for path in ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
