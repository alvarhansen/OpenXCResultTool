import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

public struct TestResultsInsightsBuilder {
    private let context: XCResultContext

    public init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    public func insights() throws -> TestResultsInsights {
        let longest = try longestTestRunsInsights()
        return TestResultsInsights(
            commonFailureInsights: [],
            failureDistributionInsights: [],
            longestTestRunsInsights: longest
        )
    }

    private func longestTestRunsInsights() throws -> [LongestTestRunsInsight] {
        var insights: [LongestTestRunsInsight] = []

        var deviceInfoByAction: [Int: (deviceName: String, osNameAndVersion: String)] = [:]
        for action in context.actions {
            let destination = try context.fetchRunDestination(runDestinationId: action.runDestinationId)
            let device = try destination.flatMap { try context.fetchDevice(deviceId: $0.deviceId) }
            let platform = try device.flatMap { try context.fetchPlatform(platformId: $0.platformId) }

            let deviceName = destination?.name ?? ""
            let osNameAndVersion = [
                platform?.userDescription,
                device?.operatingSystemVersion
            ]
            .compactMap { $0 }
            .joined(separator: " ")

            deviceInfoByAction[action.id] = (deviceName, osNameAndVersion)
        }

        for planRun in context.testPlanRuns {
            let deviceInfo = deviceInfoByAction[planRun.actionId] ?? ("", "")
            let configuration = try context.fetchConfiguration(configurationId: planRun.configurationId)
            let testableRuns = try fetchTestableRuns(for: planRun.id)

            for testableRun in testableRuns {
                guard let testable = try fetchTestable(testableId: testableRun.testableId) else { continue }
                guard let stats = try fetchRunStats(testableRunId: testableRun.id) else { continue }
                guard stats.count > 0, stats.totalDuration > 0 else { continue }

                let threshold = stats.mean + (3 * stats.standardDeviation)
                let slowRuns = try fetchSlowRuns(testableRunId: testableRun.id, threshold: threshold)
                if slowRuns.isEmpty { continue }

                let slowDuration = slowRuns.reduce(0) { $0 + $1.duration }
                let impactPercent = Int((slowDuration / stats.totalDuration) * 100)

                let meanTime = "\(formatMean(stats.mean))s across \(stats.count) test runs"
                let title = "\(slowRuns.count) longest test runs with outlier durations exceeding \(formatThreshold(threshold))s (three standard deviations)"

                let identifiers = slowRuns.map { $0.identifierURL }.sorted()

                insights.append(
                    LongestTestRunsInsight(
                        associatedTestIdentifiers: identifiers,
                        deviceName: deviceInfo.deviceName,
                        durationOfSlowTests: slowDuration,
                        impact: "(\(impactPercent)%)",
                        meanTime: meanTime,
                        osNameAndVersion: deviceInfo.osNameAndVersion,
                        targetName: testable.name,
                        testPlanConfigurationName: configuration.name,
                        title: title
                    )
                )
            }
        }

        return insights
    }

    private func fetchTestableRuns(for testPlanRunId: Int) throws -> [TestableRunRow] {
        let sql = """
        SELECT rowid, testable_fk
        FROM TestableRuns
        WHERE testPlanRun_fk = ?
        ORDER BY orderInTestPlanRun;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testPlanRunId))
        }) { statement in
            TestableRunRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                testableId: SQLiteDatabase.int(statement, 1) ?? 0
            )
        }
    }

    private func fetchTestable(testableId: Int) throws -> TestableRow? {
        let sql = "SELECT rowid, name FROM Testables WHERE rowid = ?;"
        return try context.database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testableId))
        }) { statement in
            TestableRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? ""
            )
        }
    }

    private func fetchRunStats(testableRunId: Int) throws -> RunStats? {
        let sql = """
        SELECT COUNT(*),
               avg(TestCaseRuns.duration),
               avg(TestCaseRuns.duration * TestCaseRuns.duration),
               sum(TestCaseRuns.duration)
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        WHERE TestSuiteRuns.testableRun_fk = ?;
        """
        return try context.database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testableRunId))
        }) { statement in
            let count = SQLiteDatabase.int(statement, 0) ?? 0
            let mean = SQLiteDatabase.double(statement, 1) ?? 0
            let averageSquares = SQLiteDatabase.double(statement, 2) ?? 0
            let totalDuration = SQLiteDatabase.double(statement, 3) ?? 0

            let variance = max(0, averageSquares - (mean * mean))
            return RunStats(
                count: count,
                mean: mean,
                standardDeviation: sqrt(variance),
                totalDuration: totalDuration
            )
        }
    }

    private func fetchSlowRuns(testableRunId: Int, threshold: Double) throws -> [SlowRunRow] {
        let sql = """
        SELECT TestCases.identifierURL,
               TestCaseRuns.duration
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestCases ON TestCases.rowid = TestCaseRuns.testCase_fk
        WHERE TestSuiteRuns.testableRun_fk = ?
          AND TestCaseRuns.duration > ?;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testableRunId))
            sqlite3_bind_double(statement, 2, threshold)
        }) { statement in
            SlowRunRow(
                identifierURL: SQLiteDatabase.string(statement, 0) ?? "",
                duration: SQLiteDatabase.double(statement, 1) ?? 0
            )
        }
    }

    private func formatMean(_ mean: Double) -> String {
        let formatted = String(format: "%.1f", mean)
        return formatted.replacingOccurrences(of: ".", with: ",")
    }

    private func formatThreshold(_ threshold: Double) -> String {
        String(format: "%.2f", threshold)
    }
}

private struct TestableRunRow {
    let id: Int
    let testableId: Int
}

private struct TestableRow {
    let id: Int
    let name: String
}

private struct RunStats {
    let count: Int
    let mean: Double
    let standardDeviation: Double
    let totalDuration: Double
}

private struct SlowRunRow {
    let identifierURL: String
    let duration: Double
}
