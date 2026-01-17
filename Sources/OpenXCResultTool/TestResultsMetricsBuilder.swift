import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public struct TestResultsMetricsBuilder {
    private let context: XCResultContext

    public init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    public func metrics(testId: String?) throws -> [TestResultsMetricsEntry] {
        let testCases = try fetchTestCases(testId: testId)
        let planRuns = context.testPlanRuns
        let devicesByAction = try loadDevicesByAction()

        var entries: [TestResultsMetricsEntry] = []
        for testCase in testCases {
            let runs = try fetchTestCaseRuns(testCaseId: testCase.id)
            let testRuns = try runs.map { run in
                guard let planRun = planRuns.first(where: { $0.id == run.testPlanRunId }) else {
                    throw SQLiteError("Missing test plan run with rowid \(run.testPlanRunId).")
                }
                let configuration = try context.fetchConfiguration(configurationId: planRun.configurationId)
                let device = devicesByAction[planRun.actionId] ?? TestResultsMetricsDevice(deviceId: "", deviceName: "")
                let metrics = try fetchMetrics(runId: run.id)
                return TestResultsMetricsRun(
                    device: device,
                    metrics: metrics,
                    testPlanConfiguration: TestPlanConfiguration(
                        configurationId: String(configuration.id),
                        configurationName: configuration.name
                    )
                )
            }
            entries.append(
                TestResultsMetricsEntry(
                    testIdentifier: testCase.identifier,
                    testIdentifierURL: testCase.identifierURL,
                    testRuns: testRuns
                )
            )
        }

        return entries.sorted { $0.testIdentifier < $1.testIdentifier }
    }

    private func loadDevicesByAction() throws -> [Int: TestResultsMetricsDevice] {
        var devices: [Int: TestResultsMetricsDevice] = [:]
        for action in context.actions {
            guard let runDestination = try context.fetchRunDestination(runDestinationId: action.runDestinationId) else {
                continue
            }
            guard let device = try context.fetchDevice(deviceId: runDestination.deviceId) else {
                throw SQLiteError("Missing device with rowid \(runDestination.deviceId).")
            }
            devices[action.id] = TestResultsMetricsDevice(
                deviceId: device.identifier,
                deviceName: runDestination.name
            )
        }
        return devices
    }

    private func fetchTestCases(testId: String?) throws -> [TestCaseRow] {
        let sql: String
        if testId == nil {
            sql = """
            SELECT DISTINCT TestCases.rowid, TestCases.identifier, TestCases.identifierURL
            FROM TestCases
            JOIN TestCaseRuns ON TestCaseRuns.testCase_fk = TestCases.rowid
            JOIN PerformanceMetrics ON PerformanceMetrics.testCaseRun_fk = TestCaseRuns.rowid
            ORDER BY TestCases.identifier;
            """
        } else {
            sql = """
            SELECT DISTINCT TestCases.rowid, TestCases.identifier, TestCases.identifierURL
            FROM TestCases
            JOIN TestCaseRuns ON TestCaseRuns.testCase_fk = TestCases.rowid
            JOIN PerformanceMetrics ON PerformanceMetrics.testCaseRun_fk = TestCaseRuns.rowid
            WHERE TestCases.identifier = ? OR TestCases.identifierURL = ?
            ORDER BY TestCases.identifier;
            """
        }

        return try context.database.query(sql, binder: { statement in
            if let testId {
                sqlite3_bind_text(statement, 1, testId, -1, sqliteTransient)
                sqlite3_bind_text(statement, 2, testId, -1, sqliteTransient)
            }
        }) { statement in
            TestCaseRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                identifier: SQLiteDatabase.string(statement, 1) ?? "",
                identifierURL: SQLiteDatabase.string(statement, 2) ?? ""
            )
        }
    }

    private func fetchTestCaseRuns(testCaseId: Int) throws -> [TestCaseRunRow] {
        let planRunIds = context.testPlanRuns.map(\.id)
        guard !planRunIds.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: planRunIds.count).joined(separator: ",")
        let sql = """
        SELECT TestCaseRuns.rowid,
               TestableRuns.testPlanRun_fk
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestableRuns ON TestableRuns.rowid = TestSuiteRuns.testableRun_fk
        WHERE TestCaseRuns.testCase_fk = ?
          AND TestableRuns.testPlanRun_fk IN (\(placeholders))
          AND TestCaseRuns.rowid IN (SELECT DISTINCT testCaseRun_fk FROM PerformanceMetrics)
        ORDER BY TestCaseRuns.orderInTestSuiteRun;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testCaseId))
            for (index, id) in planRunIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 2), Int32(id))
            }
        }) { statement in
            TestCaseRunRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                testPlanRunId: SQLiteDatabase.int(statement, 1) ?? 0
            )
        }
    }

    private func fetchMetrics(runId: Int) throws -> [PerformanceMetric] {
        let sql = """
        SELECT unitOfMeasurement,
               maxPercentRegression,
               maxRegression,
               displayName,
               baselineName,
               maxStandardDeviation,
               maxPercentRelativeStandardDeviation,
               measurements,
               orderInTestCase,
               identifier,
               polarity,
               baselineAverage
        FROM PerformanceMetrics
        WHERE testCaseRun_fk = ?
        ORDER BY orderInTestCase;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(runId))
        }) { statement in
            let measurements = SQLiteDatabase.string(statement, 7) ?? ""
            return PerformanceMetric(
                baselineAverage: SQLiteDatabase.double(statement, 11) ?? 0,
                baselineName: SQLiteDatabase.string(statement, 4) ?? "",
                displayName: SQLiteDatabase.string(statement, 3) ?? "",
                identifier: SQLiteDatabase.string(statement, 9) ?? "",
                maxPercentRegression: SQLiteDatabase.double(statement, 1) ?? 0,
                maxPercentRelativeStandardDeviation: SQLiteDatabase.double(statement, 6) ?? 0,
                maxRegression: SQLiteDatabase.double(statement, 2) ?? 0,
                maxStandardDeviation: SQLiteDatabase.double(statement, 5) ?? 0,
                measurements: parseMeasurements(measurements),
                polarity: SQLiteDatabase.string(statement, 10) ?? "",
                unitOfMeasurement: SQLiteDatabase.string(statement, 0) ?? ""
            )
        }
    }

    private func parseMeasurements(_ raw: String) -> [Double] {
        raw.split(separator: ",").compactMap { Double($0) }
    }
}

private struct TestCaseRow {
    let id: Int
    let identifier: String
    let identifierURL: String
}

private struct TestCaseRunRow {
    let id: Int
    let testPlanRunId: Int
}
