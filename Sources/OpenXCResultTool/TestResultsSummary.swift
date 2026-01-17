import Foundation

struct TestResultsSummary: Encodable {
    let devicesAndConfigurations: [DevicesAndConfiguration]
    let environmentDescription: String
    let expectedFailures: Int
    let failedTests: Int
    let finishTime: Double
    let passedTests: Int
    let result: String
    let skippedTests: Int
    let startTime: Double
    let statistics: [SummaryStatistic]
    let testFailures: [TestFailure]
    let title: String
    let topInsights: [SummaryInsight]
    let totalTestCount: Int
}

struct DevicesAndConfiguration: Encodable {
    let device: SummaryDevice
    let expectedFailures: Int
    let failedTests: Int
    let passedTests: Int
    let skippedTests: Int
    let testPlanConfiguration: TestPlanConfiguration
}

struct SummaryDevice: Encodable {
    let architecture: String
    let deviceId: String
    let deviceName: String
    let modelName: String
    let osBuildNumber: String
    let osVersion: String
    let platform: String
}

struct TestPlanConfiguration: Encodable {
    let configurationId: String
    let configurationName: String
}

struct SummaryStatistic: Encodable {
    let subtitle: String
    let title: String
}

struct TestFailure: Encodable {
    let failureText: String
    let targetName: String
    let testIdentifier: Int
    let testIdentifierString: String
    let testIdentifierURL: String
    let testName: String
}

struct SummaryInsight: Encodable {
    let category: String
    let impact: String
    let text: String
}
