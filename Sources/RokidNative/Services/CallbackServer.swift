import Foundation
import Network
import OSLog

final class CallbackServer {
    private let queue = DispatchQueue(label: "com.rokid.wireless-projection.native.v2.callback")
    private let logger = Logger(
        subsystem: "com.rokid.wireless-projection.native.v2",
        category: "CallbackServer"
    )
    private var listener: NWListener?
    private var sessionID = ""
    private var action: QRCastAction = .enable
    private var onCallback: ((WirelessAdbCallback) -> Void)?
    private var isMirroring: ((String) -> Bool)?

    @discardableResult
    func start(
        sessionID: String,
        action: QRCastAction,
        preferredPort: UInt16 = QRCodeService.defaultCallbackPort,
        isMirroring: @escaping (String) -> Bool,
        onCallback: @escaping (WirelessAdbCallback) -> Void
    ) async throws -> UInt16 {
        stop()
        self.sessionID = sessionID
        self.action = action
        self.onCallback = onCallback
        self.isMirroring = isMirroring

        do {
            return try await startListener(on: preferredPort)
        } catch {
            logger.warning(
                "Port \(preferredPort) is unavailable; selecting an open callback port: \(error.localizedDescription, privacy: .public)"
            )
            var lastError = error
            for fallbackPort in fallbackPorts(after: preferredPort) {
                do {
                    return try await startListener(on: fallbackPort)
                } catch {
                    lastError = error
                }
            }
            throw lastError
        }
    }

