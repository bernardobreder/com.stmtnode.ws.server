import XCTest
@testable import com_stmtnode_ws_server

final class com_stmtnode_ws_serverTests: XCTestCase, WebSocketProtocol {
    
    func perform(request: String) throws -> String {
        return "resp: \(request)"
    }
    
    
    func testExample() throws {
        guard let server = WebSocketServer(port: 9090, model: self) else { throw NSError() }
        server.start()
//        Thread.sleep(forTimeInterval: 1000000)
        server.stop()
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
