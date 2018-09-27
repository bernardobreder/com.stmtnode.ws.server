
import Foundation
#if SWIFT_PACKAGE
import com_stmtnode_net
import com_stmtnode_secure
import com_stmtnode_string
import com_stmtnode_lock
#endif

//public protocol WebSocketProtocol {
//    
//    func perform(request: String) throws -> String
//    
//}

public class WebSocketServerNIO: NetworkServerUnblockProtocol {
 
    let pm: StmtPackageManager
    
    var queue: DispatchQueue
    
    let lastUpdatedDateDefault = Date()
    
    let dateFormatter = DateFormatter()
    
    public init(pm: StmtPackageManager, queue: DispatchQueue) {
        self.pm = pm
        self.queue = queue
        self.dateFormatter.dateFormat = "EEE, dd LLL yyyy kk:mm:ss zzz"
    }
    
    public func consume(server: NetworkServerUnblock, client: Int, bytes: [UInt8]) -> Int {
        let stream = ByteStream(chars: bytes)
        guard let headers = readWsRequest(stream: stream) else { return 0 }
        guard let data = handshake(stream: stream, request: headers) else { return 0 }
        server.send(id: client, data: data)
        return stream.index
    }
    
    public func readWsRequest(stream: ByteStream) -> [String: String]? {
        guard let _ = stream.readUntilEol() else { return nil }
        stream.next(2)
        var headers = [String: String]()
        while let look = stream.look(), look >= 32 {
            guard let key = stream.readId()?.lowercased() else { return nil }
            stream.skipWhitespace()
            stream.next()
            stream.skipWhitespace()
            guard let value = stream.readUntilEol() else { return nil }
            headers[key] = value
            stream.next(2)
        }
        stream.next(2)
        return headers
    }
    
    fileprivate func handshake(stream: ByteStream, request: [String: String]) -> Data? {
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
            guard let mask = stream.subarray(count: 8) else { return nil }
            bytes.append(contentsOf: mask)
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
            return data
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
            return data
        } else { return nil }
    }
    
}

//open class WebSocketServer: NetworkThread {
//
//    public let server: NetworkServer
//
//    public let model: WebSocketProtocol
//
//    public let lock = Lock()
//
//    public var clients = [WebSocketClient]()
//
//    fileprivate var clientSequence = 1
//
//    public init?(port: Int, model: WebSocketProtocol) {
//        guard let server = NetworkServer(port: port) else { return nil }
//        self.server = server
//        self.model = model
//        super.init(name: "WebSocket:\(port)")
//    }
//
//    open override func loop() {
//        if let client = self.client() {
//            lock.lock { clients.append(client) }
//            queue.async {
//                defer { client.stop() }
//                var counter = 10.0
//                while !client.closed {
//                    if let message = client.read() {
//                        NetworkThread.autorelease {
//                            guard let response = try? self.model.perform(request: message) else { return client.stop() }
//                            guard client.write(response) else { return client.stop() }
//                        }
//                        counter = 10.0
//                    }
//                    Thread.sleep(forTimeInterval: 0.1)
//                    counter -= 0.1
//                    if counter <= 0 {
//                        client.stop()
//                    }
//                }
//                self.lock.lock {
//                    if let index = self.clients.index(where: {$0 === client}) {
//                        self.clients.remove(at: index)
//                    }
//                }
//            }
//        }
//    }
//
//    public func closeAll() {
//        lock.lock {
//            for client in clients {
//                let _ = client.stop()
//            }
//        }
//    }
//
//    open override func closeResource() {
//        server.stop()
//    }
//
//    fileprivate func client() -> WebSocketClient? {
//        let id = clientSequence
//        self.clientSequence += 1
//        guard let client = server.client() else { return nil }
//        guard let request = client.readWsRequest() else { return nil }
//        let SecWebSocketKey1 = "Sec-WebSocket-Key1".lowercased()
//        let SecWebSocketKey2 = "Sec-WebSocket-Key2".lowercased()
//        let SecWebSocketKey = "Sec-WebSocket-Key".lowercased()
//        if let key1 = request[SecWebSocketKey1], let key2 = request[SecWebSocketKey2] {
//            guard let origin = request["origin"] else { return nil }
//            guard let host = request["host"] else { return nil }
//            let keys = [key1, key2]
//            var numbers = ["", ""]
//            var spaces = [0, 0]
//            let digits = NSCharacterSet.decimalDigits
//            for i in 0 ..< keys.count {
//                let key = keys[i]
//                var number = numbers[i]
//                key.unicodeScalars.forEach({ c in
//                    if digits.hasMember(inPlane: UInt8(c.value)) {
//                        number += String(c)
//                    } else if c == " ".unicodeScalars.first! {
//                        spaces[i] += 1
//                    }
//                })
//                numbers[i] = number
//            }
//            var bytes = [UInt8]()
//            for i in 0 ..< keys.count {
//                guard var value = Int(numbers[i]) else { return nil }
//                value /= spaces[i]
//                bytes.append(UInt8((value >> 24) & 0xFF))
//                bytes.append(UInt8((value >> 16) & 0xFF))
//                bytes.append(UInt8((value >> 08) & 0xFF))
//                bytes.append(UInt8((value >> 00) & 0xFF))
//            }
//            for _ in 0 ..< 8 {
//                guard let byte = client.read() else { return nil }
//                bytes.append(byte)
//            }
//            guard let string = String(bytes: bytes, encoding: String.Encoding.ascii) else { return nil }
//            var response = ""
//            response.append("HTTP/1.1 101 WebSocket Protocol Handshake\r\n")
//            response.append("Upgrade: Websocket\r\n")
//            response.append("Connection: Upgrade\r\n")
//            response.append("Sec-WebSocket-Origin: \(origin)\r\n")
//            response.append("Sec-WebSocket-Location: ws://\(host)\r\n")
//            response.append("\r\n")
//            response.append(string.md5())
//            guard let data = response.data(using: .utf8) else { return nil }
//            guard client.write(data: data) else { return nil }
//            return WebSocketClient(id: id, client: client)
//        } else if let key = request[SecWebSocketKey] {
//            let bytes = [UInt8]((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8)
//            let accept = Data(bytes: bytes.sha1()).base64EncodedString()
//
//            var response = ""
//            response.append("HTTP/1.1 101 Switching Protocols\r\n")
//            response.append("Upgrade: Websocket\r\n")
//            response.append("Connection: Upgrade\r\n")
//            response.append("Sec-WebSocket-Accept: \(accept)\r\n")
//            response.append("\r\n")
//            guard let data = response.data(using: .utf8) else { return nil }
//            guard client.write(data: data) else { return nil }
//            return WebSocketClient(id: id, client: client)
//        } else { return nil }
//    }
//
//}
//
//extension NetworkClient {
//
//    public func readWsRequest() -> [String: String]? {
//        let code = Code()
//        while true {
//            guard let byte = read() else { return nil }
//            code.append(String(Character(UnicodeScalar(byte))))
//            if code.string.hasSuffix("\r\n\r\n") { break }
//        }
//        var headers = [String: String]()
//        for line in code.string.trimmingCharacters(in: .newlines).split(separator: "\r\n").dropFirst() {
//            guard let index = line.index(of: ":") else { return nil }
//            let key = line[..<index].trimmingCharacters(in: .whitespaces)
//            let value = line[line.index(index, offsetBy: 2)...].trimmingCharacters(in: .whitespaces)
//            headers[key.lowercased()] = value
//        }
//        return headers
//    }
//
//}
