import Foundation
import SQLite3

struct TestResultsSummaryBuilder {
    private let database: SQLiteDatabase
    private let action: ActionRow
    private let testPlanRuns: [TestPlanRunRow]

    init(xcresultPath: String) throws {
        let databasePath = TestResultsSummaryBuilder.databasePath(for: xcresultPath)
        self.database = try SQLiteDatabase(path: databasePath)
        guard let action = try TestResultsSummaryBuilder.fetchAction(from: database) else {
            throw SQLiteError("No Actions rows found in \(databasePath).")
        }
        self.action = action
        self.testPlanRuns = try TestResultsSummaryBuilder.fetchTestPlanRuns(from: database, actionId: action.id)
    }

    func summary() throws -> TestResultsSummary {
        let totalTestCount = try countTotalTests()
        let summaryCounts = try resultCountsForSummary()
        let devicesAndConfigurations = try loadDevicesAndConfigurations()
        let testFailures = try loadTestFailures()
        let statistics = try loadStatistics()

        let title = "\(action.name) - \(action.testPlanName)"
        let environmentDescription = try buildEnvironmentDescription()
        let startTime = TestResultsSummaryBuilder.toUnixTime(action.started)
        let finishTime = TestResultsSummaryBuilder.toUnixTime(action.finished)

        let result = summaryCounts.failedTests > 0 ? "Failed" : "Passed"

        return TestResultsSummary(
            devicesAndConfigurations: devicesAndConfigurations,
            environmentDescription: environmentDescription,
            expectedFailures: summaryCounts.expectedFailures,
            failedTests: summaryCounts.failedTests,
            finishTime: finishTime,
            passedTests: summaryCounts.passedTests,
            result: result,
            skippedTests: summaryCounts.skippedTests,
            startTime: startTime,
            statistics: statistics,
            testFailures: testFailures,
            title: title,
            topInsights: [],
            totalTestCount: totalTestCount
        )
    }

    private static func databasePath(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "xcresult" {
            return url.appendingPathComponent("database.sqlite3").path
        }
        if url.lastPathComponent == "database.sqlite3" {
            return url.path
        }
        return url.appendingPathComponent("database.sqlite3").path
    }

    private func countTotalTests() throws -> Int {
        let sql = "SELECT count(*) FROM TestCases;"
        let count = try database.queryOne(sql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        }
        return count ?? 0
    }

    private func resultCountsForSummary() throws -> ResultCounts {
        let sql = """
        SELECT result, count(*)
        FROM TestCaseResultsByDestinationAndConfiguration
        WHERE destination_fk IS NULL AND configuration_fk IS NULL
        GROUP BY result;
        """
        let rows = try database.query(sql) { statement in
            let result = SQLiteDatabase.string(statement, 0) ?? ""
            let count = SQLiteDatabase.int(statement, 1) ?? 0
            return (result, count)
        }
        return ResultCounts(rows: rows)
    }

    private func loadDevicesAndConfigurations() throws -> [DevicesAndConfiguration] {
        guard let runDestination = try fetchRunDestination(runDestinationId: action.runDestinationId) else {
            return []
        }
        let device = try loadDevice(for: runDestination)

        return try testPlanRuns.map { planRun in
            let configuration = try fetchConfiguration(configurationId: planRun.configurationId)
            let counts = try resultCountsForTestPlanRun(planRun.id)

            return DevicesAndConfiguration(
                device: device,
                expectedFailures: counts.expectedFailures,
                failedTests: counts.failedTests,
                passedTests: counts.passedTests,
                skippedTests: counts.skippedTests,
                testPlanConfiguration: TestPlanConfiguration(
                    configurationId: String(configuration.id),
                    configurationName: configuration.name
                )
            )
        }
    }

