import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

public struct CompareBuilder {
    private let baseline: XCResultContext
    private let current: XCResultContext

    public init(baselinePath: String, currentPath: String) throws {
        self.baseline = try XCResultContext(xcresultPath: baselinePath)
        self.current = try XCResultContext(xcresultPath: currentPath)
    }

    public func compare() throws -> CompareResult {
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

public struct CompareResult {
    public let summary: CompareSummary
    public let testFailures: TestFailuresDifferential
    public let testsExecuted: TestsExecutedDifferential
    public let buildWarnings: IssuesDifferential
    public let analyzerIssues: IssuesDifferential
}

public struct CompareOutput: Encodable {
    public var analyzerIssues: IssuesDifferential?
    public var buildWarnings: IssuesDifferential?
    public var summary: CompareSummary?
    public var testFailures: TestFailuresDifferential?
    public var testsExecuted: TestsExecutedDifferential?

    public init() {}
}

public struct CompareSummary: Encodable {
    public let analyzerIssues: DifferentialSummaryDetails
    public let buildWarnings: DifferentialSummaryDetails
    public let testFailures: DifferentialSummaryDetails
    public let testsExecuted: DifferentialSummaryTestDetails
}

public struct DifferentialSummaryDetails: Encodable {
    public let itemsInBaseline: Int
    public let itemsInCurrent: Int
    public let introduced: Int
    public let resolved: Int
}

public struct DifferentialSummaryTestDetails: Encodable {
    public let itemsInBaseline: Int
    public let itemsInCurrent: Int
    public let added: Int
    public let removed: Int
}

public struct TestFailuresDifferential: Encodable {
    public let introduced: [TestFailureDifferentialDetails]
    public let resolved: [TestFailureDifferentialDetails]
}

public struct TestFailureDifferentialDetails: Encodable {
    public let associatedTest: CompareTestReference
    public let failureMessage: String
}

public struct TestsExecutedDifferential: Encodable {
    public let added: [CompareTestReference]
    public let removed: [CompareTestReference]
}

public struct CompareTestReference: Encodable {
    public let name: String
    public let testIdentifier: String
    public let testIdentifierURL: String
}

public struct IssuesDifferential: Encodable {
    public let introduced: [CompareIssueReference]
    public let resolved: [CompareIssueReference]
}

public struct CompareIssueReference: Encodable {
    public let message: String
    public let producingTarget: String?
    public let issueType: String
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
