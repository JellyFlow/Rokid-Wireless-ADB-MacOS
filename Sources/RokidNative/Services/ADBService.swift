import AppKit
import Foundation

actor ADBService {
    static let wirelessPort = 5555

    private let adbURL: URL?
    private let mirrorRegistry: MirrorRegistry
    private var mirrorProcesses: [String: Process] = [:]
    private var mirrorProducts: [String: RokidProduct] = [:]
    private var directWirelessTarget: String?

    init(mirrorRegistry: MirrorRegistry) {
        self.mirrorRegistry = mirrorRegistry
        adbURL = ResourceLocator.executable(named: "adb")
    }

    var isAvailable: Bool { adbURL != nil }

    private func adb(_ arguments: [String], allowFailure: Bool = false) async throws -> CommandResult {
        guard let adbURL else {
            throw CommandRunnerError.launch("未找到 adb，请安装 Android Platform Tools")
        }
        return try await CommandRunner.run(adbURL, arguments: arguments, allowFailure: allowFailure)
    }

    func startServer() async {
        _ = try? await adb(["start-server"], allowFailure: true)
        await cleanupStaleProxyTargets()
    }

    func devices() async -> [ADBDevice] {
        guard let result = try? await adb(["devices", "-l"]) else { return [] }
        return result.output
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line in
                let parts = line.split(whereSeparator: \Character.isWhitespace).map(String.init)
                guard parts.count >= 2 else { return nil }
                var attributes: [String: String] = [:]
                for part in parts.dropFirst(2) {
                    let pair = part.split(separator: ":", maxSplits: 1).map(String.init)
                    if pair.count == 2 { attributes[pair[0]] = pair[1] }
                }
                return ADBDevice(
                    serial: parts[0],
                    state: parts[1],
                    model: attributes["model"] ?? "",
                    product: attributes["product"] ?? "",
                    isUSB: !parts[0].contains(":")
                )
            }
    }

    func details(for device: ADBDevice) async -> DeviceDetails {
        async let versionResult = try? adb(["-s", device.serial, "shell", "getprop", "ro.build.version.incremental"])
        async let displayVersionResult = try? adb(["-s", device.serial, "shell", "getprop", "ro.build.display.id"])
        async let serialResult = try? adb(["-s", device.serial, "shell", "getprop", "ro.serialno"])
        async let bootSerialResult = try? adb(["-s", device.serial, "shell", "getprop", "ro.boot.serialno"])
        async let batteryResult = try? adb(["-s", device.serial, "shell", "dumpsys", "battery"])
        async let ipResult = try? adb(["-s", device.serial, "shell", "ip", "-f", "inet", "addr", "show", "wlan0"])
        async let wifiEnabledResult = try? adb(["-s", device.serial, "shell", "settings", "get", "global", "wifi_on"])
        async let wifiStatusResult = try? adb(["-s", device.serial, "shell", "cmd", "wifi", "status"])

        let incrementalVersion = await versionResult?.output.trimmed ?? ""
        let displayVersion = await displayVersionResult?.output.trimmed ?? ""
        let version = incrementalVersion.isEmpty ? displayVersion : incrementalVersion
        let serial = await serialResult?.output.trimmed ?? ""
        let bootSerial = await bootSerialResult?.output.trimmed ?? ""
        let hardwareSerial = serial.isEmpty ? bootSerial : serial
        let batteryOutput = await batteryResult?.output ?? ""
        let ipOutput = await ipResult?.output ?? ""
        let enabled = await wifiEnabledResult?.output.trimmed == "1"
        let wifiStatus = await wifiStatusResult?.output ?? ""
        let ip = firstIPv4(in: ipOutput) ?? "--"
        let ssid = completedSSID(in: wifiStatus)

        return DeviceDetails(
            systemVersion: version.isEmpty ? "--" : version,
            hardwareSerial: hardwareSerial.isEmpty ? "--" : hardwareSerial,
            ipAddress: ip,
            batteryLevel: batteryLevel(in: batteryOutput),
            wifiEnabled: enabled || ip != "--",
            wifiConnected: ip != "--" && !ssid.isEmpty,
            wifiSSID: ssid
        )
    }

    func enableTCPIP(serial: String) async throws -> String {
        try await adb(["-s", serial, "tcpip", String(Self.wirelessPort)]).output
    }

    func switchToUSB(serial: String) async throws -> String {
        try await adb(["-s", serial, "usb"]).output
    }

    func connectWireless(ip: String) async throws -> String {
        guard isAllowedWirelessIPv4(ip) else {
            throw CommandRunnerError.launch("无线 ADB 只能连接眼镜的真实私网 IPv4 地址")
        }
        await disconnectWireless()
        let target = "\(ip):\(Self.wirelessPort)"

        do {
            var lastResponse = "无法连接 \(target)"
            var lastExitCode: Int32 = 1
            var restartedServer = false

            for attempt in 0..<6 {
                let result = try await adb(["connect", target], allowFailure: true)
                let response = [result.output, result.errorOutput]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                if result.exitCode == 0, response.localizedCaseInsensitiveContains("connected") {
                    try await waitForDevice(target)
                    directWirelessTarget = target
                    return target
                }

                if !response.isEmpty { lastResponse = response }
                lastExitCode = result.exitCode

                // The long-running adb daemon may retain a stale route after the Mac changes Wi-Fi.
                if !restartedServer, response.localizedCaseInsensitiveContains("no route to host") {
                    _ = try? await adb(["kill-server"], allowFailure: true)
                    try await Task.sleep(nanoseconds: 300_000_000)
                    _ = try? await adb(["start-server"], allowFailure: true)
                    restartedServer = true
                } else if attempt < 5 {
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            }

            throw CommandRunnerError.failed(lastResponse, lastExitCode)
        } catch {
            _ = try? await adb(["disconnect", target], allowFailure: true)
            throw error
        }
    }

    func disconnectWireless() async {
        if let directWirelessTarget {
            _ = try? await adb(["disconnect", directWirelessTarget], allowFailure: true)
        }
        directWirelessTarget = nil
        await cleanupStaleProxyTargets()
    }

    private func waitForDevice(_ target: String, attempts: Int = 10) async throws {
        var lastError = "设备尚未就绪"
        for _ in 0..<attempts {
            let state = try await adb(["-s", target, "get-state"], allowFailure: true)
            if state.exitCode == 0, state.output.trimmed == "device" { return }
            let response = [state.output, state.errorOutput].filter { !$0.isEmpty }.joined(separator: "\n")
            if !response.isEmpty { lastError = response }
            try await Task.sleep(nanoseconds: 400_000_000)
        }
        throw CommandRunnerError.failed(lastError, 1)
    }

    private func cleanupStaleProxyTargets() async {
        guard let result = try? await adb(["devices"]) else { return }
        for line in result.output.split(separator: "\n").dropFirst() {
            let fields = line.split(whereSeparator: \Character.isWhitespace).map(String.init)
            guard fields.count >= 2,
                  fields[0].hasPrefix("127.0.0.1:"),
                  fields[1] != "device" else { continue }
            _ = try? await adb(["disconnect", fields[0]], allowFailure: true)
        }
    }

    func setWifi(device: ADBDevice, enabled: Bool) async throws {
        let serial = device.serial
        let stateValue = enabled ? "enabled" : "disabled"
        let command = try await adb(
            ["-s", serial, "shell", "cmd", "wifi", "set-wifi-enabled", stateValue],
            allowFailure: true
        )
        let response = [command.output, command.errorOutput].filter { !$0.isEmpty }.joined(separator: "\n")
        let normalized = response.lowercased()
        let commandRejected = normalized.contains("unknown command") ||
            normalized.contains("exception") ||
            normalized.contains("permission denial")

        if commandRejected {
            _ = try await adb(
                ["-s", serial, "shell", "svc", "wifi", enabled ? "enable" : "disable"],
                allowFailure: true
            )
        }

        let expected = enabled ? "1" : "0"
        for _ in 0..<12 {
            let state = try await adb(
                ["-s", serial, "shell", "settings", "get", "global", "wifi_on"],
                allowFailure: true
            )
            if state.output.trimmed == expected { return }

            // Disabling Wi-Fi over wireless ADB drops the transport before adb can return a result.
            if !enabled, !device.isUSB {
                let transport = try await adb(["-s", serial, "get-state"], allowFailure: true)
                if transport.exitCode != 0 || transport.output.trimmed != "device" { return }
            }
            try await Task.sleep(nanoseconds: 400_000_000)
        }

        let action = enabled ? "开启" : "关闭"
        throw CommandRunnerError.failed("眼镜 Wi-Fi 未能\(action)，请确认 ADB 连接状态", command.exitCode)
    }

    func connectWifi(serial: String, ssid: String, password: String) async throws {
        _ = try await adb(["-s", serial, "shell", "cmd", "wifi", "set-wifi-enabled", "enabled"], allowFailure: true)
        try await Task.sleep(nanoseconds: 600_000_000)

        var arguments = ["-s", serial, "shell", "cmd", "wifi", "connect-network", ssid]
        if password.isEmpty {
            arguments.append("open")
        } else {
            arguments.append(contentsOf: ["wpa2", password])
        }
        let result = try await adb(arguments, allowFailure: true)
        let response = [result.output, result.errorOutput].filter { !$0.isEmpty }.joined(separator: "\n")
        let normalized = response.lowercased()
        if result.exitCode != 0 || normalized.contains("failed") || normalized.contains("error") || normalized.contains("exception") {
            throw CommandRunnerError.failed(response.isEmpty ? "眼镜拒绝了 Wi-Fi 连接命令" : response, result.exitCode)
        }

        for _ in 0..<12 {
            let status = try await adb(["-s", serial, "shell", "cmd", "wifi", "status"], allowFailure: true)
            if completedSSID(in: status.output) == ssid { return }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw CommandRunnerError.failed("眼镜未能连接到 \(ssid)，请检查密码和信号", 1)
    }

    func startScrcpy(
        target: String,
        deviceKey: String? = nil,
        product: RokidProduct = .glasses
    ) async throws -> Bool {
        let key = deviceKey ?? target
        if let existing = mirrorProcesses[key], existing.isRunning {
            if mirrorProducts[key] == product { return true }
            existing.terminate()
            mirrorProcesses.removeValue(forKey: key)
            mirrorProducts.removeValue(forKey: key)
            mirrorRegistry.remove(key)
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        guard let scrcpyURL = ResourceLocator.executable(named: "scrcpy") else {
            throw CommandRunnerError.launch("未找到 scrcpy")
        }

        let process = Process()
        process.executableURL = scrcpyURL
        process.arguments = ["--serial", target]
            + product.scrcpyVideoArguments
            + ["--window-title", "\(product.rawValue) \(key)"]
        process.currentDirectoryURL = scrcpyURL.deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        let binaryDirectory = scrcpyURL.deletingLastPathComponent()
        environment["DYLD_LIBRARY_PATH"] = binaryDirectory.path
        environment["PATH"] = [
            binaryDirectory.path,
            adbURL?.deletingLastPathComponent().path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].compactMap { $0 }.joined(separator: ":")
        if let adbURL { environment["ADB"] = adbURL.path }
        if let serverURL = ResourceLocator.resourceURL("bin/scrcpy-server"),
           FileManager.default.fileExists(atPath: serverURL.path) {
            environment["SCRCPY_SERVER_PATH"] = serverURL.path
        }
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice

        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rokid-scrcpy-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        process.standardError = logHandle
        try process.run()

        try await Task.sleep(nanoseconds: 800_000_000)
        if !process.isRunning {
            try? logHandle.close()
            let log = String(data: (try? Data(contentsOf: logURL)) ?? Data(), encoding: .utf8)?.trimmed ?? ""
            try? FileManager.default.removeItem(at: logURL)
            throw CommandRunnerError.launch(log.isEmpty ? "scrcpy 启动后立即退出" : log)
        }
        let _ = await MainActor.run {
            NSRunningApplication(processIdentifier: process.processIdentifier)?.activate(
                options: [.activateAllWindows, .activateIgnoringOtherApps]
            )
        }
        try? FileManager.default.removeItem(at: logURL)
        mirrorProcesses[key] = process
        mirrorProducts[key] = product
        mirrorRegistry.insert(key)
        return false
    }

    func stopScrcpy(deviceKey: String) {
        guard let process = mirrorProcesses[deviceKey] else { return }
        if process.isRunning { process.terminate() }
        mirrorProcesses.removeValue(forKey: deviceKey)
        mirrorProducts.removeValue(forKey: deviceKey)
        mirrorRegistry.remove(deviceKey)
    }

    func isMirroring(deviceKey: String) -> Bool {
        guard let process = mirrorProcesses[deviceKey] else { return false }
        if process.isRunning { return true }
        mirrorProcesses.removeValue(forKey: deviceKey)
        mirrorProducts.removeValue(forKey: deviceKey)
        mirrorRegistry.remove(deviceKey)
        return false
    }

    private func firstIPv4(in text: String) -> String? {
        let pattern = #"\binet\s+((?:\d{1,3}\.){3}\d{1,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[range])
        return value == "127.0.0.1" ? nil : value
    }

    private func isAllowedWirelessIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        return parts[0] == 10 ||
            (parts[0] == 172 && (16...31).contains(parts[1])) ||
            (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 100 && (64...127).contains(parts[1]))
    }

    private func batteryLevel(in text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0].trimmed == "level" else { continue }
            return Int(parts[1].trimmed)
        }
        return nil
    }

    private func completedSSID(in text: String) -> String {
        if let range = text.range(of: #"Wifi is connected to \"[^\"]+\""#, options: .regularExpression) {
            return String(text[range])
                .replacingOccurrences(of: "Wifi is connected to", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        for line in text.split(separator: "\n").map(String.init) {
            guard line.contains("mWifiInfo SSID"), line.contains("Supplicant state: COMPLETED") else { continue }
            guard let range = line.range(of: #"SSID:\s*(\"[^\"]+\"|[^,]+),"#, options: .regularExpression) else { continue }
            let fragment = String(line[range])
                .replacingOccurrences(of: "SSID:", with: "")
                .dropLast()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if fragment != "<unknown ssid>" { return fragment }
        }
        return ""
    }
}

final class MirrorRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var keys = Set<String>()

    func contains(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return keys.contains(key)
    }

    func insert(_ key: String) {
        lock.lock()
        keys.insert(key)
        lock.unlock()
    }

    func remove(_ key: String) {
        lock.lock()
        keys.remove(key)
        lock.unlock()
    }
}
