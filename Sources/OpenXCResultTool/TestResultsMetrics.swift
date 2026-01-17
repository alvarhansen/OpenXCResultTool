import Foundation

public struct TestResultsMetricsDevice: Encodable {
    public let deviceId: String
    public let deviceName: String
}

public struct TestResultsMetricsRun: Encodable {
    public let device: TestResultsMetricsDevice
    public let metrics: [PerformanceMetric]
    public let testPlanConfiguration: TestPlanConfiguration
}

public struct TestResultsMetricsEntry: Encodable {
    public let testIdentifier: String
    public let testIdentifierURL: String
    public let testRuns: [TestResultsMetricsRun]
}

public struct PerformanceMetric: Encodable {
    public let baselineAverage: Double
    public let baselineName: String
    public let displayName: String
    public let identifier: String
    public let maxPercentRegression: Double
    public let maxPercentRelativeStandardDeviation: Double
    public let maxRegression: Double
    public let maxStandardDeviation: Double
    public let measurements: [Double]
    public let polarity: String
    public let unitOfMeasurement: String
}
