import Foundation

struct TestResultsInsightsBuilder {
    init(xcresultPath: String) throws {
        _ = xcresultPath
    }

    func insights() -> TestResultsInsights {
        TestResultsInsights(
            commonFailureInsights: [],
            failureDistributionInsights: [],
            longestTestRunsInsights: []
        )
    }
}
