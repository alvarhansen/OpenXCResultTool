import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

public struct TestResultsTestsBuilder {
    private let context: XCResultContext

    public init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    public func tests() throws -> TestResultsTests {
        let devices = try loadDevices()
        let configurations = try context.fetchConfigurations().map {
            TestPlanConfiguration(configurationId: String($0.id), configurationName: $0.name)
        }
        let testNodes = try buildTestPlanNodes()

        return TestResultsTests(
            devices: devices,
            testNodes: testNodes,
            testPlanConfigurations: configurations
        )
    }

    private func loadDevices() throws -> [SummaryDevice] {
        var devices: [SummaryDevice] = []
        for action in context.actions {
            guard let runDestination = try context.fetchRunDestination(runDestinationId: action.runDestinationId) else {
                continue
            }
            let device = try loadDevice(for: runDestination)
            devices.append(device)
        }
        return devices
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

    private func buildTestPlanNodes() throws -> [TestNode] {
        let planName = context.action.testPlanName
        let testables = try fetchTestables()
        let testableNodes = try testables.map { try buildTestableNode($0) }
        let planResult = TestResultFormatter.aggregate(testableNodes.compactMap { $0.result })

        let planNode = TestNode(
            children: testableNodes,
            details: nil,
            duration: nil,
            durationInSeconds: nil,
            name: planName,
            nodeIdentifier: nil,
            nodeIdentifierURL: nil,
            nodeType: "Test Plan",
            result: planResult
        )

        return [planNode]
    }

    private func buildTestableNode(_ testable: TestableRow) throws -> TestNode {
        let suites = try fetchSuites(for: testable.id)
        let suiteTree = try buildSuiteTree(suites: suites, testableId: testable.id)
        let suiteResults = suiteTree.map { $0.result }.compactMap { $0 }
        let result = TestResultFormatter.aggregate(suiteResults)

        return TestNode(
            children: suiteTree,
            details: nil,
            duration: nil,
            durationInSeconds: nil,
            name: testable.name,
            nodeIdentifier: nil,
            nodeIdentifierURL: testable.identifierURL,
            nodeType: nodeType(forTestKind: testable.testKind),
            result: result
        )
    }

    private func buildSuiteTree(suites: [TestSuiteRow], testableId: Int) throws -> [TestNode] {
        let grouped = Dictionary(grouping: suites, by: { $0.parentSuiteId })
        let roots = grouped[nil] ?? []
        return try roots.sorted(by: { $0.orderInParent < $1.orderInParent }).map {
            try buildSuiteNode($0, grouped: grouped, testableId: testableId)
        }
    }

    private func buildSuiteNode(
        _ suite: TestSuiteRow,
        grouped: [Int?: [TestSuiteRow]],
        testableId: Int
    ) throws -> TestNode {
        let childSuites = (grouped[suite.id] ?? []).sorted(by: { $0.orderInParent < $1.orderInParent })
        let childSuiteNodes = try childSuites.map { try buildSuiteNode($0, grouped: grouped, testableId: testableId) }
        let testCaseNodes = try buildTestCaseNodes(for: suite, testableId: testableId)
        let children = childSuiteNodes + testCaseNodes
        let result = TestResultFormatter.aggregate(children.compactMap { $0.result })

        return TestNode(
            children: children.isEmpty ? nil : children,
            details: nil,
            duration: nil,
            durationInSeconds: nil,
            name: suite.name,
            nodeIdentifier: nil,
            nodeIdentifierURL: suite.identifierURL,
            nodeType: "Test Suite",
            result: result
        )
    }

    private func buildTestCaseNodes(for suite: TestSuiteRow, testableId: Int) throws -> [TestNode] {
        let testCases = try fetchTestCases(for: suite.id)
        let testableRunIds = try fetchTestableRunIds(testableId: testableId)
        return try testCases.sorted(by: { $0.orderInTestSuite < $1.orderInTestSuite }).map { testCase in
            try buildTestCaseNode(testCase, testableRunIds: testableRunIds)
        }
    }

    private func buildTestCaseNode(_ testCase: TestCaseRow, testableRunIds: [Int]) throws -> TestNode {
        let runs = try fetchTestCaseRuns(testCaseId: testCase.id, testableRunIds: testableRunIds)
        let averageDuration = runs.isEmpty ? 0 : runs.map(\.duration).reduce(0, +) / Double(runs.count)
        let durationString = RunDurationFormatter.format(seconds: averageDuration)

        let runResults = runs.map { TestResultFormatter.mapResult($0.result) }
        let result = TestResultFormatter.aggregate(runResults)

        let children: [TestNode]?
        if context.testPlanRuns.count > 1 {
            let deviceNodes = try buildDeviceNodes(for: runs)
            children = deviceNodes.isEmpty ? nil : deviceNodes
        } else {
            var nodes: [TestNode] = []
            let argumentsNodes = try buildArgumentNodes(for: runs)
            nodes.append(contentsOf: argumentsNodes)

            let failureNodes = try buildFailureNodes(for: runs)
            nodes.append(contentsOf: failureNodes)
            children = nodes.isEmpty ? nil : nodes
        }

        return TestNode(
            children: children,
            details: nil,
            duration: durationString,
            durationInSeconds: averageDuration,
            name: testCase.name,
            nodeIdentifier: testCase.identifier,
            nodeIdentifierURL: testCase.identifierURL,
            nodeType: "Test Case",
            result: result
        )
    }

    private func buildArgumentNodes(for runs: [TestCaseRunRow]) throws -> [TestNode] {
        let runIds = runs.map(\.id)
        guard !runIds.isEmpty else { return [] }

        let arguments = try fetchArguments(runIds: runIds)
        var nodes: [TestNode] = []
        for run in runs {
            guard let args = arguments[run.id], !args.isEmpty else { continue }
            let name = args.map { ArgumentNameFormatter.displayName(label: $0.label, value: $0.value) }
                .joined(separator: ", ")
            let durationString = RunDurationFormatter.format(seconds: run.duration)
            let node = TestNode(
                children: nil,
                details: nil,
                duration: durationString,
                durationInSeconds: run.duration,
                name: name,
                nodeIdentifier: nil,
                nodeIdentifierURL: nil,
                nodeType: "Arguments",
                result: TestResultFormatter.mapResult(run.result)
            )
            nodes.append(node)
        }

        return nodes.sorted { $0.name < $1.name }
    }

    private func buildFailureNodes(for runs: [TestCaseRunRow]) throws -> [TestNode] {
        var nodes: [TestNode] = []
        for run in runs {
            let result = TestResultFormatter.mapResult(run.result)
            let issues = try fetchTestIssues(testCaseRunId: run.id)
            for issue in issues {
                let message = issueMessage(issue)
                if issue.issueType == "Runtime Warning" {
                    nodes.append(issueNode(message, nodeType: "Runtime Warning"))
                } else if result == "Failed" {
                    nodes.append(failureNode(message))
                }
            }

            switch result {
            case "Expected Failure":
                let failures = try fetchExpectedFailures(testCaseRunId: run.id)
                for failure in failures {
                    if !failure.isEmpty {
                        nodes.append(failureNode(failure))
                    }
                }
            case "Skipped":
                if let skipMessage = try fetchSkipMessage(skipNoticeId: run.skipNoticeId) {
                    nodes.append(failureNode(skipMessage))
                }
            default:
                continue
            }
        }

        return nodes
    }

    private func buildDeviceNodes(for runs: [TestCaseRunRow]) throws -> [TestNode] {
        guard !runs.isEmpty else { return [] }

        let planRunsById = Dictionary(uniqueKeysWithValues: context.testPlanRuns.map { ($0.id, $0) })
        let deviceInfoByAction = try loadDeviceInfoByAction()
        var runsByDevice: [String: [Int: [TestCaseRunRow]]] = [:]
        var deviceInfoById: [String: DeviceNodeInfo] = [:]

        for run in runs {
            guard let planRun = planRunsById[run.testPlanRunId],
                  let deviceInfo = deviceInfoByAction[planRun.actionId] else {
                continue
            }
            deviceInfoById[deviceInfo.id] = deviceInfo
            runsByDevice[deviceInfo.id, default: [:]][planRun.configurationId, default: []].append(run)
        }

        let sortedDeviceIds = deviceInfoById.values.sorted {
            if $0.name == $1.name { return $0.id < $1.id }
            return $0.name < $1.name
        }.map(\.id)

        var deviceNodes: [TestNode] = []
        for deviceId in sortedDeviceIds {
            guard let deviceInfo = deviceInfoById[deviceId],
                  let configs = runsByDevice[deviceId] else {
                continue
            }

            let configIds = configs.keys.sorted()
            var configNodes: [TestNode] = []
            for configId in configIds {
                guard let configRuns = configs[configId] else { continue }
                let configuration = try context.fetchConfiguration(configurationId: configId)
                let configResult = TestResultFormatter.aggregate(configRuns.map { TestResultFormatter.mapResult($0.result) })
                let averageDuration = configRuns.isEmpty ? 0 : configRuns.map(\.duration).reduce(0, +) / Double(configRuns.count)
                let durationString = RunDurationFormatter.format(seconds: averageDuration)

                var children: [TestNode] = []
                let argumentsNodes = try buildArgumentNodes(for: configRuns)
                children.append(contentsOf: argumentsNodes)
                let failureNodes = try buildFailureNodes(for: configRuns)
                children.append(contentsOf: failureNodes)
                let includeDuration = argumentsNodes.isEmpty

                let configNode = TestNode(
                    children: children.isEmpty ? nil : children,
                    details: nil,
                    duration: includeDuration ? durationString : nil,
                    durationInSeconds: includeDuration ? averageDuration : nil,
                    name: configuration.name,
                    nodeIdentifier: String(configuration.id),
                    nodeIdentifierURL: nil,
                    nodeType: "Test Plan Configuration",
                    result: configResult
                )
                configNodes.append(configNode)
            }

            let deviceResult = TestResultFormatter.aggregate(configNodes.compactMap { $0.result })
            let deviceNode = TestNode(
                children: configNodes,
                details: deviceInfo.details,
                duration: nil,
                durationInSeconds: nil,
                name: deviceInfo.name,
                nodeIdentifier: deviceInfo.id,
                nodeIdentifierURL: nil,
                nodeType: "Device",
                result: deviceResult
            )
            deviceNodes.append(deviceNode)
        }

        return deviceNodes
    }

    private func loadDeviceInfoByAction() throws -> [Int: DeviceNodeInfo] {
        var deviceInfo: [Int: DeviceNodeInfo] = [:]
        for action in context.actions {
            guard let runDestination = try context.fetchRunDestination(runDestinationId: action.runDestinationId) else {
                continue
            }
            guard let device = try context.fetchDevice(deviceId: runDestination.deviceId) else {
                throw SQLiteError("Missing device with rowid \(runDestination.deviceId).")
            }
            let platform = try context.fetchPlatform(platformId: device.platformId)
            let details = [platform?.userDescription, device.operatingSystemVersion]
                .compactMap { $0 }
                .joined(separator: " ")
            deviceInfo[action.id] = DeviceNodeInfo(
                id: device.identifier,
                name: runDestination.name,
                details: details
            )
        }
        return deviceInfo
    }

    private func issueNode(_ message: String, nodeType: String) -> TestNode {
        TestNode(
            children: nil,
            details: nil,
            duration: nil,
            durationInSeconds: nil,
            name: message,
            nodeIdentifier: nil,
            nodeIdentifierURL: nil,
            nodeType: nodeType,
            result: nil
        )
    }

    private func failureNode(_ message: String) -> TestNode {
        TestNode(
            children: nil,
            details: nil,
            duration: nil,
            durationInSeconds: nil,
            name: message,
            nodeIdentifier: nil,
            nodeIdentifierURL: nil,
            nodeType: "Failure Message",
            result: nil
        )
    }

    private func issueMessage(_ issue: TestIssueRow) -> String {
        if let location = issue.location {
            let fileName = URL(fileURLWithPath: location.filePath).lastPathComponent
            return "\(fileName):\(location.lineNumber): \(issue.compactDescription)"
        }
        return issue.compactDescription
    }

    private func fetchTestables() throws -> [TestableRow] {
        let sql = """
        SELECT rowid, name, identifierURL, testKind, orderInTestPlan
        FROM Testables
        WHERE testPlan_fk = ?
        ORDER BY orderInTestPlan;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(context.action.testPlanId))
        }) { statement in
            TestableRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                identifierURL: SQLiteDatabase.string(statement, 2) ?? "",
                testKind: SQLiteDatabase.string(statement, 3) ?? "",
                orderInTestPlan: SQLiteDatabase.int(statement, 4) ?? 0
            )
        }
    }

    private func fetchSuites(for testableId: Int) throws -> [TestSuiteRow] {
        let sql = """
        SELECT rowid, name, identifierURL, parentSuite_fk, orderInParent
        FROM TestSuites
        WHERE testable_fk = ?
        ORDER BY orderInParent;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testableId))
        }) { statement in
            TestSuiteRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                identifierURL: SQLiteDatabase.string(statement, 2) ?? "",
                parentSuiteId: SQLiteDatabase.int(statement, 3),
                orderInParent: SQLiteDatabase.int(statement, 4) ?? 0
            )
        }
    }

    private func fetchTestCases(for suiteId: Int) throws -> [TestCaseRow] {
        let sql = """
        SELECT rowid, name, identifier, identifierURL, orderInTestSuite
        FROM TestCases
        WHERE testSuite_fk = ?
        ORDER BY orderInTestSuite;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(suiteId))
        }) { statement in
            TestCaseRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                identifier: SQLiteDatabase.string(statement, 2) ?? "",
                identifierURL: SQLiteDatabase.string(statement, 3) ?? "",
                orderInTestSuite: SQLiteDatabase.int(statement, 4) ?? 0
            )
        }
    }

    private func fetchTestableRunIds(testableId: Int) throws -> [Int] {
        let planRunIds = context.testPlanRuns.map(\.id)
        guard !planRunIds.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: planRunIds.count).joined(separator: ",")
        let sql = """
        SELECT rowid
        FROM TestableRuns
        WHERE testable_fk = ?
          AND testPlanRun_fk IN (\(placeholders))
        ORDER BY orderInTestPlanRun;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testableId))
            for (index, id) in planRunIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 2), Int32(id))
            }
        }) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        }
    }

    private func fetchTestCaseRuns(testCaseId: Int, testableRunIds: [Int]) throws -> [TestCaseRunRow] {
        guard !testableRunIds.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: testableRunIds.count).joined(separator: ",")
        let sql = """
        SELECT TestCaseRuns.rowid,
               TestCaseRuns.duration,
               TestCaseRuns.result,
               TestCaseRuns.skipNotice_fk,
               TestableRuns.testPlanRun_fk
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestableRuns ON TestableRuns.rowid = TestSuiteRuns.testableRun_fk
        WHERE TestCaseRuns.testCase_fk = ?
          AND TestSuiteRuns.testableRun_fk IN (\(placeholders))
        ORDER BY TestCaseRuns.orderInTestSuiteRun;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testCaseId))
            for (index, id) in testableRunIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 2), Int32(id))
            }
        }) { statement in
            TestCaseRunRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                duration: SQLiteDatabase.double(statement, 1) ?? 0,
                result: SQLiteDatabase.string(statement, 2) ?? "",
                skipNoticeId: SQLiteDatabase.int(statement, 3),
                testPlanRunId: SQLiteDatabase.int(statement, 4) ?? 0
            )
        }
    }

    private func fetchArguments(runIds: [Int]) throws -> [Int: [ArgumentRow]] {
        guard !runIds.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: runIds.count).joined(separator: ",")
        let sql = """
        SELECT Arguments.testCaseRun_fk,
               Parameters.label,
               TestValues.description
        FROM Arguments
        JOIN Parameters ON Parameters.rowid = Arguments.parameter_fk
        JOIN TestValues ON TestValues.rowid = Arguments.testValue_fk
        WHERE Arguments.testCaseRun_fk IN (\(placeholders))
        ORDER BY Arguments.testCaseRun_fk, Arguments.orderInTestCaseRun;
        """
        let rows = try context.database.query(sql, binder: { statement in
            for (index, id) in runIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 1), Int32(id))
            }
        }) { statement in
            ArgumentRow(
                runId: SQLiteDatabase.int(statement, 0) ?? 0,
                label: SQLiteDatabase.string(statement, 1) ?? "",
                value: SQLiteDatabase.string(statement, 2) ?? ""
            )
        }
        return Dictionary(grouping: rows, by: { $0.runId })
    }

    private func fetchTestIssues(testCaseRunId: Int) throws -> [TestIssueRow] {
        let sql = """
        SELECT TestIssues.issueType,
               TestIssues.compactDescription,
               TestIssues.sourceCodeContext_fk
        FROM TestIssues
        WHERE TestIssues.isTopLevel = 1 AND TestIssues.testCaseRun_fk = ?
        ORDER BY TestIssues.rowid;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testCaseRunId))
        }) { statement in
            let issueType = SQLiteDatabase.string(statement, 0) ?? ""
            let description = SQLiteDatabase.string(statement, 1) ?? ""
            let contextId = SQLiteDatabase.int(statement, 2)
            let location = try fetchSourceCodeLocation(contextId: contextId)
            return TestIssueRow(issueType: issueType, compactDescription: description, location: location)
        }
    }

    private func fetchSourceCodeLocation(contextId: Int?) throws -> SourceCodeLocationRow? {
        guard let contextId else { return nil }
        let sql = """
        SELECT SourceCodeLocations.filePath, SourceCodeLocations.lineNumber
        FROM SourceCodeContexts
        JOIN SourceCodeLocations ON SourceCodeLocations.rowid = SourceCodeContexts.location_fk
        WHERE SourceCodeContexts.rowid = ?;
        """
        return try context.database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(contextId))
        }) { statement in
            SourceCodeLocationRow(
                filePath: SQLiteDatabase.string(statement, 0) ?? "",
                lineNumber: SQLiteDatabase.int(statement, 1) ?? 0
            )
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

    private func nodeType(forTestKind kind: String) -> String {
        switch kind.lowercased() {
        case "ui":
            return "UI test bundle"
        case "app hosted", "xctest-tool hosted":
            return "Unit test bundle"
        default:
            return "Test bundle"
        }
    }

}

private struct TestableRow {
    let id: Int
    let name: String
    let identifierURL: String
    let testKind: String
    let orderInTestPlan: Int
}

private struct TestSuiteRow {
    let id: Int
    let name: String
    let identifierURL: String
    let parentSuiteId: Int?
    let orderInParent: Int
}

private struct TestCaseRow {
    let id: Int
    let name: String
    let identifier: String
    let identifierURL: String
    let orderInTestSuite: Int
}

private struct TestCaseRunRow {
    let id: Int
    let duration: Double
    let result: String
    let skipNoticeId: Int?
    let testPlanRunId: Int
}

private struct DeviceNodeInfo {
    let id: String
    let name: String
    let details: String
}

private struct ArgumentRow {
    let runId: Int
    let label: String
    let value: String
}

private struct TestIssueRow {
    let issueType: String
    let compactDescription: String
    let location: SourceCodeLocationRow?
}

private struct SourceCodeLocationRow {
    let filePath: String
    let lineNumber: Int
}
