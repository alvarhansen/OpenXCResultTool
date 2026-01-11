import Foundation

struct TestResultsInsights: Encodable {
    let commonFailureInsights: [CommonFailureInsight]
    let failureDistributionInsights: [FailureDistributionInsight]
    let longestTestRunsInsights: [LongestTestRunsInsight]
}

struct CommonFailureInsight: Encodable {}

struct FailureDistributionInsight: Encodable {}

struct LongestTestRunsInsight: Encodable {}
