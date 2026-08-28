import CoreWLAN
import Foundation

enum SystemWifiService {
    private static let profilerCache = WifiProfilerCache()
    private static let detectedWifiDeviceName = discoverWifiDeviceName()

    static func current(reaching deviceIP: String? = nil) async -> MacWifiInfo {
        let snapshot = await Task.detached(priority: .utility) {
            let interface = CWWiFiClient.shared().interface()
            let interfaceName = interface?.interfaceName
            let ssid = sanitizedSSID(interface?.ssid())
                ?? fallbackSSID(preferredInterface: interfaceName)
            return WifiSnapshot(ssid: ssid, interfaceName: interfaceName)
        }.value
        let localIP = await localIPv4(
            reaching: deviceIP,
            preferredInterface: snapshot.interfaceName
        )
        return MacWifiInfo(ssid: snapshot.ssid, localIP: localIP)
    }

    static func sanitizedSSID(_ rawValue: String?) -> String? {
        guard let value = rawValue?.trimmed, !value.isEmpty else { return nil }
        let normalized = value.lowercased()
        let invalidFragments = [
            "error obtaining wireless information",
            "not associated",
            "not connected",
            "unknown ssid",
            "redacted"
        ]
        guard !normalized.hasPrefix("error"),
              !normalized.hasPrefix("you are not"),
              !invalidFragments.contains(where: normalized.contains) else {
            return nil
        }
        return value
    }

    private static func fallbackSSID(preferredInterface: String?) -> String {
        let interfaces = unique([preferredInterface, detectedWifiDeviceName, "en0", "en1"].compactMap { $0 })
        for interface in interfaces {
            guard let result = try? runSync(
                "/usr/sbin/networksetup",
                ["-getairportnetwork", interface]
            ), let separator = result.firstIndex(of: ":") else { continue }
            let candidate = String(result[result.index(after: separator)...])
            if let ssid = sanitizedSSID(candidate) { return ssid }
        }
        return sanitizedSSID(profilerCache.currentSSID()) ?? ""
    }

    private static func localIPv4(reaching deviceIP: String?, preferredInterface: String?) async -> String {
        var interfaces: [String] = []
        if let deviceIP, isIPv4(deviceIP), let routeInterface = await routeInterface(to: deviceIP) {
            interfaces.append(routeInterface)
        }
        interfaces.append(contentsOf: [preferredInterface, detectedWifiDeviceName, "en0", "en1"].compactMap { $0 })
        if let defaultInterface = await routeInterface(to: "default") {
            interfaces.append(defaultInterface)
        }

        for interface in unique(interfaces) {
            guard let result = try? await CommandRunner.run(
                URL(fileURLWithPath: "/usr/sbin/ipconfig"),
                arguments: ["getifaddr", interface],
                allowFailure: true
            ) else { continue }
            let candidate = result.output.trimmed
            if isPrivateIPv4(candidate) { return candidate }
        }
        return ""
    }

    private static func routeInterface(to destination: String) async -> String? {
        guard let result = try? await CommandRunner.run(
            URL(fileURLWithPath: "/sbin/route"),
            arguments: ["-n", "get", destination],
            allowFailure: true
        ) else { return nil }

        for line in result.output.split(separator: "\n") {
            let fields = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard fields.count == 2, fields[0].trimmed == "interface" else { continue }
            let value = fields[1].trimmed
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func discoverWifiDeviceName() -> String? {
        guard let result = try? runSync("/usr/sbin/networksetup", ["-listallhardwareports"]) else {
            return nil
        }
        let lines = result.split(separator: "\n").map(String.init)
        for index in lines.indices {
            let normalized = lines[index].lowercased()
            guard normalized.contains("hardware port:"),
                  normalized.contains("wi-fi") || normalized.contains("airport") else { continue }
            for candidate in lines.dropFirst(index + 1).prefix(3) {
                let fields = candidate.split(separator: ":", maxSplits: 1).map(String.init)
                if fields.count == 2, fields[0].trimmed.lowercased() == "device" {
                    return fields[1].trimmed
                }
            }
        }
        return nil
    }

    private static func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy {
            Int($0).map { (0...255).contains($0) } ?? false
        }
    }

    private static func isPrivateIPv4(_ value: String) -> Bool {
        guard isIPv4(value) else { return false }
        let parts = value.split(separator: ".").compactMap { Int($0) }
        return parts[0] == 10 ||
            (parts[0] == 172 && (16...31).contains(parts[1])) ||
            (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 100 && (64...127).contains(parts[1]))
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func runSync(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmed ?? ""
    }
}

private struct WifiSnapshot: Sendable {
    let ssid: String
    let interfaceName: String?
}

private final class WifiProfilerCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedSSID = ""
    private var expiresAt = Date.distantPast

    func currentSSID() -> String {
        lock.lock()
        defer { lock.unlock() }

        if Date() < expiresAt { return cachedSSID }
        cachedSSID = loadSSID()
        expiresAt = Date().addingTimeInterval(2)
        return cachedSSID
    }

    private func loadSSID() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPAirPortDataType", "-xml"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let reports = plist as? [[String: Any]] else { return "" }

            for report in reports {
                guard let items = report["_items"] as? [[String: Any]] else { continue }
                for item in items {
                    guard let interfaces = item["spairport_airport_interfaces"] as? [[String: Any]] else { continue }
                    for interface in interfaces where interface["spairport_status_information"] as? String == "spairport_status_connected" {
                        guard let network = interface["spairport_current_network_information"] as? [String: Any],
                              let name = network["_name"] as? String else { continue }
                        return name
                    }
                }
            }
        } catch {
            return ""
        }
        return ""
    }
}
