import Foundation
import SQLite3

struct CompareBuilder {
    private let baseline: XCResultContext
    private let current: XCResultContext

    init(baselinePath: String, currentPath: String) throws {
        self.baseline = try XCResultContext(xcresultPath: baselinePath)
        self.current = try XCResultContext(xcresultPath: currentPath)
    }

    func compare() throws -> CompareResult {
        let baselineTests = try loadTests(context: baseline)
        let currentTests = try loadTests(context: current)
        let testDiff = diffOrdered(
            current: currentTests,
            baseline: baselineTests,
            key: { $0.signature }
        )

        let baselineFailures = try loadFailures(context: baseline)
        let currentFailures = try loadFailures(context: current)
        let failureDiff = diffOrdered(
            current: currentFailures,
            baseline: baselineFailures,
            key: { $0.signature }
        )

        let baselineIssues = try loadBuildIssues(context: baseline)
        let currentIssues = try loadBuildIssues(context: current)

        let baselineBuild = baselineIssues.filter { !$0.isAnalyzer }
        let currentBuild = currentIssues.filter { !$0.isAnalyzer }
        let baselineAnalyzer = baselineIssues.filter { $0.isAnalyzer }
        let currentAnalyzer = currentIssues.filter { $0.isAnalyzer }

        let buildDiff = diffOrdered(
            current: currentBuild.filter(\.isDiffable),
            baseline: baselineBuild.filter(\.isDiffable),
            key: { $0.signature }
        )
        let analyzerDiff = diffOrdered(
            current: currentAnalyzer.filter(\.isDiffable),
            baseline: baselineAnalyzer.filter(\.isDiffable),
            key: { $0.signature }
        )

        let testsAdded = testDiff.introduced
            .sorted { $0.identifier < $1.identifier }
            .map(\.reference)
        let testsRemoved = testDiff.resolved
            .sorted { $0.identifier < $1.identifier }
            .map(\.reference)
        let failuresIntroduced = failureDiff.introduced
            .sorted { $0.sortKey < $1.sortKey }
            .map(\.detail)
        let failuresResolved = failureDiff.resolved
            .sorted { $0.sortKey < $1.sortKey }
            .map(\.detail)
        let buildIntroduced = buildDiff.introduced
            .sorted { $0.sortKey < $1.sortKey }
            .map(\.issue)
        let buildResolved = buildDiff.resolved
            .sorted { $0.sortKey < $1.sortKey }
            .map(\.issue)
        let analyzerIntroduced = analyzerDiff.introduced
            .sorted { $0.sortKey < $1.sortKey }
            .map(\.issue)
        let analyzerResolved = analyzerDiff.resolved
            .sorted { $0.sortKey < $1.sortKey }
            .map(\.issue)

        let summary = CompareSummary(
            analyzerIssues: DifferentialSummaryDetails(
                itemsInBaseline: baselineAnalyzer.count,
                itemsInCurrent: currentAnalyzer.count,
                introduced: analyzerIntroduced.count,
                resolved: analyzerResolved.count
            ),
            buildWarnings: DifferentialSummaryDetails(
                itemsInBaseline: baselineBuild.count,
                itemsInCurrent: currentBuild.count,
                introduced: buildIntroduced.count,
                resolved: buildResolved.count
            ),
            testFailures: DifferentialSummaryDetails(
                itemsInBaseline: baselineFailures.count,
                itemsInCurrent: currentFailures.count,
                introduced: failuresIntroduced.count,
                resolved: failuresResolved.count
            ),
            testsExecuted: DifferentialSummaryTestDetails(
                itemsInBaseline: baselineTests.count,
                itemsInCurrent: currentTests.count,
                added: testsAdded.count,
                removed: testsRemoved.count
            )
        )

        return CompareResult(
            summary: summary,
            testFailures: TestFailuresDifferential(
                introduced: failuresIntroduced,
                resolved: failuresResolved
            ),
            testsExecuted: TestsExecutedDifferential(
                added: testsAdded,
                removed: testsRemoved
            ),
            buildWarnings: IssuesDifferential(
                introduced: buildIntroduced,
                resolved: buildResolved
            ),
            analyzerIssues: IssuesDifferential(
                introduced: analyzerIntroduced,
                resolved: analyzerResolved
            )
        )
    }

