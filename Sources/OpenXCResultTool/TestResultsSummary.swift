import Foundation

public struct TestResultsSummary: Encodable {
    public let devicesAndConfigurations: [DevicesAndConfiguration]
    public let environmentDescription: String
    public let expectedFailures: Int
    public let failedTests: Int
    public let finishTime: Double
    public let passedTests: Int
    public let result: String
    public let skippedTests: Int
    public let startTime: Double
    public let statistics: [SummaryStatistic]
    public let testFailures: [TestFailure]
    public let title: String
    public let topInsights: [SummaryInsight]
    public let totalTestCount: Int
}

public struct DevicesAndConfiguration: Encodable {
    public let device: SummaryDevice
    public let expectedFailures: Int
    public let failedTests: Int
    public let passedTests: Int
    public let skippedTests: Int
    public let testPlanConfiguration: TestPlanConfiguration
}

public struct SummaryDevice: Encodable {
    public let architecture: String
    public let deviceId: String
    public let deviceName: String
    public let modelName: String
    public let osBuildNumber: String
    public let osVersion: String
    public let platform: String
}

public struct TestPlanConfiguration: Encodable {
    public let configurationId: String
    public let configurationName: String
}

public struct SummaryStatistic: Encodable {
    public let subtitle: String
    public let title: String
}

public struct TestFailure: Encodable {
    public let failureText: String
    public let targetName: String
    public let testIdentifier: Int
    public let testIdentifierString: String
    public let testIdentifierURL: String
    public let testName: String
}

public struct SummaryInsight: Encodable {
    public let category: String
    public let impact: String
    public let text: String
}
