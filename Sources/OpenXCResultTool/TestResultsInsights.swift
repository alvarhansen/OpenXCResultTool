import Foundation

public struct TestResultsInsights: Encodable {
    public let commonFailureInsights: [CommonFailureInsight]
    public let failureDistributionInsights: [FailureDistributionInsight]
    public let longestTestRunsInsights: [LongestTestRunsInsight]
}

public struct CommonFailureInsight: Encodable {}

public struct FailureDistributionInsight: Encodable {}

public struct LongestTestRunsInsight: Encodable {
    public let associatedTestIdentifiers: [String]
    public let deviceName: String
    public let durationOfSlowTests: Double
    public let impact: String
    public let meanTime: String
    public let osNameAndVersion: String
    public let targetName: String
    public let testPlanConfigurationName: String
    public let title: String
}
