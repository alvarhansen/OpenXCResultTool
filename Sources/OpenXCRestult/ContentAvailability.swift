import Foundation

struct ContentAvailability: Encodable {
    let hasCoverage: Bool
    let hasDiagnostics: Bool
    let hasTestResults: Bool
    let logs: [String]
}
