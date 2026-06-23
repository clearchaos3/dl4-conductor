import Foundation
import Network

/// A tiny dependency-free HTTP server (Network.framework) that serves the looper remote
/// page and routes button presses to a handler. LAN-only, no auth — fine for a home
/// Wi-Fi network. Add a shared-secret check later if you want to expose it more widely.
final class WebServer {
    private let listener: NWListener
    private let onCommand: (String) -> Bool
    private let html: String

    init(port: UInt16, html: String, onCommand: @escaping (String) -> Bool) throws {
        self.onCommand = onCommand
        self.html = html
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        listener.start(queue: .main)
    }

    func stop() { listener.cancel() }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .main)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                conn.cancel(); return
            }
            let response = self.route(request)
            conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
        }
    }

    private func route(_ request: String) -> Data {
        // First request line: "GET /path?query HTTP/1.1"
        let firstLine = request.split(whereSeparator: { $0 == "\r" || $0 == "\n" }).first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ")
        let target = parts.count > 1 ? String(parts[1]) : "/"

        if target == "/" || target.hasPrefix("/index") {
            return httpResponse("200 OK", "text/html; charset=utf-8", Data(html.utf8))
        }
        if target.hasPrefix("/cmd") {
            let action = queryValue("a", in: target) ?? ""
            let ok = onCommand(action)
            let body = Data(#"{"ok":\#(ok),"action":"\#(action)"}"#.utf8)
            return httpResponse(ok ? "200 OK" : "400 Bad Request", "application/json", body)
        }
        return httpResponse("404 Not Found", "text/plain", Data("not found".utf8))
    }

    private func queryValue(_ key: String, in target: String) -> String? {
        guard let query = target.split(separator: "?").dropFirst().first else { return nil }
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.first.map(String.init) == key {
                return kv.count > 1 ? String(kv[1]) : ""
            }
        }
        return nil
    }

    private func httpResponse(_ status: String, _ contentType: String, _ body: Data) -> Data {
        var header = "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Cache-Control: no-store\r\n"
        header += "Connection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
