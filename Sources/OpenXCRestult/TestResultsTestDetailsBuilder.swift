import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct TestResultsTestDetailsBuilder {
    private let context: XCResultContext

    init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    func testDetails(testId: String) throws -> TestResultsTestDetails {
        guard let testCase = try fetchTestCase(identifier: testId) else {
            throw SQLiteError("Test case not found for identifier \(testId).")
        }

        let runs = try fetchTestCaseRuns(testCaseId: testCase.id)
        let runIds = runs.map(\.id)
        let argumentRows = try fetchArguments(runIds: runIds)
        let argumentsByRun = Dictionary(grouping: argumentRows, by: { $0.runId })
        let hasArguments = !argumentRows.isEmpty

        let runCount = runs.count
        let totalDuration = runs.map(\.duration).reduce(0, +)
        let averageDuration = runCount > 0 ? totalDuration / Double(runCount) : 0
        let durationSeconds = runCount > 1 ? averageDuration : (runs.first?.duration ?? 0)
        let durationString = runCount > 1
            ? DetailDurationFormatter.formatAverage(seconds: averageDuration)
            : DetailDurationFormatter.format(seconds: durationSeconds, average: false)

        let mappedResults = runs.map { TestResultFormatter.mapResult($0.result) }
        let testResult = TestResultFormatter.aggregate(mappedResults) ?? ""
        let testDescription = "Test case with \(runCount) \(runCount == 1 ? "run" : "runs")"

        let devices = try loadDevices()
        let configurations = try context.fetchConfigurations().map {
            TestPlanConfiguration(configurationId: String($0.id), configurationName: $0.name)
        }
        let startTime = try fetchStartTime(runIds: runIds)
        let hasMediaAttachments = try fetchMediaAttachments(runIds: runIds)
        let hasPerformanceMetrics = try fetchPerformanceMetrics(runIds: runIds)

        let arguments = hasArguments ? buildArgumentsList(arguments: argumentRows) : nil
        let testRuns: [TestDetailNode]
        if hasArguments {
            testRuns = buildArgumentRunNodes(runs: runs, argumentsByRun: argumentsByRun)
        } else {
            testRuns = try buildDeviceRunNodes(runs: runs, testCase: testCase)
        }

        return TestResultsTestDetails(
            arguments: arguments,
            devices: devices,
            duration: durationString,
            durationInSeconds: durationSeconds,
            hasMediaAttachments: hasMediaAttachments,
            hasPerformanceMetrics: hasPerformanceMetrics,
            startTime: startTime,
            testDescription: testDescription,
            testIdentifier: testCase.identifier,
            testIdentifierURL: testCase.identifierURL,
            testName: testCase.name,
            testPlanConfigurations: configurations,
            testResult: testResult,
            testRuns: testRuns
        )
    }

    private func loadDevices() throws -> [SummaryDevice] {
        guard let deviceInfo = try loadDeviceInfo() else { return [] }
        return [deviceInfo.device]
    }

    private func loadDeviceInfo() throws -> DeviceInfo? {
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
        let summaryDevice = SummaryDevice(
            architecture: runDestination.architecture,
            deviceId: device.identifier,
            deviceName: runDestination.name,
            modelName: device.modelName,
            osBuildNumber: osBuildNumber,
            osVersion: device.operatingSystemVersion,
            platform: platform.userDescription
        )
        let details = "\(platform.userDescription) \(device.operatingSystemVersion)"
        return DeviceInfo(
            device: summaryDevice,
            details: details,
            name: runDestination.name,
            identifier: device.identifier
        )
    }

    private func buildArgumentRunNodes(
        runs: [TestCaseRunRow],
        argumentsByRun: [Int: [ArgumentRow]]
    ) -> [TestDetailNode] {
        var nodes: [TestDetailNode] = []
        for run in runs {
            guard let arguments = argumentsByRun[run.id], !arguments.isEmpty else { continue }
            let sortedArguments = arguments.sorted { $0.orderInTestCaseRun < $1.orderInTestCaseRun }
            let name = sortedArguments.map {
                ArgumentNameFormatter.displayName(label: $0.label, value: $0.value)
            }.joined(separator: ", ")
            let durationString = RunDurationFormatter.format(seconds: run.duration)
            nodes.append(
                TestDetailNode(
                    children: nil,
                    details: nil,
                    duration: durationString,
                    durationInSeconds: run.duration,
                    name: name,
                    nodeIdentifier: nil,
                    nodeType: "Arguments",
                    result: TestResultFormatter.mapResult(run.result)
                )
            )
        }
        return nodes
    }

    private func buildArgumentsList(arguments: [ArgumentRow]) -> [TestArgument] {
        let grouped = Dictionary(grouping: arguments, by: { $0.label })
        let parameterGroups = grouped.map { label, values in
            ParameterGroup(
                label: label,
                orderIndex: values.map(\.orderInTestCaseRun).min() ?? 0,
                values: values.map(\.value)
            )
        }
        let sortedGroups = parameterGroups.sorted { $0.orderIndex < $1.orderIndex }
        var results: [TestArgument] = []
        for group in sortedGroups {
            let sortedValues = sortArgumentValues(label: group.label, values: group.values)
            for value in sortedValues {
                let display = ArgumentNameFormatter.displayName(label: group.label, value: value)
                results.append(TestArgument(value: display))
            }
        }
        return results
    }

    private func sortArgumentValues(label: String, values: [String]) -> [String] {
        switch label {
        case "XCUIAppearanceMode":
            let uniqueValues = Array(Set(values))
            return uniqueValues.sorted { lhs, rhs in
                let leftName = ArgumentNameFormatter.displayName(label: label, value: lhs)
                let rightName = ArgumentNameFormatter.displayName(label: label, value: rhs)
                return leftName < rightName
            }
        case "XCUIDeviceOrientation":
            let uniqueValues = Array(Set(values))
            return uniqueValues.sorted { lhs, rhs in
                let leftNumber = Int(lhs)
                let rightNumber = Int(rhs)
                if let leftNumber, let rightNumber, leftNumber != rightNumber {
                    return leftNumber < rightNumber
                }
                return lhs < rhs
            }
        default:
            break
        }

        var counts: [String: Int] = [:]
        for value in values {
            counts[value, default: 0] += 1
        }
        return Array(counts.keys).sorted { lhs, rhs in
            let leftCount = counts[lhs] ?? 0
            let rightCount = counts[rhs] ?? 0
            if leftCount != rightCount {
                return leftCount < rightCount
            }
            let leftNumber = Int(lhs)
            let rightNumber = Int(rhs)
            if let leftNumber, let rightNumber, leftNumber != rightNumber {
                return leftNumber < rightNumber
            }
            return lhs < rhs
        }
    }

    private func buildDeviceRunNodes(
        runs: [TestCaseRunRow],
        testCase: TestCaseRow
    ) throws -> [TestDetailNode] {
        guard let deviceInfo = try loadDeviceInfo() else { return [] }
        let suiteName = try fetchSuiteName(testSuiteId: testCase.testSuiteId) ?? ""
        let runsByPlanRun = Dictionary(grouping: runs, by: { $0.testPlanRunId })
        var configurationNodes: [TestDetailNode] = []
        for planRun in context.testPlanRuns {
            guard let planRuns = runsByPlanRun[planRun.id], !planRuns.isEmpty else { continue }
            let configuration = try context.fetchConfiguration(configurationId: planRun.configurationId)
            let node = try buildConfigurationNode(
                configuration: configuration,
                runs: planRuns,
                testCase: testCase,
                suiteName: suiteName
            )
            configurationNodes.append(node)
        }

        guard !configurationNodes.isEmpty else { return [] }
        let configResults = configurationNodes.compactMap { $0.result }
        let durationSeconds = configurationNodes.compactMap { $0.durationInSeconds }.reduce(0, +)
        let durationString = RunDurationFormatter.format(seconds: durationSeconds)
        let result = TestResultFormatter.aggregate(configResults)

        let deviceNode = TestDetailNode(
            children: configurationNodes,
            details: deviceInfo.details,
            duration: durationString,
            durationInSeconds: durationSeconds,
            name: deviceInfo.name,
            nodeIdentifier: deviceInfo.identifier,
            nodeType: "Device",
            result: result
        )
        return [deviceNode]
    }

    private func buildConfigurationNode(
        configuration: ConfigurationRow,
        runs: [TestCaseRunRow],
        testCase: TestCaseRow,
        suiteName: String
    ) throws -> TestDetailNode {
        let mappedResults = runs.map { TestResultFormatter.mapResult($0.result) }
        let result = TestResultFormatter.aggregate(mappedResults)
        let durationSeconds = runs.first?.duration ?? 0
        let durationString = RunDurationFormatter.format(seconds: durationSeconds)

        var children: [TestDetailNode] = []
        for run in runs {
            if let node = try buildTestCaseRunNode(run: run, testCase: testCase, suiteName: suiteName) {
                children.append(node)
            }
        }

        return TestDetailNode(
            children: children.isEmpty ? nil : children,
            details: nil,
            duration: durationString,
            durationInSeconds: durationSeconds,
            name: configuration.name,
            nodeIdentifier: String(configuration.id),
            nodeType: "Test Plan Configuration",
            result: result
        )
    }

    private func buildTestCaseRunNode(
        run: TestCaseRunRow,
        testCase: TestCaseRow,
        suiteName: String
    ) throws -> TestDetailNode? {
        let result = TestResultFormatter.mapResult(run.result)
        switch result {
        case "Failed":
            guard let issue = try fetchTestIssues(testCaseRunId: run.id).first else { return nil }
            let children = issue.hasLocation ? [sourceCodeReferenceNode(suiteName: suiteName, testCase: testCase)] : nil
            return TestDetailNode(
                children: children,
                details: nil,
                duration: nil,
                durationInSeconds: nil,
                name: issue.message,
                nodeIdentifier: nil,
                nodeType: "Test Case Run",
                result: result
            )
        case "Expected Failure":
            let failureReason = try fetchExpectedFailures(testCaseRunId: run.id)
                .first(where: { !$0.isEmpty }) ?? ""
            return TestDetailNode(
                children: nil,
                details: nil,
                duration: nil,
                durationInSeconds: nil,
                name: failureReason,
                nodeIdentifier: nil,
                nodeType: "Test Case Run",
                result: result
            )
        case "Skipped":
            guard let skipMessage = try fetchSkipMessage(skipNoticeId: run.skipNoticeId) else { return nil }
            return TestDetailNode(
                children: nil,
                details: nil,
                duration: nil,
                durationInSeconds: nil,
                name: skipMessage,
                nodeIdentifier: nil,
                nodeType: "Test Case Run",
                result: result
            )
        default:
            return nil
        }
    }

    private func sourceCodeReferenceNode(
        suiteName: String,
        testCase: TestCaseRow
    ) -> TestDetailNode {
        TestDetailNode(
            children: nil,
            details: nil,
            duration: nil,
            durationInSeconds: nil,
            name: "\(suiteName).\(testCase.name)",
            nodeIdentifier: nil,
            nodeType: "Source Code Reference",
            result: nil
        )
    }

    private func fetchTestCase(identifier: String) throws -> TestCaseRow? {
        let sql = """
        SELECT rowid, name, identifier, identifierURL, testSuite_fk
        FROM TestCases
        WHERE identifier = ? OR identifierURL = ?
        LIMIT 1;
        """
        return try context.database.queryOne(sql, binder: { statement in
            sqlite3_bind_text(statement, 1, identifier, -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, identifier, -1, sqliteTransient)
        }) { statement in
            TestCaseRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                identifier: SQLiteDatabase.string(statement, 2) ?? "",
                identifierURL: SQLiteDatabase.string(statement, 3) ?? "",
                testSuiteId: SQLiteDatabase.int(statement, 4) ?? 0
            )
        }
    }

    private func fetchSuiteName(testSuiteId: Int) throws -> String? {
        let sql = "SELECT name FROM TestSuites WHERE rowid = ?;"
        return try context.database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testSuiteId))
        }) { statement in
            SQLiteDatabase.string(statement, 0)
        } ?? nil
    }

    private func fetchTestCaseRuns(testCaseId: Int) throws -> [TestCaseRunRow] {
        let planRunIds = context.testPlanRuns.map(\.id)
        guard !planRunIds.isEmpty else { return [] }
        let placeholder = Array(repeating: "?", count: planRunIds.count).joined(separator: ",")
        let sql = """
        SELECT TestCaseRuns.rowid,
               TestCaseRuns.duration,
               TestCaseRuns.result,
               TestCaseRuns.skipNotice_fk,
               TestableRuns.testPlanRun_fk,
               TestCaseRuns.orderInTestSuiteRun
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestableRuns ON TestableRuns.rowid = TestSuiteRuns.testableRun_fk
        WHERE TestCaseRuns.testCase_fk = ?
          AND TestableRuns.testPlanRun_fk IN (\(placeholder))
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
                duration: SQLiteDatabase.double(statement, 1) ?? 0,
                result: SQLiteDatabase.string(statement, 2) ?? "",
                skipNoticeId: SQLiteDatabase.int(statement, 3),
                testPlanRunId: SQLiteDatabase.int(statement, 4) ?? 0,
                orderInTestSuiteRun: SQLiteDatabase.int(statement, 5) ?? 0
            )
        }
    }

    private func fetchArguments(runIds: [Int]) throws -> [ArgumentRow] {
        guard !runIds.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: runIds.count).joined(separator: ",")
        let sql = """
        SELECT Arguments.testCaseRun_fk,
               Parameters.label,
               TestValues.description,
               Arguments.orderInTestCaseRun
        FROM Arguments
        JOIN Parameters ON Parameters.rowid = Arguments.parameter_fk
        JOIN TestValues ON TestValues.rowid = Arguments.testValue_fk
        WHERE Arguments.testCaseRun_fk IN (\(placeholders))
        ORDER BY Arguments.testCaseRun_fk, Arguments.orderInTestCaseRun;
        """
        return try context.database.query(sql, binder: { statement in
            for (index, id) in runIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 1), Int32(id))
            }
        }) { statement in
            ArgumentRow(
                runId: SQLiteDatabase.int(statement, 0) ?? 0,
                label: SQLiteDatabase.string(statement, 1) ?? "",
                value: SQLiteDatabase.string(statement, 2) ?? "",
                orderInTestCaseRun: SQLiteDatabase.int(statement, 3) ?? 0
            )
        }
    }

    private func fetchTestIssues(testCaseRunId: Int) throws -> [TestIssueRow] {
        let sql = """
        SELECT TestIssues.compactDescription,
               TestIssues.detailedDescription,
               TestIssues.sanitizedDescription,
               TestIssues.sourceCodeContext_fk
        FROM TestIssues
        WHERE TestIssues.isTopLevel = 1 AND TestIssues.testCaseRun_fk = ?
        ORDER BY TestIssues.rowid;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testCaseRunId))
        }) { statement in
            let message = SQLiteDatabase.string(statement, 0)
                ?? SQLiteDatabase.string(statement, 1)
                ?? SQLiteDatabase.string(statement, 2)
                ?? ""
            let hasLocation = SQLiteDatabase.int(statement, 3) != nil
            return TestIssueRow(message: message, hasLocation: hasLocation)
        }
    }

    private func fetchExpectedFailures(testCaseRunId: Int) throws -> [String] {
        let sql = """
        SELECT failureReason
        FROM ExpectedFailures
        WHERE testCaseRun_fk = ? AND isTopLevelFailure = 1
        ORDER BY orderInOwner;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testCaseRunId))
        }) { statement in
            SQLiteDatabase.string(statement, 0) ?? ""
        }
    }

    private func fetchSkipMessage(skipNoticeId: Int?) throws -> String? {
        guard let skipNoticeId else { return nil }
        let sql = "SELECT message FROM SkipNotices WHERE rowid = ?;"
        return try context.database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(skipNoticeId))
        }) { statement in
            SQLiteDatabase.string(statement, 0)
        } ?? nil
    }

    private func fetchMediaAttachments(runIds: [Int]) throws -> Bool {
        guard !runIds.isEmpty else { return false }
        let placeholders = Array(repeating: "?", count: runIds.count).joined(separator: ",")
        let sql = """
        SELECT count(*)
        FROM Attachments
        JOIN Activities ON Activities.rowid = Attachments.activity_fk
        WHERE Activities.testCaseRun_fk IN (\(placeholders));
        """
        let count = try context.database.queryOne(sql, binder: { statement in
            for (index, id) in runIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 1), Int32(id))
            }
        }) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        return count > 0
    }

    private func fetchPerformanceMetrics(runIds: [Int]) throws -> Bool {
        guard !runIds.isEmpty else { return false }
        let placeholders = Array(repeating: "?", count: runIds.count).joined(separator: ",")
        let sql = """
        SELECT count(*)
        FROM PerformanceMetrics
        WHERE testCaseRun_fk IN (\(placeholders));
        """
        let count = try context.database.queryOne(sql, binder: { statement in
            for (index, id) in runIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 1), Int32(id))
            }
        }) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        return count > 0
    }

    private func fetchStartTime(runIds: [Int]) throws -> Double? {
        guard !runIds.isEmpty else { return nil }
        let placeholders = Array(repeating: "?", count: runIds.count).joined(separator: ",")
        let sql = """
        SELECT min(startTime)
        FROM Activities
        WHERE testCaseRun_fk IN (\(placeholders));
        """
        let startTime = try context.database.queryOne(
            sql,
            binder: { statement in
                for (index, id) in runIds.enumerated() {
                    sqlite3_bind_int(statement, Int32(index + 1), Int32(id))
                }
            },
            row: { statement in
                SQLiteDatabase.double(statement, 0)
            }
        ) ?? nil
        guard let startTime else { return nil }
        return toUnixTime(startTime)
    }

    private func toUnixTime(_ coreDataTime: Double) -> Double {
        let unixTime = coreDataTime + 978_307_200
        return (unixTime * 1000).rounded() / 1000
    }
}

private struct TestCaseRow {
    let id: Int
    let name: String
    let identifier: String
    let identifierURL: String
    let testSuiteId: Int
}

private struct TestCaseRunRow {
    let id: Int
    let duration: Double
    let result: String
    let skipNoticeId: Int?
    let testPlanRunId: Int
    let orderInTestSuiteRun: Int
}

private struct ArgumentRow {
    let runId: Int
    let label: String
    let value: String
    let orderInTestCaseRun: Int
}

private struct ParameterGroup {
    let label: String
    let orderIndex: Int
    let values: [String]
}

private struct TestIssueRow {
    let message: String
    let hasLocation: Bool
}

private struct DeviceInfo {
    let device: SummaryDevice
    let details: String
    let name: String
    let identifier: String
}
