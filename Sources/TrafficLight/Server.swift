import Foundation
import Network

/// Минимальный localhost HTTP-сервер. Принимает POST /event?type=<Event>
/// с JSON-телом хука (session_id, cwd, ...). Без зависимостей — на Network.framework.
final class TrafficServer {
    private let listener: NWListener
    private let onEvent: (_ type: String, _ sessionID: String, _ cwd: String?) -> Void

    init?(port: UInt16, onEvent: @escaping (_ type: String, _ sessionID: String, _ cwd: String?) -> Void) {
        self.onEvent = onEvent
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port),
              let listener = try? NWListener(using: params, on: nwPort) else {
            return nil
        }
        self.listener = listener
    }

    func start() {
        listener.newConnectionHandler = { [weak self] conn in
            self?.receive(on: conn)
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    private func receive(on conn: NWConnection, buffer: Data = Data()) {
        conn.start(queue: .global(qos: .userInitiated))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var acc = buffer
            if let data { acc.append(data) }

            if let request = Self.parse(acc) {
                self.dispatch(request)
                self.respond(on: conn)
                return
            }
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            // ещё не получили полный запрос — дочитываем
            self.receive(on: conn, buffer: acc)
        }
    }

    private struct Request { let type: String; let body: Data }

    /// Разбираем HTTP: находим ?type=... в request line и тело по Content-Length.
    private static func parse(_ data: Data) -> Request? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data.subdata(in: data.startIndex..<headerEnd.lowerBound)
        guard let header = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = header.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        // GET/POST /event?type=Stop HTTP/1.1
        var type = "Unknown"
        if let qmark = requestLine.range(of: "?type=") {
            let tail = requestLine[qmark.upperBound...]
            type = String(tail.prefix { $0 != " " && $0 != "&" })
            type = type.removingPercentEncoding ?? type
        }

        var contentLength = 0
        for line in lines.dropFirst() {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                contentLength = Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        let body = data.subdata(in: headerEnd.upperBound..<data.endIndex)
        if body.count < contentLength { return nil } // тело ещё не догружено
        return Request(type: type, body: body)
    }

    private func dispatch(_ request: Request) {
        var sessionID = "default"
        var cwd: String? = nil
        if let obj = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] {
            if let sid = obj["session_id"] as? String, !sid.isEmpty { sessionID = sid }
            cwd = obj["cwd"] as? String
        }
        onEvent(request.type, sessionID, cwd)
    }

    private func respond(on conn: NWConnection) {
        let response = "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        conn.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }
}
