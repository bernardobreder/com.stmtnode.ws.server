import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(com_stmtnode_ws_serverTests.allTests),
    ]
}
#endif