import Foundation

public struct TestResultsActivities: Encodable {
    public let testIdentifier: String
    public let testIdentifierURL: String
    public let testName: String
    public let testRuns: [TestRunActivities]
}

public struct TestRunActivities: Encodable {
    public let activities: [ActivityNode]
    public let arguments: [TestArgument]?
    public let device: SummaryDevice
    public let testPlanConfiguration: TestPlanConfiguration
}

public struct ActivityNode: Encodable {
    public let attachments: [ActivityAttachment]?
    public let childActivities: [ActivityNode]?
    public let isAssociatedWithFailure: Bool
    public let startTime: Double?
    public let title: String
}

public struct ActivityAttachment: Encodable {
    public let lifetime: String
    public let name: String
    public let payloadId: String
    public let timestamp: Double
    public let uuid: String
}
