import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum QRCodeService {
    static let defaultCallbackPort: UInt16 = 18_080
    static let callbackPath = "/rokid/wireless-adb/callback"

    static func makeSession(
        callbackIP: String,
        callbackPort: UInt16 = defaultCallbackPort,
        sessionID: String = UUID().uuidString.uppercased(),
        wifi: WirelessWifiProfile
    ) throws -> (QRCastSession, NSImage) {
        let action = QRCastAction.enable
        let callbackURL = "http://\(callbackIP):\(callbackPort)\(callbackPath)"
        var object: [String: Any] = [
            "PORT": 5555,
            "SID": sessionID,
            "T": action.protocolType,
            "U": callbackURL
        ]

        try validate(wifi)
        var wifiObject: [String: Any] = [
            "P": wifi.security == "NOPASS" ? "" : wifi.password,
            "S": wifi.ssid,
            "T": wifi.security.uppercased()
        ]
        if wifi.security.uppercased() == "EAP" {
            wifiObject["I"] = wifi.identity
            wifiObject["EAP"] = "PEAP"
            wifiObject["PH2"] = "MSCHAPV2"
        }
        object["PERSIST"] = false
        object["WIFI"] = wifiObject

        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let payload = String(data: data, encoding: .utf8) else { throw QRCodeError.encoding }
        guard let image = qrImage(payload: payload) else { throw QRCodeError.image }
        return (QRCastSession(id: sessionID, action: action, payload: payload), image)
    }

    static func qrImage(payload: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: .init(scaleX: 6, y: 6)) else { return nil }
        let representation = NSCIImageRep(ciImage: output)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }

    private static func validate(_ wifi: WirelessWifiProfile) throws {
        guard !wifi.ssid.isEmpty, wifi.ssid.lengthOfBytes(using: .utf8) <= 32 else {
            throw QRCodeError.invalidWifi("SSID 必须为 1～32 个 UTF-8 字节")
        }
        let security = wifi.security.uppercased()
        guard ["WPA", "WEP", "NOPASS", "EAP"].contains(security) else {
            throw QRCodeError.invalidWifi("Wi-Fi 安全类型无效")
        }
        if security == "WPA" {
            let validLength = (8...63).contains(wifi.password.count)
            let validPSK = wifi.password.count == 64 && wifi.password.allSatisfy(\.isHexDigit)
            guard validLength || validPSK else {
                throw QRCodeError.invalidWifi("WPA 密码必须为 8～63 个字符或 64 位十六进制 PSK")
            }
        }
        if security == "EAP" && (wifi.identity.isEmpty || wifi.password.isEmpty) {
            throw QRCodeError.invalidWifi("企业 Wi-Fi 必须填写身份和密码")
        }
    }
}

enum QRCodeError: LocalizedError {
    case invalidWifi(String)
    case encoding
    case image

    var errorDescription: String? {
        switch self {
        case .invalidWifi(let message): return message
        case .encoding: return "二维码 JSON 编码失败"
        case .image: return "二维码图像生成失败"
        }
    }
}
