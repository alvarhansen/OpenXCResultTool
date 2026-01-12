import Foundation
import SQLite3

struct BuildResultsBuilder {
    private let context: XCResultContext
    private let store: XCResultFileBackedStore

    init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
        self.store = try XCResultFileBackedStore(xcresultPath: xcresultPath)
    }

    func buildResults() throws -> BuildResults {
        let issues = try loadIssues()
        let destination = try loadDestination()
        let startTime = toUnixTime(context.action.started)
        let endTime = toUnixTime(context.action.finished)
        let status = try loadStatus() ?? "notRequested"

        return BuildResults(
            analyzerWarningCount: issues.analyzerWarnings.count,
            analyzerWarnings: issues.analyzerWarnings,
            destination: destination,
            endTime: endTime,
            errorCount: issues.errors.count,
            errors: issues.errors,
            startTime: startTime,
            status: status,
            warningCount: issues.warnings.count,
            warnings: issues.warnings
        )
    }

    private func loadIssues() throws -> BuildIssueBuckets {
        let sql = """
        SELECT issueType, message, severity
        FROM BuildIssues
        WHERE action_fk = ?
        ORDER BY orderInAction;
        """
        let rows = try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(context.action.id))
        }) { statement in
            BuildIssueRow(
                issueType: SQLiteDatabase.string(statement, 0) ?? "",
                message: SQLiteDatabase.string(statement, 1) ?? "",
                severity: SQLiteDatabase.int(statement, 2) ?? 0
            )
        }

        var errors: [BuildIssue] = []
        var warnings: [BuildIssue] = []
        var analyzerWarnings: [BuildIssue] = []

        for row in rows {
            let issue = BuildIssue(issueType: row.issueType, message: row.message)
            if row.issueType.lowercased().contains("analyzer") {
                analyzerWarnings.append(issue)
            } else if row.severity == 1 {
                errors.append(issue)
            } else {
                warnings.append(issue)
            }
        }

        return BuildIssueBuckets(errors: errors, warnings: warnings, analyzerWarnings: analyzerWarnings)
    }

    private func loadDestination() throws -> BuildDestination? {
        guard let runDestination = try context.fetchRunDestination(runDestinationId: context.action.runDestinationId) else {
            return nil
        }
        guard let device = try context.fetchDevice(deviceId: runDestination.deviceId) else {
            throw SQLiteError("Missing device with rowid \(runDestination.deviceId).")
        }
        guard let platform = try context.fetchPlatform(platformId: device.platformId) else {
            throw SQLiteError("Missing platform with rowid \(device.platformId).")
        }
        let osBuildNumber = TestResultsSummaryBuilder.extractBuildNumber(device.operatingSystemVersionWithBuildNumber)
        return BuildDestination(
            architecture: runDestination.architecture,
            deviceId: device.identifier,
            deviceName: runDestination.name,
            modelName: device.modelName,
            osBuildNumber: osBuildNumber,
            osVersion: device.operatingSystemVersion,
            platform: platform.userDescription
        )
    }

    private func loadStatus() throws -> String? {
        let root = try store.loadObject(id: store.rootId)
        let actions = root.value(for: "actions")?.arrayValues ?? []
        guard let action = actions.first else { return nil }
        return action.value(for: "buildResult")?.value(for: "status")?.stringValue
    }

    private func toUnixTime(_ coreDataTime: Double) -> Double {
        let unixTime = coreDataTime + 978_307_200
        return (unixTime * 1000).rounded() / 1000
    }
}

private struct BuildIssueRow {
    let issueType: String
    let message: String
    let severity: Int
}

private struct BuildIssueBuckets {
    let errors: [BuildIssue]
    let warnings: [BuildIssue]
    let analyzerWarnings: [BuildIssue]
}