    private func loadTests(context: XCResultContext) throws -> [CompareTestEntry] {
        let sql = """
        SELECT TestCases.rowid,
               TestCases.name,
               TestCases.identifier,
               TestCases.identifierURL
        FROM TestCaseRuns
        JOIN TestCases ON TestCases.rowid = TestCaseRuns.testCase_fk
        GROUP BY TestCases.rowid
        ORDER BY TestCases.rowid;
        """
        return try context.database.query(sql) { statement in
            CompareTestEntry(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                identifier: SQLiteDatabase.string(statement, 2) ?? "",
                identifierURL: SQLiteDatabase.string(statement, 3) ?? ""
            )
        }
    }

    private func loadFailures(context: XCResultContext) throws -> [CompareFailureEntry] {
        let sql = """
        SELECT TestIssues.rowid,
               TestIssues.compactDescription,
               TestIssues.sanitizedDescription,
               TestIssues.detailedDescription,
               TestCases.name,
               TestCases.identifier,
               TestCases.identifierURL
        FROM TestIssues
        JOIN TestCaseRuns ON TestCaseRuns.rowid = TestIssues.testCaseRun_fk
        JOIN TestCases ON TestCases.rowid = TestCaseRuns.testCase_fk
        WHERE TestIssues.isTopLevel = 1
        ORDER BY TestIssues.rowid;
        """
        return try context.database.query(sql) { statement in
            let compact = SQLiteDatabase.string(statement, 1)
            let sanitized = SQLiteDatabase.string(statement, 2)
            let detailed = SQLiteDatabase.string(statement, 3)
            let message = compact ?? sanitized ?? detailed ?? ""
            return CompareFailureEntry(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                message: message,
                testName: SQLiteDatabase.string(statement, 4) ?? "",
                testIdentifier: SQLiteDatabase.string(statement, 5) ?? "",
                testIdentifierURL: SQLiteDatabase.string(statement, 6) ?? ""
            )
        }
    }

    private func loadBuildIssues(context: XCResultContext) throws -> [CompareIssueEntry] {
        let sql = """
        SELECT BuildIssues.rowid,
               BuildIssues.issueType,
               BuildIssues.producingTarget,
               BuildIssues.message,
               BuildIssues.documentLocation_fk
        FROM BuildIssues
        ORDER BY BuildIssues.rowid;
        """
        return try context.database.query(sql) { statement in
            let issueType = SQLiteDatabase.string(statement, 1) ?? ""
            let producingTarget = SQLiteDatabase.string(statement, 2)
            let message = SQLiteDatabase.string(statement, 3) ?? ""
            let documentLocationId = SQLiteDatabase.int(statement, 4)
            return CompareIssueEntry(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                issueType: issueType,
                producingTarget: producingTarget,
                message: message,
                hasLocation: documentLocationId != nil
            )
        }
    }

    private func diffOrdered<T>(
        current: [T],
        baseline: [T],
        key: (T) -> String
    ) -> (introduced: [T], resolved: [T]) {
        var baselineCounts: [String: Int] = [:]
        for item in baseline {
            baselineCounts[key(item), default: 0] += 1
        }

        var introduced: [T] = []
        for item in current {
            let signature = key(item)
            if let count = baselineCounts[signature], count > 0 {
                baselineCounts[signature] = count - 1
            } else {
                introduced.append(item)
            }
        }

        var currentCounts: [String: Int] = [:]
        for item in current {
            currentCounts[key(item), default: 0] += 1
        }

        var resolved: [T] = []
        for item in baseline {
            let signature = key(item)
            if let count = currentCounts[signature], count > 0 {
                currentCounts[signature] = count - 1
            } else {
                resolved.append(item)
            }
        }

        return (introduced, resolved)
    }
}

