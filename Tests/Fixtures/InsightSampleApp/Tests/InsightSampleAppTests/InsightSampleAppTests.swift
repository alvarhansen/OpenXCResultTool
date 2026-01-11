import XCTest
@testable import InsightSampleApp

final class InsightSampleAppTests: XCTestCase {
    func testMathExample() {
        XCTAssertEqual(1 + 1, 2)
    }

    func testExpectedFailureExample() {
        XCTExpectFailure("Working on a fix for this problem.") {
            XCTAssertEqual("one", "two")
        }
    }

    func testSkippedExample() throws {
        throw XCTSkip("Skipping for fixture generation.")
    }

    func testPerformanceExample() {
        measure {
            _ = (0..<1_000).reduce(0, +)
        }
    }

    func testConditionalFailureExample() {
        if ProcessInfo.processInfo.environment["INSIGHT_FORCE_FAILURE"] == "1" {
            XCTFail("Forced failure for insights.")
        } else {
            XCTAssertTrue(true)
        }
    }

    func testSecondaryConditionalFailureExample() {
        if ProcessInfo.processInfo.environment["INSIGHT_FORCE_FAILURE"] == "1" {
            XCTFail("Second forced failure for insights.")
        } else {
            XCTAssertTrue(true)
        }
    }
}
