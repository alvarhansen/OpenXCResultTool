import Foundation

struct TestResultsActivities: Encodable {
    let testIdentifier: String
    let testIdentifierURL: String
    let testName: String
    let testRuns: [TestRunActivities]
}

struct TestRunActivities: Encodable {
    let activities: [ActivityNode]
    let arguments: [TestArgument]?
    let device: SummaryDevice
    let testPlanConfiguration: TestPlanConfiguration
}

struct ActivityNode: Encodable {
    let attachments: [ActivityAttachment]?
    let childActivities: [ActivityNode]?
    let isAssociatedWithFailure: Bool
    let startTime: Double?
    let title: String
}

struct ActivityAttachment: Encodable {
    let lifetime: String
    let name: String
    let payloadId: String
    let timestamp: Double
    let uuid: String
}