    private func resultCountsForTestPlanRun(_ testPlanRunId: Int) throws -> ResultCounts {
        let sql = """
        SELECT TestCaseRuns.result, count(*)
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestableRuns ON TestableRuns.rowid = TestSuiteRuns.testableRun_fk
        WHERE TestableRuns.testPlanRun_fk = ?
        GROUP BY TestCaseRuns.result;
        """
        let rows = try database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testPlanRunId))
        }) { statement in
            let result = SQLiteDatabase.string(statement, 0) ?? ""
            let count = SQLiteDatabase.int(statement, 1) ?? 0
            return (result, count)
        }
        return ResultCounts(rows: rows)
    }

    private func loadDevice(for runDestination: RunDestinationRow) throws -> SummaryDevice {
        guard let device = try fetchDevice(deviceId: runDestination.deviceId) else {
            throw SQLiteError("Missing device with rowid \(runDestination.deviceId).")
        }
        guard let platform = try fetchPlatform(platformId: device.platformId) else {
            throw SQLiteError("Missing platform with rowid \(device.platformId).")
        }
        let osBuildNumber = TestResultsSummaryBuilder.extractBuildNumber(device.operatingSystemVersionWithBuildNumber)
        return SummaryDevice(
            architecture: runDestination.architecture,
            deviceId: device.identifier,
            deviceName: runDestination.name,
            modelName: device.modelName,
            osBuildNumber: osBuildNumber,
            osVersion: device.operatingSystemVersion,
            platform: platform.userDescription
        )
    }

    private func buildEnvironmentDescription() throws -> String {
        guard let hostId = action.hostDeviceId,
              let hostDevice = try fetchDevice(deviceId: hostId),
              let platform = try fetchPlatform(platformId: hostDevice.platformId) else {
            return action.scheme
        }
        return "\(action.scheme) · Built with \(platform.userDescription) \(hostDevice.operatingSystemVersion)"
    }

    private func loadTestFailures() throws -> [TestFailure] {
        let sql = """
        SELECT TestIssues.compactDescription,
               TestIssues.detailedDescription,
               TestIssues.sanitizedDescription,
               TestIssues.testCaseRun_fk,
               TestCases.rowid,
               TestCases.identifier,
               TestCases.identifierURL,
               TestCases.name,
               TestSuites.name
        FROM TestIssues
        JOIN TestCaseRuns ON TestCaseRuns.rowid = TestIssues.testCaseRun_fk
        JOIN TestCases ON TestCases.rowid = TestCaseRuns.testCase_fk
        JOIN TestSuites ON TestSuites.rowid = TestCases.testSuite_fk
        WHERE TestIssues.isTopLevel = 1 AND TestIssues.testCaseRun_fk IS NOT NULL
        ORDER BY TestIssues.rowid;
        """

        return try database.query(sql) { statement in
            let compact = SQLiteDatabase.string(statement, 0)
            let detailed = SQLiteDatabase.string(statement, 1)
            let sanitized = SQLiteDatabase.string(statement, 2)
            let failureText = compact ?? detailed ?? sanitized ?? ""
            let testIdentifier = SQLiteDatabase.int(statement, 4) ?? 0
            let testIdentifierString = SQLiteDatabase.string(statement, 5) ?? ""
            let testIdentifierURL = SQLiteDatabase.string(statement, 6) ?? ""
            let testName = SQLiteDatabase.string(statement, 7) ?? ""
            let targetName = SQLiteDatabase.string(statement, 8) ?? ""

            return TestFailure(
                failureText: failureText,
                targetName: targetName,
                testIdentifier: testIdentifier,
                testIdentifierString: testIdentifierString,
                testIdentifierURL: testIdentifierURL,
                testName: testName
            )
        }
    }

    private func loadStatistics() throws -> [SummaryStatistic] {
        var stats: [SummaryStatistic] = []
        if let dynamic = try loadDynamicParameterStatistic() {
            stats.append(dynamic)
        }
        if let performance = try loadPerformanceMetricsStatistic() {
            stats.append(performance)
        }
        return stats
    }

    private func loadDynamicParameterStatistic() throws -> SummaryStatistic? {
        let testCountSql = "SELECT count(DISTINCT testCase_fk) FROM Parameters;"
        let testCount = try database.queryOne(testCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        guard testCount > 0 else { return nil }

        let runCountSql = """
        SELECT count(*)
        FROM TestCaseRuns
        WHERE testCase_fk IN (SELECT DISTINCT testCase_fk FROM Parameters);
        """
        let runCount = try database.queryOne(runCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0

        let title = "\(testCount) \(testCount == 1 ? "test ran" : "tests ran") with dynamic parameters"
        let subtitle = "\(runCount) \(runCount == 1 ? "test run" : "test runs")"
        return SummaryStatistic(subtitle: subtitle, title: title)
    }

    private func loadPerformanceMetricsStatistic() throws -> SummaryStatistic? {
        let runCountSql = "SELECT count(DISTINCT testCaseRun_fk) FROM PerformanceMetrics;"
        let runCount = try database.queryOne(runCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        guard runCount > 0 else { return nil }

        let testCountSql = """
        SELECT count(DISTINCT testCase_fk)
        FROM TestCaseRuns
        WHERE rowid IN (SELECT DISTINCT testCaseRun_fk FROM PerformanceMetrics);
        """
        let testCount = try database.queryOne(testCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0

        let title = "\(testCount) \(testCount == 1 ? "test collected" : "tests collected") performance metrics"
        let subtitle = "\(runCount) \(runCount == 1 ? "test run" : "test runs")"
        return SummaryStatistic(subtitle: subtitle, title: title)
    }

    private func fetchRunDestination(runDestinationId: Int?) throws -> RunDestinationRow? {
        guard let runDestinationId else { return nil }
        let sql = "SELECT rowid, name, architecture, device_fk FROM RunDestinations WHERE rowid = ?;"
        return try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(runDestinationId))
        }) { statement in
            RunDestinationRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                architecture: SQLiteDatabase.string(statement, 2) ?? "",
                deviceId: SQLiteDatabase.int(statement, 3) ?? 0
            )
        }
    }

    private func fetchConfiguration(configurationId: Int) throws -> ConfigurationRow {
        let sql = "SELECT rowid, name FROM TestPlanConfigurations WHERE rowid = ?;"
        let configuration = try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(configurationId))
        }) { statement in
            ConfigurationRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? ""
            )
        }
        return configuration ?? ConfigurationRow(id: configurationId, name: "")
    }

    private func fetchDevice(deviceId: Int) throws -> DeviceRow? {
        let sql = """
        SELECT rowid, identifier, name, modelName, operatingSystemVersion,
               operatingSystemVersionWithBuildNumber, platform_fk
        FROM Devices
        WHERE rowid = ?;
        """
        return try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(deviceId))
        }) { statement in
            DeviceRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                identifier: SQLiteDatabase.string(statement, 1) ?? "",
                name: SQLiteDatabase.string(statement, 2) ?? "",
                modelName: SQLiteDatabase.string(statement, 3) ?? "",
                operatingSystemVersion: SQLiteDatabase.string(statement, 4) ?? "",
                operatingSystemVersionWithBuildNumber: SQLiteDatabase.string(statement, 5) ?? "",
                platformId: SQLiteDatabase.int(statement, 6) ?? 0
            )
        }
    }

    private func fetchPlatform(platformId: Int) throws -> PlatformRow? {
        let sql = "SELECT rowid, userDescription FROM Platforms WHERE rowid = ?;"
        return try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(platformId))
        }) { statement in
            PlatformRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                userDescription: SQLiteDatabase.string(statement, 1) ?? ""
            )
        }
    }

    private static func fetchAction(from database: SQLiteDatabase) throws -> ActionRow? {
        let sql = """
        SELECT Actions.rowid,
               Actions.name,
               Actions.started,
               Actions.finished,
               Actions.runDestination_fk,
               Actions.host_fk,
               Invocations.scheme,
               TestPlans.name
        FROM Actions
        JOIN Invocations ON Invocations.rowid = Actions.invocation_fk
        JOIN TestPlans ON TestPlans.rowid = Actions.testPlan_fk
        ORDER BY Actions.orderInInvocation
        LIMIT 1;
        """
        return try database.queryOne(sql) { statement in
            ActionRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                started: SQLiteDatabase.double(statement, 2) ?? 0,
                finished: SQLiteDatabase.double(statement, 3) ?? 0,
                runDestinationId: SQLiteDatabase.int(statement, 4),
                hostDeviceId: SQLiteDatabase.int(statement, 5),
                scheme: SQLiteDatabase.string(statement, 6) ?? "",
                testPlanName: SQLiteDatabase.string(statement, 7) ?? ""
            )
        }
    }

    private static func fetchTestPlanRuns(from database: SQLiteDatabase, actionId: Int) throws -> [TestPlanRunRow] {
        let sql = """
        SELECT rowid, configuration_fk, orderInAction
        FROM TestPlanRuns
        WHERE action_fk = ?
        ORDER BY orderInAction;
        """
        return try database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(actionId))
        }) { statement in
            TestPlanRunRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                configurationId: SQLiteDatabase.int(statement, 1) ?? 0,
                orderInAction: SQLiteDatabase.int(statement, 2) ?? 0
            )
        }
    }

    private static func toUnixTime(_ coreDataTime: Double) -> Double {
        let unixTime = coreDataTime + 978_307_200
        return (unixTime * 1000).rounded() / 1000
    }

    private static func extractBuildNumber(_ value: String) -> String {
        guard let open = value.firstIndex(of: "("),
              let close = value.firstIndex(of: ")"),
              open < close else {
            return ""
        }
        return String(value[value.index(after: open)..<close])
    }
}

