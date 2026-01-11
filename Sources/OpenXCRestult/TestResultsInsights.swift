import Foundation

struct TestResultsInsights: Encodable {
    let commonFailureInsights: [CommonFailureInsight]
    let failureDistributionInsights: [FailureDistributionInsight]
    let longestTestRunsInsights: [LongestTestRunsInsight]
}

struct CommonFailureInsight: Encodable {}

struct FailureDistributionInsight: Encodable {}

struct LongestTestRunsInsight: Encodable {
    let associatedTestIdentifiers: [String]
    let deviceName: String
    let durationOfSlowTests: Double
    let impact: String
    let meanTime: String
    let osNameAndVersion: String
    let targetName: String
    let testPlanConfigurationName: String
    let title: String
}
