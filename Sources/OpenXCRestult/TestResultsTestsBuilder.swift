import Foundation
import SQLite3

struct TestResultsTestsBuilder {
    private let context: XCResultContext

    init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    func tests() throws -> TestResultsTests {
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
        guard let runDestination = try context.fetchRunDestination(runDestinationId: context.action.runDestinationId) else {
            return []
        }
        let device = try loadDevice(for: runDestination)
        return [device]
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
        let planResult = aggregateResult(from: testableNodes.compactMap { $0.result })

        let planNode = TestNode(
            children: testableNodes,
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
        let result = aggregateResult(from: suiteResults)

        return TestNode(
            children: suiteTree,
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
        let result = aggregateResult(from: children.compactMap { $0.result })

        return TestNode(
            children: children.isEmpty ? nil : children,
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
        let durationString = DurationFormatter.format(seconds: averageDuration)

        let runResults = runs.map { mapResult($0.result) }
        let result = aggregateResult(from: runResults)

        var children: [TestNode] = []
        let argumentsNodes = try buildArgumentNodes(for: runs)
        children.append(contentsOf: argumentsNodes)

        let failureNodes = try buildFailureNodes(for: runs)
        children.append(contentsOf: failureNodes)

        return TestNode(
            children: children.isEmpty ? nil : children,
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
            let name = args.map { argumentDisplayName($0) }.joined(separator: ", ")
            let durationString = DurationFormatter.format(seconds: run.duration)
            let node = TestNode(
                children: nil,
                duration: durationString,
                durationInSeconds: run.duration,
                name: name,
                nodeIdentifier: nil,
                nodeIdentifierURL: nil,
                nodeType: "Arguments",
                result: mapResult(run.result)
            )
            nodes.append(node)
        }

        return nodes.sorted { $0.name < $1.name }
    }

    private func buildFailureNodes(for runs: [TestCaseRunRow]) throws -> [TestNode] {
        var nodes: [TestNode] = []
        for run in runs {
            let result = mapResult(run.result)
            switch result {
            case "Failed":
                let issues = try fetchTestIssues(testCaseRunId: run.id)
                for issue in issues {
                    let message = issueMessage(issue)
                    nodes.append(failureNode(message))
                }
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

    private func failureNode(_ message: String) -> TestNode {
        TestNode(
            children: nil,
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
        SELECT TestCaseRuns.rowid, TestCaseRuns.duration, TestCaseRuns.result, TestCaseRuns.skipNotice_fk
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
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
                skipNoticeId: SQLiteDatabase.int(statement, 3)
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
        SELECT TestIssues.compactDescription, TestIssues.sourceCodeContext_fk
        FROM TestIssues
        WHERE TestIssues.isTopLevel = 1 AND TestIssues.testCaseRun_fk = ?
        ORDER BY TestIssues.rowid;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(testCaseRunId))
        }) { statement in
            let description = SQLiteDatabase.string(statement, 0) ?? ""
            let contextId = SQLiteDatabase.int(statement, 1)
            let location = try fetchSourceCodeLocation(contextId: contextId)
            return TestIssueRow(compactDescription: description, location: location)
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
        case "app hosted":
            return "Unit test bundle"
        default:
            return "Test bundle"
        }
    }

    private func mapResult(_ result: String) -> String {
        switch result {
        case "Success":
            return "Passed"
        case "Failure":
            return "Failed"
        default:
            return result
        }
    }

    private func aggregateResult(from results: [String]) -> String? {
        if results.contains("Failed") {
            return "Failed"
        }
        if results.contains("Skipped") {
            return "Skipped"
        }
        if results.contains("Expected Failure") {
            return "Expected Failure"
        }
        if results.contains("Passed") {
            return "Passed"
        }
        return nil
    }

    private func argumentDisplayName(_ argument: ArgumentRow) -> String {
        switch argument.label {
        case "XCUIAppearanceMode":
            return appearanceName(from: argument.value)
        case "XCUIDeviceOrientation":
            return orientationName(from: argument.value)
        default:
            return argument.value
        }
    }

    private func appearanceName(from value: String) -> String {
        switch value {
        case "1":
            return "Light Appearance"
        case "2":
            return "Dark Appearance"
        case "4":
            return "Unspecified"
        default:
            return value
        }
    }

    private func orientationName(from value: String) -> String {
        switch value {
        case "1":
            return "Portrait"
        case "4":
            return "Landscape Right"
        default:
            return value
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
}

private struct ArgumentRow {
    let runId: Int
    let label: String
    let value: String
}

private struct TestIssueRow {
    let compactDescription: String
    let location: SourceCodeLocationRow?
}

private struct SourceCodeLocationRow {
    let filePath: String
    let lineNumber: Int
}

private struct DurationFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = ","
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 2
        formatter.maximumSignificantDigits = 2
        return formatter
    }()

    static func format(seconds: Double) -> String {
        if seconds >= 60 {
            let totalSeconds = Int(seconds.rounded(.down))
            let minutes = totalSeconds / 60
            let remaining = totalSeconds % 60
            return "\(minutes)m \(remaining)s"
        }
        if seconds >= 1 {
            let whole = Int(seconds.rounded(.down))
            return "\(whole)s"
        }
        let number = NSNumber(value: seconds)
        let value = formatter.string(from: number) ?? String(format: "%.2f", seconds)
        return "\(value)s"
    }
}
