import Foundation

public struct TestResultsTests: Encodable {
    public let devices: [SummaryDevice]
    public let testNodes: [TestNode]
    public let testPlanConfigurations: [TestPlanConfiguration]
}

public struct TestNode: Encodable {
    public let children: [TestNode]?
    public let details: String?
    public let duration: String?
    public let durationInSeconds: Double?
    public let name: String
    public let nodeIdentifier: String?
    public let nodeIdentifierURL: String?
    public let nodeType: String
    public let result: String?
}
