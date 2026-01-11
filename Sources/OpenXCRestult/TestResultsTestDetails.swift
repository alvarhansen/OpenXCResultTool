import Foundation

struct TestResultsTestDetails: Encodable {
    let arguments: [TestArgument]?
    let devices: [SummaryDevice]
    let duration: String
    let durationInSeconds: Double
    let hasMediaAttachments: Bool
    let hasPerformanceMetrics: Bool
    let startTime: Double?
    let testDescription: String
    let testIdentifier: String
    let testIdentifierURL: String
    let testName: String
    let testPlanConfigurations: [TestPlanConfiguration]
    let testResult: String
    let testRuns: [TestDetailNode]
}

struct TestArgument: Encodable {
    let value: String
}

struct TestDetailNode: Encodable {
    let children: [TestDetailNode]?
    let details: String?
    let duration: String?
    let durationInSeconds: Double?
    let name: String
    let nodeIdentifier: String?
    let nodeType: String
    let result: String?
}
