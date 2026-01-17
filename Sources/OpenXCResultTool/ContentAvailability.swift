import Foundation

public struct ContentAvailability: Encodable {
    public let hasCoverage: Bool
    public let hasDiagnostics: Bool
    public let hasTestResults: Bool
    public let logs: [String]
}
