import Foundation

public struct BuildResults: Encodable {
    public let analyzerWarningCount: Int
    public let analyzerWarnings: [BuildIssue]
    public let destination: BuildDestination?
    public let endTime: Double
    public let errorCount: Int
    public let errors: [BuildIssue]
    public let startTime: Double
    public let status: String
    public let warningCount: Int
    public let warnings: [BuildIssue]
}

public struct BuildIssue: Encodable {
    public let issueType: String
    public let message: String
}

public struct BuildDestination: Encodable {
    public let architecture: String
    public let deviceId: String
    public let deviceName: String
    public let modelName: String
    public let osBuildNumber: String
    public let osVersion: String
    public let platform: String
}
