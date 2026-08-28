import Foundation
import Network

@main
struct CallbackServerTests {
    static func main() async throws {
        let server = CallbackServer()
        let callbackReceived = CallbackFlag()
        let sessionID = UUID().uuidString.uppercased()
        let testPort: UInt16 = 38_080
        let occupiedListener = try NWListener(
            using: .tcp,
            on: NWEndpoint.Port(rawValue: testPort)!
        )
        let occupiedPort = try await start(occupiedListener)
        defer { occupiedListener.cancel() }

        let callbackPort = try await server.start(
            sessionID: sessionID,
            action: .enable,
            preferredPort: occupiedPort,
            isMirroring: { _ in false },
            onCallback: { _ in callbackReceived.markReceived() }
        )
        defer { server.stop() }
        precondition(callbackPort != occupiedPort, "Callback server did not fall back from the occupied port")

        let payload: [String: Any] = [
            "type": "ROKID_WIRELESS_ADB_STATUS",
            "version": 1,
            "action": "ENABLE",
            "sessionId": sessionID,
            "status": "READY",
            "device": [
                "serial": "1801082435000517",
                "ip": "10.91.11.238",
                "adbPort": 5555,
                "adbEnabled": true,
                "tcpPortOpen": true
            ],
            "errorCode": "",
            "message": "ADB TCP ready"
        ]
        var request = URLRequest(
            url: URL(string: "http://127.0.0.1:\(callbackPort)/rokid/wireless-adb/callback")!
        )
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        precondition(
            httpResponse?.statusCode == 200,
            "Unexpected HTTP status \(httpResponse?.statusCode ?? -1): \(String(data: data, encoding: .utf8) ?? "<non-UTF8>")"
        )
        precondition(object?["ok"] as? Bool == true)
        precondition(object?["alreadyMirroring"] as? Bool == false)
        precondition(callbackReceived.value)
    }

    private static func start(_ listener: NWListener) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: listener.port!.rawValue)
                case .failed(let error), .waiting(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: DispatchQueue(label: "CallbackServerTests.occupied-port"))
        }
    }
}

private final class CallbackFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var received = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return received
    }

    func markReceived() {
        lock.lock()
        received = true
        lock.unlock()
    }
}
