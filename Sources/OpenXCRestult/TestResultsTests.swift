import Foundation

struct TestResultsTests: Encodable {
    let devices: [SummaryDevice]
    let testNodes: [TestNode]
    let testPlanConfigurations: [TestPlanConfiguration]
}

struct TestNode: Encodable {
    let children: [TestNode]?
    let duration: String?
    let durationInSeconds: Double?
    let name: String
    let nodeIdentifier: String?
    let nodeIdentifierURL: String?
    let nodeType: String
    let result: String?
}
