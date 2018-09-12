
import Foundation
#if SWIFT_PACKAGE
import com_stmtnode_net
import com_stmtnode_secure
import com_stmtnode_string
import com_stmtnode_lock
#endif

public protocol WebSocketProtocol {
    
    func perform(request: String) throws -> String
    
}

open class WebSocketServer: NetworkThread {
    
    public let server: NetworkServer
    
    public let model: WebSocketProtocol
    
    public let queue: DispatchQueue
    
    public let lock = Lock()
    
    public var clients = [WebSocketClient]()
    
    fileprivate var clientSequence = 1
    
    public init?(port: Int, model: WebSocketProtocol, queue: DispatchQueue) {
        guard let server = NetworkServer(port: port) else { return nil }
        self.server = server
        self.model = model
        self.queue = queue
    }
    
    open override func loop() {
        if let client = self.client() {
            lock.lock { clients.append(client) }
            queue.async {
                defer { client.stop() }
                while !client.closed {
                    autoreleasepool(invoking: { () -> () in
                        if let message = client.read() {
                            guard let response = try? self.model.perform(request: message) else { return client.stop() }
                            guard client.write(response) else { return client.stop() }
                        } else {
                            Thread.sleep(forTimeInterval: 0.1)
                        }
                    })
                }
                self.lock.lock {
                    if let index = self.clients.index(where: {$0 === client}) {
                        self.clients.remove(at: index)
                    }
                }
            }
        }
    }
    
    public func closeAll() {
        lock.lock {
            for client in clients {
                let _ = client.stop()
            }
        }
    }
    
    open override func closeResource() {
        server.stop()
    }
    
    fileprivate func client() -> WebSocketClient? {
        let id = clientSequence
        self.clientSequence += 1
        guard let client = server.client() else { return nil }
        guard let request = client.readWsRequest() else { return nil }
        let SecWebSocketKey1 = "Sec-WebSocket-Key1".lowercased()
        let SecWebSocketKey2 = "Sec-WebSocket-Key2".lowercased()
        let SecWebSocketKey = "Sec-WebSocket-Key".lowercased()
        if let key1 = request[SecWebSocketKey1], let key2 = request[SecWebSocketKey2] {
            guard let origin = request["origin"] else { return nil }
            guard let host = request["host"] else { return nil }
            let keys = [key1, key2]
            var numbers = ["", ""]
            var spaces = [0, 0]
            let digits = NSCharacterSet.decimalDigits
            for i in 0 ..< keys.count {
                let key = keys[i]
                var number = numbers[i]
                key.unicodeScalars.forEach({ c in
                    if digits.hasMember(inPlane: UInt8(c.value)) {
                        number += String(c)
                    } else if c == " ".unicodeScalars.first! {
                        spaces[i] += 1
                    }
                })
                numbers[i] = number
            }
            var bytes = [UInt8]()
            for i in 0 ..< keys.count {
                guard var value = Int(numbers[i]) else { return nil }
                value /= spaces[i]
                bytes.append(UInt8((value >> 24) & 0xFF))
                bytes.append(UInt8((value >> 16) & 0xFF))
                bytes.append(UInt8((value >> 08) & 0xFF))
                bytes.append(UInt8((value >> 00) & 0xFF))
            }
            for _ in 0 ..< 8 {
                guard let byte = client.read() else { return nil }
                bytes.append(byte)
            }
            guard let string = String(bytes: bytes, encoding: String.Encoding.ascii) else { return nil }
            var response = ""
            response.append("HTTP/1.1 101 WebSocket Protocol Handshake\r\n")
            response.append("Upgrade: Websocket\r\n")
            response.append("Connection: Upgrade\r\n")
            response.append("Sec-WebSocket-Origin: \(origin)\r\n")
            response.append("Sec-WebSocket-Location: ws://\(host)\r\n")
            response.append("\r\n")
            response.append(string.md5())
            guard let data = response.data(using: .utf8) else { return nil }
            guard client.write(data: data) else { return nil }
            return WebSocketClient(id: id, client: client)
        } else if let key = request[SecWebSocketKey] {
            let bytes = [UInt8]((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8)
            let accept = Data(bytes: bytes.sha1()).base64EncodedString()
            
            var response = ""
            response.append("HTTP/1.1 101 Switching Protocols\r\n")
            response.append("Upgrade: Websocket\r\n")
            response.append("Connection: Upgrade\r\n")
            response.append("Sec-WebSocket-Accept: \(accept)\r\n")
            response.append("\r\n")
            guard let data = response.data(using: .utf8) else { return nil }
            guard client.write(data: data) else { return nil }
            return WebSocketClient(id: id, client: client)
        } else { return nil }
    }
    
}

extension NetworkClient {
    
    public func readWsRequest() -> [String: String]? {
        let sb = StringBuilder()
        while true {
            guard let byte = read() else { return nil }
            sb.append(String(Character(UnicodeScalar(byte))))
            if sb.string.hasSuffix("\r\n\r\n") { break }
        }
        var headers = [String: String]()
        for line in sb.string.trimmingCharacters(in: .newlines).split(separator: "\r\n").dropFirst() {
            guard let index = line.index(of: ":") else { return nil }
            let key = line[..<index].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(index, offsetBy: 2)...].trimmingCharacters(in: .whitespaces)
            headers[key.lowercased()] = value
        }
        return headers
    }
    
}
