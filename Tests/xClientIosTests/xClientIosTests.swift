import XCTest
@testable import xClientIos

final class xClientIosTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(xClientIos().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
