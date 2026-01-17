import Foundation

struct TestResultsMetricsDevice: Encodable {
    let deviceId: String
    let deviceName: String
}

struct TestResultsMetricsRun: Encodable {
    let device: TestResultsMetricsDevice
    let metrics: [PerformanceMetric]
    let testPlanConfiguration: TestPlanConfiguration
}

struct TestResultsMetricsEntry: Encodable {
    let testIdentifier: String
    let testIdentifierURL: String
    let testRuns: [TestResultsMetricsRun]
}

struct PerformanceMetric: Encodable {
    let baselineAverage: Double
    let baselineName: String
    let displayName: String
    let identifier: String
    let maxPercentRegression: Double
    let maxPercentRelativeStandardDeviation: Double
    let maxRegression: Double
    let maxStandardDeviation: Double
    let measurements: [Double]
    let polarity: String
    let unitOfMeasurement: String
}
