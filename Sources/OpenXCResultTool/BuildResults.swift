import Foundation

struct BuildResults: Encodable {
    let analyzerWarningCount: Int
    let analyzerWarnings: [BuildIssue]
    let destination: BuildDestination?
    let endTime: Double
    let errorCount: Int
    let errors: [BuildIssue]
    let startTime: Double
    let status: String
    let warningCount: Int
    let warnings: [BuildIssue]
}

struct BuildIssue: Encodable {
    let issueType: String
    let message: String
}

struct BuildDestination: Encodable {
    let architecture: String
    let deviceId: String
    let deviceName: String
    let modelName: String
    let osBuildNumber: String
    let osVersion: String
    let platform: String
}
