import XCTest
@testable import OpenXCRestult

final class OpenXCRestultTests: XCTestCase {
    func testGreeting() {
        XCTAssertEqual(OpenXCRestult.greeting(), "Hello, world!")
    }
}