    private func startListener(on requestedPort: UInt16) async throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(
            using: parameters,
            on: NWEndpoint.Port(rawValue: requestedPort)!
        )
        self.listener = listener

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UInt16, Error>) in
            let gate = ContinuationGate()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready where gate.claim():
                    let boundPort = listener.port?.rawValue ?? requestedPort
                    self.logger.info("Callback listener ready on port \(boundPort)")
                    continuation.resume(returning: boundPort)
                case .waiting(let error) where gate.claim():
                    self.logger.error("Callback listener waiting: \(error.localizedDescription, privacy: .public)")
                    listener.cancel()
                    continuation.resume(throwing: error)
                case .failed(let error) where gate.claim():
                    self.logger.error("Callback listener failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.logger.info("Incoming callback connection received")
                connection.start(queue: self.queue)
                self.receive(connection: connection, data: Data())
            }
            listener.start(queue: queue)
        }
    }

    private func fallbackPorts(after preferredPort: UInt16) -> [UInt16] {
        let lowerBound = Int(preferredPort) + 1
        let upperBound = min(lowerBound + 199, Int(UInt16.max))
        guard lowerBound <= upperBound else {
            return Array(18_081...18_280).map(UInt16.init)
        }
        return (lowerBound...upperBound).map(UInt16.init)
    }

    func stop() {
        if listener != nil {
            logger.info("Callback listener stopped")
        }
        listener?.cancel()
        listener = nil
        onCallback = nil
        isMirroring = nil
    }

    private func receive(connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] chunk, _, complete, error in
            guard let self else { return }
            var accumulated = data
            if let chunk { accumulated.append(chunk) }
            if accumulated.count > 65_536 {
                self.respond(connection, status: 413, body: ["ok": false, "error": "Payload too large"])
                return
            }
            if self.requestIsComplete(accumulated) || complete {
                self.handle(connection: connection, data: accumulated)
            } else if error == nil {
                self.receive(connection: connection, data: accumulated)
            } else {
                connection.cancel()
            }
        }
    }

    private func requestIsComplete(_ data: Data) -> Bool {
        guard let request = requestParts(data) else { return false }
        if let length = contentLength(in: request.header) {
            return request.body.count >= length
        }
        if usesChunkedEncoding(request.header) {
            return decodeChunkedBody(request.body) != nil
        }
        return (try? JSONDecoder().decode(WirelessAdbCallback.self, from: request.body)) != nil
    }

    private func handle(connection: NWConnection, data: Data) {
        guard let request = requestParts(data) else {
            respond(connection, status: 400, body: ["ok": false, "error": "Invalid request"])
            return
        }
        let requestLine = request.header.split(separator: "\n").first.map(String.init) ?? ""
        guard requestLine.hasPrefix("POST \(QRCodeService.callbackPath) ") else {
            respond(connection, status: 404, body: ["ok": false, "error": "Not found"])
            return
        }
        let body: Data
        if usesChunkedEncoding(request.header) {
            guard let decoded = decodeChunkedBody(request.body) else {
                respond(connection, status: 400, body: ["ok": false, "error": "Invalid chunked body"])
                return
            }
            body = decoded
        } else if let length = contentLength(in: request.header) {
            guard request.body.count >= length else {
                respond(connection, status: 400, body: ["ok": false, "error": "Incomplete body"])
                return
            }
            body = request.body.prefix(length)
        } else {
            body = request.body
        }
        guard let callback = try? JSONDecoder().decode(WirelessAdbCallback.self, from: body) else {
            logger.error("Rejected callback with invalid JSON body (\(body.count) bytes)")
            respond(connection, status: 400, body: ["ok": false, "error": "Invalid JSON"])
            return
        }
        guard callback.sessionId == sessionID,
              callback.type == "ROKID_WIRELESS_ADB_STATUS",
              callback.version == 1,
              callback.action == action.rawValue else {
            respond(connection, status: 409, body: ["ok": false, "error": "Unknown session"])
            return
        }
        guard callback.status == "READY", callback.device?.tcpPortOpen == true else {
            respond(connection, status: 422, body: ["ok": false, "error": callback.message ?? "Device is not ready"])
            return
        }
        let serial = callback.device?.serial ?? ""
        let alreadyMirroring = isMirroring?(serial) ?? false
        respond(connection, status: 200, body: ["ok": true, "alreadyMirroring": alreadyMirroring])
        logger.info("Accepted callback for session \(callback.sessionId, privacy: .public)")
        onCallback?(callback)
    }

    private func requestParts(_ data: Data) -> (header: String, body: Data)? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator),
              let header = String(data: data[..<range.lowerBound], encoding: .utf8) else {
            return nil
        }
        return (header, Data(data[range.upperBound...]))
    }

    private func contentLength(in header: String) -> Int? {
        header.split(separator: "\n")
            .first { $0.lowercased().hasPrefix("content-length:") }?
            .split(separator: ":", maxSplits: 1)
            .last
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func usesChunkedEncoding(_ header: String) -> Bool {
        header.split(separator: "\n").contains {
            $0.lowercased().hasPrefix("transfer-encoding:") &&
                $0.lowercased().contains("chunked")
        }
    }

    private func decodeChunkedBody(_ data: Data) -> Data? {
        let separator = Data("\r\n".utf8)
        var cursor = data.startIndex
        var decoded = Data()

        while cursor < data.endIndex {
            guard let lineEnd = data[cursor...].range(of: separator),
                  let sizeLine = String(data: data[cursor..<lineEnd.lowerBound], encoding: .ascii),
                  let sizeText = sizeLine.split(separator: ";", maxSplits: 1).first,
                  let size = Int(sizeText.trimmingCharacters(in: .whitespaces), radix: 16) else {
                return nil
            }
            cursor = lineEnd.upperBound
            if size == 0 { return decoded }

            guard data.distance(from: cursor, to: data.endIndex) >= size + separator.count else {
                return nil
            }
            let chunkEnd = data.index(cursor, offsetBy: size)
            decoded.append(data[cursor..<chunkEnd])
            let terminatorEnd = data.index(chunkEnd, offsetBy: separator.count)
            guard data[chunkEnd..<terminatorEnd] == separator else { return nil }
            cursor = terminatorEnd
        }
        return nil
    }

    private func respond(_ connection: NWConnection, status: Int, body: [String: Any]) {
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data("{}".utf8)
        let reason = status == 200 ? "OK" : "Error"
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(data.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(data)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}

private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var available = true

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard available else { return false }
        available = false
        return true
    }
}
