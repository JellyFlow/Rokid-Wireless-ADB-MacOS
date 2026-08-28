import Foundation

enum NavigationSection: String, CaseIterable, Identifiable {
    case devices
    case settings
    case help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: return "设备"
        case .settings: return "设置"
        case .help: return "帮助"
        }
    }

    var systemImage: String {
        switch self {
        case .devices: return "display"
        case .settings: return "sun.max"
        case .help: return "questionmark.circle"
        }
    }
}

enum RokidProduct: String, CaseIterable, Identifiable {
    case glasses = "Rokid Glasses"
    case lite = "Rokid AR Lite"
    case studio = "Rokid AR Studio"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .glasses: return "带显示的 AI 眼镜"
        case .lite: return "轻量级 AR 眼镜"
        case .studio: return "专业级 AR 眼镜"
        }
    }

    var assetName: String { "\(rawValue).png" }

    var scrcpyVideoArguments: [String] {
        switch self {
        case .glasses:
            return []
        case .lite:
            return ["--display-id=2", "--crop=1920:1200:0:0"]
        case .studio:
            return ["--display-id=2", "--crop=1920:1200:0:0"]
        }
    }
}

struct ADBDevice: Identifiable, Hashable, Sendable {
    let serial: String
    let state: String
    let model: String
    let product: String
    let isUSB: Bool

    var id: String { serial }
    var rokidProduct: RokidProduct? {
        switch model {
        case "RG-glasses", "RG_glasses": return .glasses
        case "RG-lite", "RG_lite", "RG-station2", "RG_station2": return .lite
        case "RG-studio", "RG_studio", "RG-stationPro", "RG_stationPro": return .studio
        default: return nil
        }
    }

    var displayName: String {
        rokidProduct?.rawValue ?? (model.isEmpty ? "Rokid 设备" : model)
    }
}

struct DeviceDetails: Sendable, Equatable {
    var systemVersion = "--"
    var hardwareSerial = "--"
    var ipAddress = "--"
    var batteryLevel: Int?
    var wifiEnabled = false
    var wifiConnected = false
    var wifiSSID = ""
}

struct MacWifiInfo: Sendable, Equatable {
    var ssid = ""
    var localIP = ""
    var connected: Bool { !ssid.isEmpty && !localIP.isEmpty }
}

struct WirelessWifiProfile: Sendable {
    var ssid: String
    var password: String
    var security: String
    var identity: String = ""
}

enum QRCastAction: String {
    case enable = "ENABLE"

    var protocolType: String { "ENABLE_WIRELESS_ADB" }
}

struct QRCastSession {
    let id: String
    let action: QRCastAction
    let payload: String
}

struct WirelessAdbCallback: Codable, Sendable {
    let type: String
    let version: Int
    let action: String
    let sessionId: String
    let status: String
    let device: WirelessAdbCallbackDevice?
    let errorCode: String?
    let message: String?
}

struct WirelessAdbCallbackDevice: Codable, Sendable {
    let serial: String?
    let ip: String
    let adbPort: Int
    let adbEnabled: Bool?
    let tcpPortOpen: Bool
}

struct CallbackResponse: Encodable {
    let ok: Bool
    let alreadyMirroring: Bool
    var error: String?
}

enum OperationState: Equatable {
    case idle
    case working(String)
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .idle: return ""
        case .working(let message), .success(let message), .failure(let message): return message
        }
    }
}
