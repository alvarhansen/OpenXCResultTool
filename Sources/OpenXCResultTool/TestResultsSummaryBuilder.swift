import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

public struct TestResultsSummaryBuilder {
    private let context: XCResultContext
    private let xcresultPath: String

    public init(xcresultPath: String) throws {
        self.xcresultPath = xcresultPath
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    public func summary() throws -> TestResultsSummary {
        let action = context.action
        let totalTestCount = try countTotalTests()
        let summaryCounts = try resultCountsForSummary()
        let devicesAndConfigurations = try loadDevicesAndConfigurations()
        let testFailures = try loadTestFailures()
        let statistics = try loadStatistics()
        let topInsights = (try? loadTopInsights()) ?? []

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
            topInsights: topInsights,
            totalTestCount: totalTestCount
        )
    }

    private func countTotalTests() throws -> Int {
        let sql = "SELECT count(*) FROM TestCases;"
        let count = try context.database.queryOne(sql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        }
        return count ?? 0
    }

    private func countTestRuns() throws -> Int {
        let sql = "SELECT count(*) FROM TestCaseRuns;"
        let count = try context.database.queryOne(sql) { statement in
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
        let rows = try context.database.query(sql) { statement in
            let result = SQLiteDatabase.string(statement, 0) ?? ""
            let count = SQLiteDatabase.int(statement, 1) ?? 0
            return (result, count)
        }
        return ResultCounts(rows: rows)
    }

    private func loadDevicesAndConfigurations() throws -> [DevicesAndConfiguration] {
        var results: [DevicesAndConfiguration] = []

        for action in context.actions {
            guard let runDestination = try context.fetchRunDestination(runDestinationId: action.runDestinationId) else {
                continue
            }
            let device = try loadDevice(for: runDestination)
            let planRuns = context.testPlanRuns.filter { $0.actionId == action.id }

            for planRun in planRuns {
                let configuration = try context.fetchConfiguration(configurationId: planRun.configurationId)
                let counts = try resultCountsForTestPlanRun(planRun.id)

                results.append(
                    DevicesAndConfiguration(
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
                )
            }
        }

        return results.sorted {
            if $0.device.deviceName != $1.device.deviceName {
                return $0.device.deviceName < $1.device.deviceName
            }
            let leftConfig = Int($0.testPlanConfiguration.configurationId) ?? Int.max
            let rightConfig = Int($1.testPlanConfiguration.configurationId) ?? Int.max
            if leftConfig != rightConfig {
                return leftConfig < rightConfig
            }
            return $0.testPlanConfiguration.configurationName < $1.testPlanConfiguration.configurationName
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
        let rows = try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testPlanRunId))
        }) { statement in
            let result = SQLiteDatabase.string(statement, 0) ?? ""
            let count = SQLiteDatabase.int(statement, 1) ?? 0
            return (result, count)
        }
        return ResultCounts(rows: rows)
    }

    private func loadDevice(for runDestination: RunDestinationRow) throws -> SummaryDevice {
        guard let device = try context.fetchDevice(deviceId: runDestination.deviceId) else {
            throw SQLiteError("Missing device with rowid \(runDestination.deviceId).")
        }
        guard let platform = try context.fetchPlatform(platformId: device.platformId) else {
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
        let action = context.action
        guard let hostId = action.hostDeviceId,
              let hostDevice = try context.fetchDevice(deviceId: hostId),
              let platform = try context.fetchPlatform(platformId: hostDevice.platformId) else {
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
        WHERE TestIssues.isTopLevel = 1
          AND TestIssues.testCaseRun_fk IS NOT NULL
          AND TestCaseRuns.result = 'Failure'
        ORDER BY TestIssues.rowid;
        """

        return try context.database.query(sql) { statement in
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
        if let runStatistic = try loadTestRunStatistic() {
            stats.append(runStatistic)
        }
        if let dynamic = try loadDynamicParameterStatistic() {
            stats.append(dynamic)
        }
        if let performance = try loadPerformanceMetricsStatistic() {
            stats.append(performance)
        }
        return stats
    }

    private func loadTestRunStatistic() throws -> SummaryStatistic? {
        guard context.testPlanRuns.count > 1 else { return nil }
        let totalTests = try countTotalTests()
        let testRuns = try countTestRuns()
        let configurationCount = Set(context.testPlanRuns.map(\.configurationId)).count
        let deviceCount = Set(context.actions.compactMap(\.runDestinationId)).count

        let testLabel = totalTests == 1 ? "test ran" : "tests ran"
        let configurationLabel = configurationCount == 1 ? "configuration" : "configurations"
        let deviceLabel = deviceCount == 1 ? "device" : "devices"

        let title = "\(totalTests) \(testLabel) on \(configurationCount) \(configurationLabel) and \(deviceCount) \(deviceLabel)"
        let subtitle = "\(testRuns) test runs"
        return SummaryStatistic(subtitle: subtitle, title: title)
    }

    private func loadTopInsights() throws -> [SummaryInsight] {
        let insightsBuilder = try TestResultsInsightsBuilder(xcresultPath: xcresultPath)
        let insights = try insightsBuilder.insights()

        return insights.longestTestRunsInsights.map { insight in
            let percent = insight.impact.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            let impact = percent.isEmpty ? "" : "\(percent) of duration"
            return SummaryInsight(
                category: "Longest Test Runs",
                impact: impact,
                text: insight.title
            )
        }
    }

    private func loadDynamicParameterStatistic() throws -> SummaryStatistic? {
        let testCountSql = "SELECT count(DISTINCT testCase_fk) FROM Parameters;"
        let testCount = try context.database.queryOne(testCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        guard testCount > 0 else { return nil }

        let runCountSql = """
        SELECT count(*)
        FROM TestCaseRuns
        WHERE testCase_fk IN (SELECT DISTINCT testCase_fk FROM Parameters);
        """
        let runCount = try context.database.queryOne(runCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0

        let title = "\(testCount) \(testCount == 1 ? "test ran" : "tests ran") with dynamic parameters"
        let subtitle = "\(runCount) \(runCount == 1 ? "test run" : "test runs")"
        return SummaryStatistic(subtitle: subtitle, title: title)
    }

    private func loadPerformanceMetricsStatistic() throws -> SummaryStatistic? {
        let runCountSql = "SELECT count(DISTINCT testCaseRun_fk) FROM PerformanceMetrics;"
        let runCount = try context.database.queryOne(runCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        guard runCount > 0 else { return nil }

        let testCountSql = """
        SELECT count(DISTINCT testCase_fk)
        FROM TestCaseRuns
        WHERE rowid IN (SELECT DISTINCT testCaseRun_fk FROM PerformanceMetrics);
        """
        let testCount = try context.database.queryOne(testCountSql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0

        let title = "\(testCount) \(testCount == 1 ? "test collected" : "tests collected") performance metrics"
        let subtitle = "\(runCount) \(runCount == 1 ? "test run" : "test runs")"
        return SummaryStatistic(subtitle: subtitle, title: title)
    }

    private static func toUnixTime(_ coreDataTime: Double) -> Double {
        let unixTime = coreDataTime + 978_307_200
        return (unixTime * 1000).rounded() / 1000
    }

    static func extractBuildNumber(_ value: String) -> String {
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
