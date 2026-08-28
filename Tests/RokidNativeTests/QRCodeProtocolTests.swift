import Foundation

@main
struct QRCodeProtocolTests {
    static func main() throws {
        let (session, _) = try QRCodeService.makeSession(
            callbackIP: "192.168.3.10",
            callbackPort: 49_152,
            wifi: WirelessWifiProfile(
                ssid: "Example-WiFi",
                password: "example-password",
                security: "WPA"
            )
        )
        let data = try XCTUnwrap(session.payload.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let wifi = try XCTUnwrap(object["WIFI"] as? [String: Any])

        precondition(object["T"] as? String == "ENABLE_WIRELESS_ADB")
        precondition(object["SID"] as? String == session.id)
        precondition(object["U"] as? String == "http://192.168.3.10:49152/rokid/wireless-adb/callback")
        precondition(object["PORT"] as? Int == 5555)
        precondition(object["PERSIST"] as? Bool == false)
        precondition(wifi["S"] as? String == "Example-WiFi")
        precondition(wifi["P"] as? String == "example-password")
        precondition(wifi["T"] as? String == "WPA")
    }
}

private func XCTUnwrap<T>(_ value: T?) throws -> T {
    guard let value else { throw TestError.missingValue }
    return value
}

private enum TestError: Error {
    case missingValue
}
