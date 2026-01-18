import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public struct TestResultsActivitiesBuilder {
    private let context: XCResultContext

    public init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    public func activities(testId: String) throws -> TestResultsActivities {
        guard let testCase = try fetchTestCase(identifier: testId) else {
            throw SQLiteError("Test case not found for identifier \(testId).")
        }
        let runs = try fetchTestCaseRuns(testCaseId: testCase.id)
        let devicesByAction = try loadDevicesByAction(for: runs)
        let suiteName = try fetchSuiteName(testSuiteId: testCase.testSuiteId) ?? ""
        let argumentsByRun = try fetchArguments(runIds: runs.map(\.id))

        let testRuns = try runs.map { run in
            guard let planRun = context.testPlanRuns.first(where: { $0.id == run.testPlanRunId }) else {
                throw SQLiteError("Missing test plan run with rowid \(run.testPlanRunId).")
            }
            let configuration = try context.fetchConfiguration(configurationId: planRun.configurationId)
            let device = devicesByAction[planRun.actionId] ?? emptySummaryDevice()
            let arguments = buildArgumentsList(argumentsByRun[run.id] ?? [])
            let activities = try buildActivities(
                runId: run.id,
                testCase: testCase,
                suiteName: suiteName
            )
            return TestRunActivities(
                activities: activities,
                arguments: arguments,
                device: device,
                testPlanConfiguration: TestPlanConfiguration(
                    configurationId: String(configuration.id),
                    configurationName: configuration.name
                )
            )
        }

        return TestResultsActivities(
            testIdentifier: testCase.identifier,
            testIdentifierURL: testCase.identifierURL,
            testName: testCase.name,
            testRuns: testRuns
        )
    }

    private func loadDevicesByAction(for runs: [TestCaseRunRow]) throws -> [Int: SummaryDevice] {
        let planRunsById = Dictionary(uniqueKeysWithValues: context.testPlanRuns.map { ($0.id, $0) })
        let actionIds = Set(runs.compactMap { planRunsById[$0.testPlanRunId]?.actionId })
        var devices: [Int: SummaryDevice] = [:]

        for action in context.actions where actionIds.contains(action.id) {
            guard let runDestination = try context.fetchRunDestination(runDestinationId: action.runDestinationId) else {
                continue
            }
            guard let device = try context.fetchDevice(deviceId: runDestination.deviceId) else {
                throw SQLiteError("Missing device with rowid \(runDestination.deviceId).")
            }
            guard let platform = try context.fetchPlatform(platformId: device.platformId) else {
                throw SQLiteError("Missing platform with rowid \(device.platformId).")
            }
            let osBuildNumber = TestResultsSummaryBuilder.extractBuildNumber(device.operatingSystemVersionWithBuildNumber)
            devices[action.id] = SummaryDevice(
                architecture: runDestination.architecture,
                deviceId: device.identifier,
                deviceName: runDestination.name,
                modelName: device.modelName,
                osBuildNumber: osBuildNumber,
                osVersion: device.operatingSystemVersion,
                platform: platform.userDescription
            )
        }
        return devices
    }

    private func emptySummaryDevice() -> SummaryDevice {
        SummaryDevice(
            architecture: "",
            deviceId: "",
            deviceName: "",
            modelName: "",
            osBuildNumber: "",
            osVersion: "",
            platform: ""
        )
    }

    private func buildArgumentsList(_ arguments: [ArgumentRow]) -> [TestArgument]? {
        guard !arguments.isEmpty else { return nil }
        let sorted = arguments.sorted { $0.orderInTestCaseRun < $1.orderInTestCaseRun }
        return sorted.map {
            let display = ArgumentNameFormatter.displayName(label: $0.label, value: $0.value)
            return TestArgument(value: display)
        }
    }

    private func buildActivities(
        runId: Int,
        testCase: TestCaseRow,
        suiteName: String
    ) throws -> [ActivityNode] {
        let activityRows = try fetchActivities(runId: runId)
        if !activityRows.isEmpty {
            let attachments = try fetchAttachments(activityIds: activityRows.map(\.id))
            return buildActivityTree(rows: activityRows, attachments: attachments)
        }
        let expectedFailures = try fetchExpectedFailureActivities(runId: runId)
        if !expectedFailures.isEmpty {
            return expectedFailures.map { expectedFailure in
                issueActivityNode(
                    title: expectedFailure.title,
                    timestamp: expectedFailure.timestamp,
                    isAssociatedWithFailure: false,
                    testCase: testCase,
                    suiteName: suiteName
                )
            }
        }
        let issues = try fetchIssueActivities(runId: runId)
        return issues.map { issue in
            issueActivityNode(
                title: issue.title,
                timestamp: issue.timestamp,
                isAssociatedWithFailure: true,
                testCase: testCase,
                suiteName: suiteName
            )
        }
    }

    private func buildActivityTree(
        rows: [ActivityRow],
        attachments: [Int: [AttachmentRow]]
    ) -> [ActivityNode] {
        let grouped = Dictionary(grouping: rows, by: { $0.parentId })
        let roots = (grouped[nil] ?? []).sorted { $0.orderInParent < $1.orderInParent }
        return roots.map { row in
            buildActivityNode(row: row, grouped: grouped, attachments: attachments)
        }
    }

    private func buildActivityNode(
        row: ActivityRow,
        grouped: [Int?: [ActivityRow]],
        attachments: [Int: [AttachmentRow]]
    ) -> ActivityNode {
        let childRows = (grouped[row.id] ?? []).sorted { $0.orderInParent < $1.orderInParent }
        var childActivities = childRows.map { buildActivityNode(row: $0, grouped: grouped, attachments: attachments) }
        let attachmentRows = attachments[row.id] ?? []
        let attachmentNodes = attachmentRows.map {
            ActivityAttachment(
                lifetime: $0.lifetime,
                name: $0.filename,
                payloadId: $0.payloadId,
                timestamp: toUnixTime($0.timestamp),
                uuid: $0.uuid
            )
        }
        if !attachmentRows.isEmpty {
            let attachmentChildren = attachmentRows.map {
                ActivityNode(
                    attachments: nil,
                    childActivities: nil,
                    isAssociatedWithFailure: false,
                    startTime: toUnixTime($0.timestamp),
                    title: $0.title
                )
            }
            childActivities.append(contentsOf: attachmentChildren)
        }
        let startTime = row.startTime.map { toUnixTime($0) }
        return ActivityNode(
            attachments: attachmentNodes.isEmpty ? nil : attachmentNodes,
            childActivities: childActivities.isEmpty ? nil : childActivities,
            isAssociatedWithFailure: row.isAssociatedWithFailure,
            startTime: startTime,
            title: row.title
        )
    }

    private func issueActivityNode(
        title: String,
        timestamp: Double?,
        isAssociatedWithFailure: Bool,
        testCase: TestCaseRow,
        suiteName: String
    ) -> ActivityNode {
        let child = ActivityNode(
            attachments: nil,
            childActivities: nil,
            isAssociatedWithFailure: false,
            startTime: nil,
            title: "\(suiteName).\(testCase.name)"
        )
        return ActivityNode(
            attachments: nil,
            childActivities: [child],
            isAssociatedWithFailure: isAssociatedWithFailure,
            startTime: timestamp.map { toUnixTime($0) },
            title: title
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
        let placeholders = Array(repeating: "?", count: planRunIds.count).joined(separator: ",")
        let sql = """
        SELECT TestCaseRuns.rowid,
               TestCaseRuns.orderInTestSuiteRun,
               TestableRuns.testPlanRun_fk
        FROM TestCaseRuns
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestableRuns ON TestableRuns.rowid = TestSuiteRuns.testableRun_fk
        WHERE TestCaseRuns.testCase_fk = ?
          AND TestableRuns.testPlanRun_fk IN (\(placeholders))
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
                orderInTestSuiteRun: SQLiteDatabase.int(statement, 1) ?? 0,
                testPlanRunId: SQLiteDatabase.int(statement, 2) ?? 0
            )
        }
    }

    private func fetchArguments(runIds: [Int]) throws -> [Int: [ArgumentRow]] {
        guard !runIds.isEmpty else { return [:] }
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
        let rows = try context.database.query(sql, binder: { statement in
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
        return Dictionary(grouping: rows, by: { $0.runId })
    }

    private func fetchActivities(runId: Int) throws -> [ActivityRow] {
        let sql = """
        WITH RECURSIVE ActivityTree(rowid, title, startTime, parent_fk, orderInParent, failureIDs, expectedFailureIDs) AS (
            SELECT rowid, title, startTime, parent_fk, orderInParent, failureIDs, expectedFailureIDs
            FROM Activities
            WHERE testCaseRun_fk = ?
            UNION ALL
            SELECT Activities.rowid,
                   Activities.title,
                   Activities.startTime,
                   Activities.parent_fk,
                   Activities.orderInParent,
                   Activities.failureIDs,
                   Activities.expectedFailureIDs
            FROM Activities
            JOIN ActivityTree ON Activities.parent_fk = ActivityTree.rowid
        )
        SELECT rowid,
               title,
               startTime,
               parent_fk,
               orderInParent,
               failureIDs,
               expectedFailureIDs
        FROM ActivityTree
        ORDER BY parent_fk, orderInParent;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(runId))
        }) { statement in
            ActivityRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                title: SQLiteDatabase.string(statement, 1) ?? "",
                startTime: SQLiteDatabase.double(statement, 2),
                parentId: SQLiteDatabase.int(statement, 3),
                orderInParent: SQLiteDatabase.int(statement, 4) ?? 0,
                failureIds: SQLiteDatabase.string(statement, 5),
                expectedFailureIds: SQLiteDatabase.string(statement, 6)
            )
        }
    }

    private func fetchAttachments(activityIds: [Int]) throws -> [Int: [AttachmentRow]] {
        guard !activityIds.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: activityIds.count).joined(separator: ",")
        let sql = """
        SELECT activity_fk,
               lifetime,
               name,
               filenameOverride,
               xcResultKitPayloadRefId,
               timestamp,
               uuid
        FROM Attachments
        WHERE activity_fk IN (\(placeholders))
        ORDER BY activity_fk, rowid;
        """
        let rows = try context.database.query(sql, binder: { statement in
            for (index, id) in activityIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 1), Int32(id))
            }
        }) { statement in
            let activityId = SQLiteDatabase.int(statement, 0) ?? 0
            let lifetime = SQLiteDatabase.string(statement, 1) ?? ""
            let name = SQLiteDatabase.string(statement, 2) ?? ""
            let filenameOverride = SQLiteDatabase.string(statement, 3)
            let payloadId = SQLiteDatabase.string(statement, 4) ?? ""
            let timestamp = SQLiteDatabase.double(statement, 5) ?? 0
            let uuid = SQLiteDatabase.string(statement, 6) ?? ""
            return AttachmentRow(
                activityId: activityId,
                lifetime: lifetime,
                title: name,
                filename: (filenameOverride?.isEmpty == false) ? filenameOverride ?? name : name,
                payloadId: payloadId,
                timestamp: timestamp,
                uuid: uuid
            )
        }
        return Dictionary(grouping: rows, by: { $0.activityId })
    }

    private func fetchExpectedFailureActivities(runId: Int) throws -> [IssueActivityRow] {
        let sql = """
        SELECT ExpectedFailures.failureReason,
               TestIssues.timestamp
        FROM ExpectedFailures
        JOIN TestIssues ON TestIssues.rowid = ExpectedFailures.issue_fk
        WHERE ExpectedFailures.testCaseRun_fk = ? AND ExpectedFailures.isTopLevelFailure = 1
        ORDER BY ExpectedFailures.orderInOwner;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(runId))
        }) { statement in
            IssueActivityRow(
                title: SQLiteDatabase.string(statement, 0) ?? "",
                timestamp: SQLiteDatabase.double(statement, 1)
            )
        }
    }

    private func fetchIssueActivities(runId: Int) throws -> [IssueActivityRow] {
        let sql = """
        SELECT compactDescription,
               detailedDescription,
               sanitizedDescription,
               timestamp
        FROM TestIssues
        WHERE isTopLevel = 1 AND testCaseRun_fk = ?
        ORDER BY rowid;
        """
        return try context.database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(runId))
        }) { statement in
            let title = SQLiteDatabase.string(statement, 0)
                ?? SQLiteDatabase.string(statement, 1)
                ?? SQLiteDatabase.string(statement, 2)
                ?? ""
            return IssueActivityRow(
                title: title,
                timestamp: SQLiteDatabase.double(statement, 3)
            )
        }
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
    let orderInTestSuiteRun: Int
    let testPlanRunId: Int
}

private struct ArgumentRow {
    let runId: Int
    let label: String
    let value: String
    let orderInTestCaseRun: Int
}

private struct ActivityRow {
    let id: Int
    let title: String
    let startTime: Double?
    let parentId: Int?
    let orderInParent: Int
    let failureIds: String?
    let expectedFailureIds: String?

    var isAssociatedWithFailure: Bool {
        let trimmed = (failureIds ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
}

private struct AttachmentRow {
    let activityId: Int
    let lifetime: String
    let title: String
    let filename: String
    let payloadId: String
    let timestamp: Double
    let uuid: String
}

private struct IssueActivityRow {
    let title: String
    let timestamp: Double?
}