struct CompareResult {
    let summary: CompareSummary
    let testFailures: TestFailuresDifferential
    let testsExecuted: TestsExecutedDifferential
    let buildWarnings: IssuesDifferential
    let analyzerIssues: IssuesDifferential
}

struct CompareOutput: Encodable {
    var analyzerIssues: IssuesDifferential?
    var buildWarnings: IssuesDifferential?
    var summary: CompareSummary?
    var testFailures: TestFailuresDifferential?
    var testsExecuted: TestsExecutedDifferential?
}

struct CompareSummary: Encodable {
    let analyzerIssues: DifferentialSummaryDetails
    let buildWarnings: DifferentialSummaryDetails
    let testFailures: DifferentialSummaryDetails
    let testsExecuted: DifferentialSummaryTestDetails
}

struct DifferentialSummaryDetails: Encodable {
    let itemsInBaseline: Int
    let itemsInCurrent: Int
    let introduced: Int
    let resolved: Int
}

struct DifferentialSummaryTestDetails: Encodable {
    let itemsInBaseline: Int
    let itemsInCurrent: Int
    let added: Int
    let removed: Int
}

struct TestFailuresDifferential: Encodable {
    let introduced: [TestFailureDifferentialDetails]
    let resolved: [TestFailureDifferentialDetails]
}

struct TestFailureDifferentialDetails: Encodable {
    let associatedTest: CompareTestReference
    let failureMessage: String
}

struct TestsExecutedDifferential: Encodable {
    let added: [CompareTestReference]
    let removed: [CompareTestReference]
}

struct CompareTestReference: Encodable {
    let name: String
    let testIdentifier: String
    let testIdentifierURL: String
}

struct IssuesDifferential: Encodable {
    let introduced: [CompareIssueReference]
    let resolved: [CompareIssueReference]
}

struct CompareIssueReference: Encodable {
    let message: String
    let producingTarget: String?
    let issueType: String
}

private struct CompareTestEntry {
    let id: Int
    let name: String
    let identifier: String
    let identifierURL: String

    var signature: String {
        identifierURL.isEmpty ? identifier : identifierURL
    }

    var reference: CompareTestReference {
        CompareTestReference(
            name: name,
            testIdentifier: identifier,
            testIdentifierURL: identifierURL
        )
    }
}

private struct CompareFailureEntry {
    let id: Int
    let message: String
    let testName: String
    let testIdentifier: String
    let testIdentifierURL: String

    var signature: String {
        let testKey = testIdentifierURL.isEmpty ? testIdentifier : testIdentifierURL
        return "\(testKey)|\(message)"
    }

    var sortKey: String {
        "\(testIdentifier)|\(message)"
    }

    var detail: TestFailureDifferentialDetails {
        TestFailureDifferentialDetails(
            associatedTest: CompareTestReference(
                name: testName,
                testIdentifier: testIdentifier,
                testIdentifierURL: testIdentifierURL
            ),
            failureMessage: message
        )
    }
}

private struct CompareIssueEntry {
    let id: Int
    let issueType: String
    let producingTarget: String?
    let message: String
    let hasLocation: Bool

    var isAnalyzer: Bool {
        issueType.lowercased().contains("analyzer")
    }

    var isDiffable: Bool {
        hasLocation
    }

    var signature: String {
        "\(issueType)|\(producingTarget ?? "")|\(message)"
    }

    var sortKey: String {
        "\(issueType)|\(producingTarget ?? "")|\(message)"
    }

    var issue: CompareIssueReference {
        CompareIssueReference(
            message: message,
            producingTarget: producingTarget,
            issueType: issueType
        )
    }
}