private struct ResultCounts {
    let passedTests: Int
    let failedTests: Int
    let skippedTests: Int
    let expectedFailures: Int

    init(rows: [(String, Int)]) {
        var passed = 0
        var failed = 0
        var skipped = 0
        var expected = 0
        for (result, count) in rows {
            switch result {
            case "Success":
                passed = count
            case "Failure":
                failed = count
            case "Skipped":
                skipped = count
            case "Expected Failure":
                expected = count
            default:
                continue
            }
        }
        self.passedTests = passed
        self.failedTests = failed
        self.skippedTests = skipped
        self.expectedFailures = expected
    }
}

private struct ActionRow {
    let id: Int
    let name: String
    let started: Double
    let finished: Double
    let runDestinationId: Int?
    let hostDeviceId: Int?
    let scheme: String
    let testPlanName: String
}

private struct TestPlanRunRow {
    let id: Int
    let configurationId: Int
    let orderInAction: Int
}

private struct RunDestinationRow {
    let id: Int
    let name: String
    let architecture: String
    let deviceId: Int
}

private struct ConfigurationRow {
    let id: Int
    let name: String
}

private struct DeviceRow {
    let id: Int
    let identifier: String
    let name: String
    let modelName: String
    let operatingSystemVersion: String
    let operatingSystemVersionWithBuildNumber: String
    let platformId: Int
}

private struct PlatformRow {
    let id: Int
    let userDescription: String
}
