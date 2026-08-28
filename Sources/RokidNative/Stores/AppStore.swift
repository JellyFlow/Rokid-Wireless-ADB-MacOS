import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class AppStore: ObservableObject {
    @Published var selection: NavigationSection = .devices
    @Published var selectedProduct: RokidProduct = .glasses
    @Published var devices: [ADBDevice] = []
    @Published var selectedDevice: ADBDevice?
    @Published var deviceDetails = DeviceDetails()
    @Published var macWifi = MacWifiInfo()
    @Published var operationState: OperationState = .idle

    @Published var wifiSSID = ""
    @Published var wifiPassword = ""
    @Published var wirelessIP = ""

    @Published var showingQR = false
    @Published var qrSecurity = "WPA"
    @Published var qrIdentity = ""
    @Published var qrImage: NSImage?
    @Published var qrSession: QRCastSession?
    @Published var qrState: OperationState = .idle
    @Published var qrShowingConfiguration = true

    @Published var preferredAppearance = UserDefaults.standard.string(forKey: "appearance") ?? "system"
    @Published var preferredLanguage = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.system.rawValue

    private let mirrorRegistry = MirrorRegistry()
    private let callbackServer = CallbackServer()
    private let adb: ADBService
    private var refreshTask: Task<Void, Never>?
    private var wifiRefreshTask: Task<Void, Never>?
    private var qrTimeoutTask: Task<Void, Never>?
    private let logger = Logger(
        subsystem: "com.rokid.wireless-projection.native.v2",
        category: "QRCode"
    )

    init() {
        UserDefaults.standard.removeObject(forKey: "tcpPort")
        LocationPermissionService.shared.request()
        LocalNetworkPermissionService.request()
        adb = ADBService(mirrorRegistry: mirrorRegistry)
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.adb.startServer()
            while !Task.isCancelled {
                if !self.showingQR {
                    await self.refreshDevices()
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        wifiRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshWifi()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        wifiRefreshTask?.cancel()
        qrTimeoutTask?.cancel()
        callbackServer.stop()
    }

    var usbDevice: ADBDevice? { devices.first { $0.isUSB && $0.state == "device" } }
    var wirelessDevice: ADBDevice? { devices.first { !$0.isUSB && $0.state == "device" } }
    var wifiControlDevice: ADBDevice? { usbDevice ?? wirelessDevice }
    var appLanguage: AppLanguage { AppLanguage(rawValue: preferredLanguage) ?? .system }

    func localized(_ key: String) -> String {
        Localization.text(key, language: appLanguage)
    }

    func refresh() async {
        async let devices: Void = refreshDevices()
        async let wifi: Void = refreshWifi()
        _ = await (devices, wifi)
    }

    private func refreshWifi() async {
        let deviceIP = deviceDetails.ipAddress == "--" ? nil : deviceDetails.ipAddress
        let newWifi = await SystemWifiService.current(reaching: deviceIP)
        if macWifi != newWifi { macWifi = newWifi }
        if !newWifi.ssid.isEmpty, wifiSSID != newWifi.ssid { wifiSSID = newWifi.ssid }
    }

    private func refreshDevices() async {
        let newDevices = await adb.devices()
        if devices != newDevices { devices = newDevices }

        let nextSelection: ADBDevice?
        if let current = selectedDevice, newDevices.contains(where: { $0.serial == current.serial }) {
            nextSelection = newDevices.first { $0.serial == current.serial }
        } else {
            nextSelection = newDevices.first { $0.isUSB && $0.state == "device" } ?? newDevices.first
        }
        if selectedDevice != nextSelection {
            let connectedDeviceChanged = selectedDevice?.serial != nextSelection?.serial
            let detectedProductChanged = selectedDevice?.rokidProduct != nextSelection?.rokidProduct
            selectedDevice = nextSelection
            if (connectedDeviceChanged || detectedProductChanged),
               let product = nextSelection?.rokidProduct {
                selectedProduct = product
            }
        }

        if let nextSelection, nextSelection.state == "device" {
            let newDetails = await adb.details(for: nextSelection)
            if deviceDetails != newDetails { deviceDetails = newDetails }
        } else {
            let emptyDetails = DeviceDetails()
            if deviceDetails != emptyDetails { deviceDetails = emptyDetails }
        }
    }

    func persistSettings() {
        UserDefaults.standard.set(preferredAppearance, forKey: "appearance")
        UserDefaults.standard.set(preferredLanguage, forKey: "language")
    }

    func startWiredMirror() {
        guard let device = usbDevice else {
            operationState = .failure(localized("请先通过 USB 连接眼镜"))
            return
        }
        let product = selectedProduct
        let successMessage = localized("有线投屏已启动")
        runOperation(localized("正在启动有线投屏…")) { [adb] in
            _ = try await adb.startScrcpy(target: device.serial, product: product)
            return successMessage
        }
    }

    func stopWiredMirror() {
        guard let device = usbDevice else {
            operationState = .failure(localized("未找到有线设备"))
            return
        }
        let successMessage = localized("有线投屏已断开")
        Task {
            await adb.stopScrcpy(deviceKey: device.serial)
            operationState = .success(successMessage)
        }
    }

    func enableWirelessMirror() {
        guard let device = usbDevice else {
            operationState = .failure(localized("首次开启无线 ADB 需要 USB 连接"))
            return
        }
        let product = selectedProduct
        let language = appLanguage
        runOperation(localized("正在开启无线 ADB…")) { [adb] in
            _ = try await adb.enableTCPIP(serial: device.serial)
            try await Task.sleep(nanoseconds: 1_200_000_000)
            let details = await adb.details(for: device)
            guard details.ipAddress != "--" else {
                throw CommandRunnerError.launch(Localization.text("未获取到眼镜 Wi-Fi IP", language: language))
            }
            let target = try await adb.connectWireless(ip: details.ipAddress)
            _ = try await adb.startScrcpy(target: target, deviceKey: device.serial, product: product)
            return String(
                format: Localization.text("无线投屏已启动：%@:5555", language: language),
                details.ipAddress
            )
        }
    }

    func connectWireless() {
        let ip = wirelessIP.trimmed
        guard isIPv4(ip) else {
            operationState = .failure(localized("请输入有效的设备 IPv4 地址"))
            return
        }
        let device = usbDevice
        let product = selectedProduct
        let language = appLanguage
        let workingMessage = String(format: localized("正在连接 %@:5555…"), ip)
        runOperation(workingMessage) { [adb] in
            if let device {
                _ = try await adb.enableTCPIP(serial: device.serial)
                try await Task.sleep(nanoseconds: 1_200_000_000)
            }
            let target = try await adb.connectWireless(ip: ip)
            _ = try await adb.startScrcpy(
                target: target,
                deviceKey: device?.serial ?? ip,
                product: product
            )
            return String(format: Localization.text("已连接并启动投屏：%@:5555", language: language), ip)
        }
    }

    func disconnectWireless() {
        let successMessage = localized("无线 ADB 已断开")
        runOperation(localized("正在断开无线 ADB…")) { [adb] in
            await adb.disconnectWireless()
            return successMessage
        }
    }

    func setDeviceWifi(enabled: Bool) {
        guard let device = wifiControlDevice else {
            operationState = .failure(localized("请先通过 USB 或无线 ADB 连接眼镜"))
            return
        }
        let workingMessage = localized(enabled ? "正在开启眼镜 Wi-Fi…" : "正在关闭眼镜 Wi-Fi…")
        let successMessage = localized(enabled ? "眼镜 Wi-Fi 已开启" : "眼镜 Wi-Fi 已关闭")
        runOperation(workingMessage) { [adb] in
            try await adb.setWifi(device: device, enabled: enabled)
            return successMessage
        }
    }

    func connectDeviceWifi() {
        guard let device = usbDevice else {
            operationState = .failure(localized("请先通过 USB 连接眼镜"))
            return
        }
        guard !wifiSSID.trimmed.isEmpty else {
            operationState = .failure(localized("请输入 Wi-Fi 名称"))
            return
        }
        let language = appLanguage
        runOperation(localized("正在连接眼镜 Wi-Fi…")) { [adb, wifiSSID, wifiPassword] in
            try await adb.connectWifi(serial: device.serial, ssid: wifiSSID.trimmed, password: wifiPassword)
            return String(
                format: Localization.text("眼镜已连接到 %@", language: language),
                wifiSSID.trimmed
            )
        }
    }

    func openQR() {
        stopQRListener(reason: "starting a new QR flow")
        LocationPermissionService.shared.request()
        LocalNetworkPermissionService.request()
        qrImage = nil
        qrSession = nil
        qrState = .idle
        qrShowingConfiguration = true
        if wifiSSID.isEmpty { wifiSSID = macWifi.ssid }
        showingQR = true
    }

    func generateQR() {
        stopQRListener(reason: "generating a new QR session")
        let ip = macWifi.localIP
        guard isPrivateIPv4(ip) else {
            qrState = .failure(localized("未找到符合协议要求的电脑私网 IPv4 地址"))
            return
        }
        let profile = WirelessWifiProfile(
            ssid: wifiSSID.trimmed,
            password: wifiPassword,
            security: qrSecurity,
            identity: qrIdentity.trimmed
        )

        let language = appLanguage
        qrState = .working(localized("正在生成二维码…"))
        let sessionID = UUID().uuidString.uppercased()
        Task {
            do {
                let callbackPort = try await callbackServer.start(
                    sessionID: sessionID,
                    action: .enable,
                    isMirroring: { [mirrorRegistry] in mirrorRegistry.contains($0) },
                    onCallback: { [weak self] callback in
                        Task { @MainActor in await self?.handle(callback: callback) }
                    }
                )
                let (session, image): (QRCastSession, NSImage)
                do {
                    (session, image) = try QRCodeService.makeSession(
                        callbackIP: ip,
                        callbackPort: callbackPort,
                        sessionID: sessionID,
                        wifi: profile
                    )
                } catch {
                    callbackServer.stop()
                    throw error
                }
                qrSession = session
                qrImage = image
                qrShowingConfiguration = false
                qrState = .working(Localization.text("等待眼镜扫码", language: language))
                scheduleQRTimeout(sessionID: session.id)
                logger.info(
                    "QR callback listener ready for session \(session.id, privacy: .public) on port \(callbackPort)"
                )
            } catch {
                qrState = .failure(String(
                    format: Localization.text("无法启动扫码回调服务：%@", language: language),
                    error.localizedDescription
                ))
            }
        }
    }

    func resetQR() {
        stopQRListener(reason: "QR session reset")
        qrSession = nil
        qrImage = nil
        qrShowingConfiguration = true
        qrState = .idle
    }

    func closeQR() {
        showingQR = false
        if let sessionID = qrSession?.id {
            logger.info("QR sheet closed; listener remains active for session \(sessionID, privacy: .public)")
        }
    }

    private func handle(callback: WirelessAdbCallback) async {
        stopQRListener(reason: "valid callback received")
        logger.info("Received valid QR callback for session \(callback.sessionId, privacy: .public)")
        guard let device = callback.device else {
            qrState = .failure(callback.message ?? localized("眼镜回调缺少设备信息"))
            return
        }
        qrState = .working(localized("眼镜已就绪，正在连接投屏…"))
        let product = selectedProduct
        do {
            let target = try await adb.connectWireless(ip: device.ip)
            let already = try await adb.startScrcpy(
                target: target,
                deviceKey: device.serial ?? target,
                product: product
            )
            qrState = .success(localized(already ? "该眼镜已在投屏" : "投屏已启动"))
            await refresh()
        } catch {
            qrState = .failure(error.localizedDescription)
        }
    }

    private func scheduleQRTimeout(sessionID: String) {
        qrTimeoutTask?.cancel()
        qrTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000_000)
            guard !Task.isCancelled, let self, self.qrSession?.id == sessionID else { return }
            self.stopQRListener(reason: "QR session timed out")
            self.qrSession = nil
            if self.showingQR {
                self.qrState = .failure(self.localized("二维码已过期，请重新生成"))
            }
        }
    }

    private func stopQRListener(reason: String) {
        qrTimeoutTask?.cancel()
        qrTimeoutTask = nil
        callbackServer.stop()
        logger.info("Stopped QR callback listener: \(reason, privacy: .public)")
    }

    private func runOperation(_ message: String, operation: @escaping () async throws -> String) {
        operationState = .working(message)
        Task {
            do {
                operationState = .success(try await operation())
                await refresh()
            } catch {
                operationState = .failure(error.localizedDescription)
            }
        }
    }

    private func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { Int($0).map { (0...255).contains($0) } ?? false }
    }

    private func isPrivateIPv4(_ value: String) -> Bool {
        guard isIPv4(value) else { return false }
        let parts = value.split(separator: ".").compactMap { Int($0) }
        return parts[0] == 10 ||
            (parts[0] == 172 && (16...31).contains(parts[1])) ||
            (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 100 && (64...127).contains(parts[1]))
    }
}
