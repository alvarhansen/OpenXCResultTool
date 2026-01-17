import Foundation

public struct TestResultsTestDetails: Encodable {
    public let arguments: [TestArgument]?
    public let devices: [SummaryDevice]
    public let duration: String
    public let durationInSeconds: Double
    public let hasMediaAttachments: Bool
    public let hasPerformanceMetrics: Bool
    public let startTime: Double?
    public let testDescription: String
    public let testIdentifier: String
    public let testIdentifierURL: String
    public let testName: String
    public let testPlanConfigurations: [TestPlanConfiguration]
    public let testResult: String
    public let testRuns: [TestDetailNode]
}

public struct TestArgument: Encodable {
    public let value: String
}

public struct TestDetailNode: Encodable {
    public let children: [TestDetailNode]?
    public let details: String?
    public let duration: String?
    public let durationInSeconds: Double?
    public let name: String
    public let nodeIdentifier: String?
    public let nodeType: String
    public let result: String?
}
