import XCTest

final class InsightSampleAppUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Insight Sample"].exists)
    }

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    func testConditionalFailureExample() {
        if ProcessInfo.processInfo.environment["INSIGHT_FORCE_FAILURE"] == "1" {
            XCTFail("Forced UI failure for insights.")
        }
    }
}
