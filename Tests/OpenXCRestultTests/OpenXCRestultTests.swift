import Foundation
import XCTest
@testable import OpenXCRestult

final class OpenXCRestultTests: XCTestCase {
    func testSummaryMatchesFixture() throws {
        try assertMatchesSnapshots(
            suffix: "summary",
            build: { path in
                let builder = try TestResultsSummaryBuilder(xcresultPath: path)
                let summary = try builder.summary()
                return try encode(summary)
            }
        )
    }

    func testTestsMatchesFixture() throws {
        try assertMatchesSnapshots(
            suffix: "tests",
            build: { path in
                let builder = try TestResultsTestsBuilder(xcresultPath: path)
                let tests = try builder.tests()
                return try encode(tests)
            }
        )
    }

    func testInsightsMatchesFixture() throws {
        try assertMatchesSnapshots(
            suffix: "insights",
            build: { path in
                let builder = try TestResultsInsightsBuilder(xcresultPath: path)
                let insights = try builder.insights()
                return try encode(insights)
            }
        )
    }

    func testTestDetailsMatchesFixture() throws {
        let snapshots = [
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffUITestsLaunchTests/testLaunch",
                snapshotSuffix: "test-details.testLaunch"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffUITests/testLaunchPerformance()",
                snapshotSuffix: "test-details.testLaunchPerformance"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffTests/testExample()",
                snapshotSuffix: "test-details.testExample"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testExpectedFailure()",
                snapshotSuffix: "test-details.testExpectedFailure"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testExpectedFailure2()",
                snapshotSuffix: "test-details.testExpectedFailure2"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testFoo()",
                snapshotSuffix: "test-details.testFoo"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testSkippedTest()",
                snapshotSuffix: "test-details.testSkippedTest"
            ),
        ]

        for snapshot in snapshots {
            let fixtureURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).xcresult")
            let snapshotURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).\(snapshot.snapshotSuffix).json")

            let builder = try TestResultsTestDetailsBuilder(xcresultPath: fixtureURL.path)
            let details = try builder.testDetails(testId: snapshot.testId)
            let actual = try encode(details)
            let expected = try Data(contentsOf: snapshotURL)

            let normalizedActual = try normalizedJSON(actual)
            let normalizedExpected = try normalizedJSON(expected)

            XCTAssertEqual(normalizedActual, normalizedExpected, "Mismatch for fixture \(snapshot.fixtureName) (\(snapshot.snapshotSuffix))")
        }
    }

    func testActivitiesMatchesFixture() throws {
        let snapshots = [
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffUITestsLaunchTests/testLaunch",
                snapshotSuffix: "activities.testLaunch"
            ),
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffTests/testExample()",
                snapshotSuffix: "activities.testExample"
            ),
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testFoo()",
                snapshotSuffix: "activities.testFoo"
            ),
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testExpectedFailure()",
                snapshotSuffix: "activities.testExpectedFailure"
            ),
        ]

        for snapshot in snapshots {
            let fixtureURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).xcresult")
            let snapshotURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).\(snapshot.snapshotSuffix).json")

            let builder = try TestResultsActivitiesBuilder(xcresultPath: fixtureURL.path)
            let activities = try builder.activities(testId: snapshot.testId)
            let actual = try encode(activities)
            let expected = try Data(contentsOf: snapshotURL)

            let normalizedActual = try normalizedJSON(actual)
            let normalizedExpected = try normalizedJSON(expected)

            XCTAssertEqual(normalizedActual, normalizedExpected, "Mismatch for fixture \(snapshot.fixtureName) (\(snapshot.snapshotSuffix))")
        }
    }

    func testMetricsMatchesFixture() throws {
        let snapshots = [
            MetricsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                snapshotSuffix: "metrics"
            ),
            MetricsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                snapshotSuffix: "metrics"
            ),
        ]

        for snapshot in snapshots {
            let fixtureURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).xcresult")
            let snapshotURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).\(snapshot.snapshotSuffix).json")

            let builder = try TestResultsMetricsBuilder(xcresultPath: fixtureURL.path)
            let metrics = try builder.metrics(testId: nil)
            let actual = try encode(metrics)
            let expected = try Data(contentsOf: snapshotURL)

            let normalizedActual = try normalizedJSON(actual)
            let normalizedExpected = try normalizedJSON(expected)

            XCTAssertEqual(normalizedActual, normalizedExpected, "Mismatch for fixture \(snapshot.fixtureName) (\(snapshot.snapshotSuffix))")
        }
    }

    func testMetricsWithTestIdMatchesFixture() throws {
        let snapshot = MetricsTestIdSnapshot(
            fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
            testId: "RandomStuffUITests/testLaunchPerformance()",
            snapshotSuffix: "metrics.testLaunchPerformance"
        )

        let fixtureURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).xcresult")
        let snapshotURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).\(snapshot.snapshotSuffix).json")

        let builder = try TestResultsMetricsBuilder(xcresultPath: fixtureURL.path)
        let metrics = try builder.metrics(testId: snapshot.testId)
        let actual = try encode(metrics)
        let expected = try Data(contentsOf: snapshotURL)

        let normalizedActual = try normalizedJSON(actual)
        let normalizedExpected = try normalizedJSON(expected)

        XCTAssertEqual(normalizedActual, normalizedExpected, "Mismatch for fixture \(snapshot.fixtureName) (\(snapshot.snapshotSuffix))")
    }

    func testXCResultToolParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let commands: [XCResulttoolCommand] = [.summary, .tests, .insights, .metrics]
        let fixtures = try fixtureBundles()

        for fixtureURL in fixtures {
            for command in commands {
                let expected = try xcresulttoolJSON(
                    xcrunURL: xcrunURL,
                    fixtureURL: fixtureURL,
                    command: command
                )
                let actual = try openXcresultOutput(
                    fixturePath: fixtureURL.path,
                    command: command
                )

                let normalizedActual = try normalizedParityJSON(actual, command: command)
                let normalizedExpected = try normalizedParityJSON(expected, command: command)

                XCTAssertEqual(
                    normalizedActual,
                    normalizedExpected,
                    "Mismatch for fixture \(fixtureURL.lastPathComponent) (\(command.rawValue))"
                )
            }
        }
    }

    func testXCResultToolBuildResultsParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        for fixtureURL in fixtures {
            let expected = try xcresulttoolBuildResultsJSON(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL
            )
            let actual = try openXcresultBuildResultsOutput(
                fixturePath: fixtureURL.path
            )

            let normalizedActual = try normalizedJSON(actual)
            let normalizedExpected = try normalizedJSON(expected)

            XCTAssertEqual(
                normalizedActual,
                normalizedExpected,
                "Mismatch for fixture \(fixtureURL.lastPathComponent) (build-results)"
            )
        }
    }

    func testMergeCombinesRowsAndData() throws {
        try assertMergedRowsAndData(
            fixtureNames: [
                "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                "Test-RandomStuff-2026.01.11_14-12-06-+0200",
            ]
        )
    }

    func testMergeCombinesRowsAndDataWithThreeBundles() throws {
        try assertMergedRowsAndData(
            fixtureNames: [
                "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                "Test-Kickstarter-Framework-iOS-2026.01.11_21-21-05-+0200",
            ]
        )
    }

    func testMergeForeignKeyIntegrity() throws {
        let fixtureNames = [
            "Test-RandomStuff-2026.01.11_12-36-33-+0200",
            "Test-RandomStuff-2026.01.11_14-12-06-+0200",
        ]
        let fixtureURLs = fixtureNames.map { fixturesDirectory().appendingPathComponent("\($0).xcresult") }
        let outputURL = try mergeFixtures(fixtureNames)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var expectedViolations: Int64 = 0
        for fixtureURL in fixtureURLs {
            expectedViolations += try foreignKeyMissingReferenceCount(
                in: fixtureURL.appendingPathComponent("database.sqlite3")
            )
        }

        let outputDB = outputURL.appendingPathComponent("database.sqlite3")
        let mergedViolations = try foreignKeyMissingReferenceCount(in: outputDB)
        XCTAssertEqual(
            mergedViolations,
            expectedViolations,
            "Merged database has unexpected foreign key violations"
        )
    }

    func testMergeSelectedForeignKeys() throws {
        let fixtureNames = [
            "Test-RandomStuff-2026.01.11_12-36-33-+0200",
            "Test-RandomStuff-2026.01.11_14-12-06-+0200",
            "Test-Kickstarter-Framework-iOS-2026.01.11_21-21-05-+0200",
        ]
        let fixtureURLs = fixtureNames.map { fixturesDirectory().appendingPathComponent("\($0).xcresult") }
        let outputURL = try mergeFixtures(fixtureNames)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let checks: [ForeignKeyCheck] = [
            ForeignKeyCheck(table: "TestCaseRuns", column: "testCase_fk", referencedTable: "TestCases"),
            ForeignKeyCheck(table: "TestCaseRuns", column: "testSuiteRun_fk", referencedTable: "TestSuiteRuns"),
            ForeignKeyCheck(table: "TestSuiteRuns", column: "testableRun_fk", referencedTable: "TestableRuns"),
            ForeignKeyCheck(table: "TestCaseResultsByDestinationAndConfiguration", column: "testCase_fk", referencedTable: "TestCases"),
            ForeignKeyCheck(table: "TestCaseResultsByDestinationAndConfiguration", column: "destination_fk", referencedTable: "RunDestinations"),
            ForeignKeyCheck(table: "TestableRuns", column: "testable_fk", referencedTable: "Testables"),
            ForeignKeyCheck(table: "TestableRuns", column: "testPlanRun_fk", referencedTable: "TestPlanRuns"),
            ForeignKeyCheck(table: "TestSuites", column: "testable_fk", referencedTable: "Testables"),
            ForeignKeyCheck(table: "TestIssues", column: "testCaseRun_fk", referencedTable: "TestCaseRuns"),
            ForeignKeyCheck(table: "Attachments", column: "activity_fk", referencedTable: "Activities"),
            ForeignKeyCheck(table: "Activities", column: "testCaseRun_fk", referencedTable: "TestCaseRuns"),
            ForeignKeyCheck(table: "TestPlanRuns", column: "action_fk", referencedTable: "Actions"),
            ForeignKeyCheck(table: "TestPlanRuns", column: "testPlan_fk", referencedTable: "TestPlans"),
            ForeignKeyCheck(table: "PerformanceMetrics", column: "testCaseRun_fk", referencedTable: "TestCaseRuns"),
            ForeignKeyCheck(table: "BuildIssues", column: "action_fk", referencedTable: "Actions"),
        ]

        let outputDB = outputURL.appendingPathComponent("database.sqlite3")
        for check in checks {
            var expectedMissing: Int64 = 0
            for fixtureURL in fixtureURLs {
                expectedMissing += try missingReferenceCount(
                    in: fixtureURL.appendingPathComponent("database.sqlite3"),
                    check: check
                )
            }
            let actualMissing = try missingReferenceCount(in: outputDB, check: check)
            XCTAssertEqual(
                actualMissing,
                expectedMissing,
                "Mismatch missing references for \(check.table).\(check.column) -> \(check.referencedTable)"
            )
        }
    }

    func testMergeTableSetMatchesInputs() throws {
        let fixtureNames = [
            "Test-RandomStuff-2026.01.11_12-36-33-+0200",
            "Test-RandomStuff-2026.01.11_14-12-06-+0200",
            "Test-Kickstarter-Framework-iOS-2026.01.11_21-21-05-+0200",
        ]
        let fixtureURLs = fixtureNames.map { fixturesDirectory().appendingPathComponent("\($0).xcresult") }
        let outputURL = try mergeFixtures(fixtureNames)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var expectedTables = Set<String>()
        for fixtureURL in fixtureURLs {
            let dbURL = fixtureURL.appendingPathComponent("database.sqlite3")
            expectedTables.formUnion(try tableNames(in: dbURL))
        }

        let outputDB = outputURL.appendingPathComponent("database.sqlite3")
        let mergedTables = Set(try tableNames(in: outputDB))
        XCTAssertEqual(mergedTables, expectedTables, "Mismatch merged table set")
    }

    func testMergeXCResultToolParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtureNames = [
            "Test-RandomStuff-2026.01.11_12-36-33-+0200",
            "Test-RandomStuff-2026.01.11_14-12-06-+0200",
            "Test-Kickstarter-Framework-iOS-2026.01.11_21-21-05-+0200",
        ]
        let outputURL = try mergeFixtures(fixtureNames)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let commands: [XCResulttoolCommand] = [.summary, .tests, .insights, .metrics]
        do {
            for command in commands {
                let expected = try xcresulttoolJSON(
                    xcrunURL: xcrunURL,
                    fixtureURL: outputURL,
                    command: command
                )
                let actual = try openXcresultOutput(
                    fixturePath: outputURL.path,
                    command: command
                )

                let normalizedActual = try normalizedParityJSON(actual, command: command)
                let normalizedExpected = try normalizedParityJSON(expected, command: command)

                XCTAssertEqual(
                    normalizedActual,
                    normalizedExpected,
                    "Mismatch for merged bundle (\(command.rawValue))"
                )
            }

            let expectedBuild = try xcresulttoolBuildResultsJSON(
                xcrunURL: xcrunURL,
                fixtureURL: outputURL
            )
            let actualBuild = try openXcresultBuildResultsOutput(
                fixturePath: outputURL.path
            )
            XCTAssertEqual(
                try normalizedJSON(actualBuild),
                try normalizedJSON(expectedBuild),
                "Mismatch for merged bundle (build-results)"
            )

            let expectedAvailability = try xcresulttoolContentAvailabilityJSON(
                xcrunURL: xcrunURL,
                fixtureURL: outputURL
            )
            let actualAvailability = try openXcresultContentAvailabilityOutput(
                fixturePath: outputURL.path
            )
            XCTAssertEqual(
                try normalizedJSON(actualAvailability),
                try normalizedJSON(expectedAvailability),
                "Mismatch for merged bundle (content-availability)"
            )
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool failed for merged bundle: \(error.message)")
        }
    }

    func testXCResultToolContentAvailabilityParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        for fixtureURL in fixtures {
            let expected = try xcresulttoolContentAvailabilityJSON(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL
            )
            let actual = try openXcresultContentAvailabilityOutput(
                fixturePath: fixtureURL.path
            )

            let normalizedActual = try normalizedJSON(actual)
            let normalizedExpected = try normalizedJSON(expected)

            XCTAssertEqual(
                normalizedActual,
                normalizedExpected,
                "Mismatch for fixture \(fixtureURL.lastPathComponent) (content-availability)"
            )
        }
    }

    func testXCResultToolDiagnosticsExportParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        for fixtureURL in fixtures {
            let baseURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            let expectedURL = baseURL.appendingPathComponent("expected")
            let actualURL = baseURL.appendingPathComponent("actual")

            try FileManager.default.createDirectory(at: expectedURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: actualURL, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: baseURL)
            }

            try xcresulttoolExportDiagnostics(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL,
                outputURL: expectedURL
            )
            try openXcresultExportDiagnostics(
                fixturePath: fixtureURL.path,
                outputURL: actualURL
            )

            let expectedFiles = try collectFiles(at: expectedURL)
            let actualFiles = try collectFiles(at: actualURL)

            XCTAssertEqual(
                Set(expectedFiles.keys),
                Set(actualFiles.keys),
                "Mismatch diagnostics file list for fixture \(fixtureURL.lastPathComponent)"
            )

            for (path, expectedData) in expectedFiles {
                let actualData = actualFiles[path]
                XCTAssertEqual(
                    actualData,
                    expectedData,
                    "Mismatch diagnostics file contents for \(fixtureURL.lastPathComponent): \(path)"
                )
            }
        }
    }

    func testXCResultToolExportObjectParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        var selectedFixture: URL?
        var objectId: String?
        for fixtureURL in fixtures {
            if let diagnosticsId = try diagnosticsDirectoryId(fixtureURL: fixtureURL) {
                selectedFixture = fixtureURL
                objectId = diagnosticsId
                break
            }
        }

        guard let fixtureURL = selectedFixture, let objectId else {
            throw XCTSkip("No diagnostics directory available for export object parity.")
        }

        do {
            try assertObjectExportParity(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL,
                objectId: objectId
            )
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool export object failed: \(error.message)")
        }
    }

    func testXCResultToolGraphParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        do {
            for fixtureURL in fixtures {
                let expected = try xcresulttoolGraphOutput(
                    xcrunURL: xcrunURL,
                    fixtureURL: fixtureURL
                )
                let actual = try openXcresultGraphOutput(
                    fixturePath: fixtureURL.path
                )

                let normalizedActual = normalizedGraphSignatures(actual)
                let normalizedExpected = normalizedGraphSignatures(expected)
                XCTAssertEqual(
                    normalizedActual,
                    normalizedExpected,
                    "Mismatch graph for fixture \(fixtureURL.lastPathComponent)"
                )
            }
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool graph failed: \(error.message)")
        }
    }

    func testXCResultToolFormatDescriptionParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        do {
            let expected = try xcresulttoolFormatDescriptionOutput(
                xcrunURL: xcrunURL,
                includeEventStreamTypes: false,
                hash: false
            )
            let actual = try openXcresultFormatDescriptionOutput(
                includeEventStreamTypes: false,
                hash: false
            )
            XCTAssertEqual(
                try normalizedJSON(actual),
                try normalizedJSON(expected),
                "Mismatch formatDescription output"
            )

            let expectedEvent = try xcresulttoolFormatDescriptionOutput(
                xcrunURL: xcrunURL,
                includeEventStreamTypes: true,
                hash: false
            )
            let actualEvent = try openXcresultFormatDescriptionOutput(
                includeEventStreamTypes: true,
                hash: false
            )
            XCTAssertEqual(
                try normalizedJSON(actualEvent),
                try normalizedJSON(expectedEvent),
                "Mismatch formatDescription output with event stream types"
            )

            let expectedHash = try xcresulttoolFormatDescriptionOutput(
                xcrunURL: xcrunURL,
                includeEventStreamTypes: false,
                hash: true
            )
            let actualHash = try openXcresultFormatDescriptionOutput(
                includeEventStreamTypes: false,
                hash: true
            )
            XCTAssertEqual(
                normalizedText(actualHash),
                normalizedText(expectedHash),
                "Mismatch formatDescription hash output"
            )
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool formatDescription failed: \(error.message)")
        }
    }

    func testXCResultToolFormatDescriptionDiffParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let baseURL = root.appendingPathComponent("Sources")
            .appendingPathComponent("OpenXCRestult")
            .appendingPathComponent("Resources")
        let originalURL = baseURL.appendingPathComponent("formatDescription.json")
        let eventURL = baseURL.appendingPathComponent("formatDescription-event-stream.json")

        do {
            let expectedText = try xcresulttoolFormatDescriptionDiffOutput(
                xcrunURL: xcrunURL,
                format: "text",
                fromURL: originalURL,
                toURL: eventURL
            )
            let actualText = try openXcresultFormatDescriptionDiffOutput(
                format: "text",
                fromURL: originalURL,
                toURL: eventURL
            )
            XCTAssertEqual(
                normalizedFormatDescriptionDiff(expectedText),
                normalizedFormatDescriptionDiff(actualText),
                "Mismatch formatDescription diff (text)"
            )

            let expectedMarkdown = try xcresulttoolFormatDescriptionDiffOutput(
                xcrunURL: xcrunURL,
                format: "markdown",
                fromURL: originalURL,
                toURL: eventURL
            )
            let actualMarkdown = try openXcresultFormatDescriptionDiffOutput(
                format: "markdown",
                fromURL: originalURL,
                toURL: eventURL
            )
            XCTAssertEqual(
                normalizedFormatDescriptionDiff(expectedMarkdown),
                normalizedFormatDescriptionDiff(actualMarkdown),
                "Mismatch formatDescription diff (markdown)"
            )
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool formatDescription diff failed: \(error.message)")
        }
    }

    func testXCResultToolCompareParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let baselineURL = fixturesDirectory()
            .appendingPathComponent("Test-RandomStuff-2026.01.11_12-36-33-+0200.xcresult")
        let currentURL = fixturesDirectory()
            .appendingPathComponent("Test-RandomStuff-2026.01.11_14-12-06-+0200.xcresult")

        do {
            let expected = try xcresulttoolCompareOutput(
                xcrunURL: xcrunURL,
                comparisonURL: currentURL,
                baselineURL: baselineURL,
                flags: []
            )
            let actual = try openXcresultCompareOutput(
                comparisonURL: currentURL,
                baselineURL: baselineURL,
                flags: []
            )

            XCTAssertEqual(
                try normalizedJSON(actual),
                try normalizedJSON(expected),
                "Mismatch compare output"
            )
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool compare failed: \(error.message)")
        }
    }

    func testXCResultToolAttachmentsExportParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        for fixtureURL in fixtures {
            try assertAttachmentsExportParity(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL,
                testId: nil,
                onlyFailures: false
            )
        }

        let filteredFixture = fixturesDirectory()
            .appendingPathComponent("Test-RandomStuff-2026.01.11_12-36-33-+0200.xcresult")
        try assertAttachmentsExportParity(
            xcrunURL: xcrunURL,
            fixtureURL: filteredFixture,
            testId: "RandomStuffUITestsLaunchTests/testLaunch",
            onlyFailures: false
        )
    }

    func testXCResultToolMetricsExportParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        for fixtureURL in fixtures {
            try assertMetricsExportParity(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL,
                testId: nil
            )
        }

        let filteredFixture = fixturesDirectory()
            .appendingPathComponent("Test-RandomStuff-2026.01.11_12-36-33-+0200.xcresult")
        try assertMetricsExportParity(
            xcrunURL: xcrunURL,
            fixtureURL: filteredFixture,
            testId: "RandomStuffUITests/testLaunchPerformance()"
        )
    }

    func testXCResultToolMetadataParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        do {
            for fixtureURL in fixtures {
                let expected = try xcresulttoolMetadataJSON(
                    xcrunURL: xcrunURL,
                    fixtureURL: fixtureURL
                )
                let actual = try openXcresultMetadataOutput(
                    fixturePath: fixtureURL.path
                )

                let normalizedActual = try normalizedJSON(actual)
                let normalizedExpected = try normalizedJSON(expected)

                XCTAssertEqual(
                    normalizedActual,
                    normalizedExpected,
                    "Mismatch metadata for fixture \(fixtureURL.lastPathComponent)"
                )
            }
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool metadata get failed: \(error.message)")
        }
    }

    func testXCResultToolMetadataAddExternalLocationParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtureURL = fixturesDirectory()
            .appendingPathComponent("Test-RandomStuff-2026.01.11_12-36-33-+0200.xcresult")
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let expectedURL = baseURL.appendingPathComponent("expected.xcresult")
        let actualURL = baseURL.appendingPathComponent("actual.xcresult")

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("Fixture not found at \(fixtureURL.path)")
        }

        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixtureURL, to: expectedURL)
        try FileManager.default.copyItem(at: fixtureURL, to: actualURL)
        defer {
            try? FileManager.default.removeItem(at: baseURL)
        }

        do {
            try xcresulttoolAddExternalLocation(
                xcrunURL: xcrunURL,
                bundleURL: expectedURL,
                identifier: "testid",
                link: "https://example.com",
                description: "Example"
            )
        } catch let error as ProcessFailure {
            throw XCTSkip("xcresulttool metadata addExternalLocation failed: \(error.message)")
        }

        try openXcresultAddExternalLocation(
            bundleURL: actualURL,
            identifier: "testid",
            link: "https://example.com",
            description: "Example"
        )

        let expectedPlist = try normalizedPlistJSON(at: expectedURL.appendingPathComponent("Info.plist"))
        let actualPlist = try normalizedPlistJSON(at: actualURL.appendingPathComponent("Info.plist"))
        XCTAssertEqual(
            actualPlist,
            expectedPlist,
            "Mismatch Info.plist after metadata addExternalLocation"
        )
    }

    func testXCResultToolTestDetailsParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let snapshots = [
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffUITestsLaunchTests/testLaunch",
                snapshotSuffix: "test-details.testLaunch"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffUITests/testLaunchPerformance()",
                snapshotSuffix: "test-details.testLaunchPerformance"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffTests/testExample()",
                snapshotSuffix: "test-details.testExample"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testExpectedFailure()",
                snapshotSuffix: "test-details.testExpectedFailure"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testExpectedFailure2()",
                snapshotSuffix: "test-details.testExpectedFailure2"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testFoo()",
                snapshotSuffix: "test-details.testFoo"
            ),
            TestDetailsSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testSkippedTest()",
                snapshotSuffix: "test-details.testSkippedTest"
            ),
        ]

        for snapshot in snapshots {
            let fixtureURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).xcresult")
            let expected = try xcresulttoolJSON(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL,
                command: .testDetails,
                testId: snapshot.testId
            )
            let actual = try openXcresultOutput(
                fixturePath: fixtureURL.path,
                command: .testDetails,
                testId: snapshot.testId
            )

            let normalizedActual = try normalizedParityJSON(actual, command: .testDetails)
            let normalizedExpected = try normalizedParityJSON(expected, command: .testDetails)

            XCTAssertEqual(
                normalizedActual,
                normalizedExpected,
                "Mismatch for fixture \(snapshot.fixtureName) (\(snapshot.snapshotSuffix))"
            )
        }
    }

    func testXCResultToolActivitiesParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let snapshots = [
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffUITestsLaunchTests/testLaunch",
                snapshotSuffix: "activities.testLaunch"
            ),
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_12-36-33-+0200",
                testId: "RandomStuffTests/testExample()",
                snapshotSuffix: "activities.testExample"
            ),
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testFoo()",
                snapshotSuffix: "activities.testFoo"
            ),
            ActivitiesSnapshot(
                fixtureName: "Test-RandomStuff-2026.01.11_14-12-06-+0200",
                testId: "RandomStuffTests/testExpectedFailure()",
                snapshotSuffix: "activities.testExpectedFailure"
            ),
        ]

        for snapshot in snapshots {
            let fixtureURL = fixturesDirectory().appendingPathComponent("\(snapshot.fixtureName).xcresult")
            let expected = try xcresulttoolJSON(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL,
                command: .activities,
                testId: snapshot.testId
            )
            let actual = try openXcresultOutput(
                fixturePath: fixtureURL.path,
                command: .activities,
                testId: snapshot.testId
            )

            let normalizedActual = try normalizedParityJSON(actual, command: .activities)
            let normalizedExpected = try normalizedParityJSON(expected, command: .activities)

            XCTAssertEqual(
                normalizedActual,
                normalizedExpected,
                "Mismatch for fixture \(snapshot.fixtureName) (\(snapshot.snapshotSuffix))"
            )
        }
    }

    func testXCResultToolLogParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let logTypes: [XCResulttoolLogType] = [.build, .action, .console]
        let fixtures = try fixtureBundles()

        for fixtureURL in fixtures {
            for logType in logTypes {
                do {
                    let expected = try xcresulttoolLogJSON(
                        xcrunURL: xcrunURL,
                        fixtureURL: fixtureURL,
                        logType: logType
                    )
                    let actual = try openXcresultLogOutput(
                        fixturePath: fixtureURL.path,
                        logType: logType
                    )

                    let normalizedActual = try normalizedJSON(actual)
                    let normalizedExpected = try normalizedJSON(expected)

                    XCTAssertEqual(
                        normalizedActual,
                        normalizedExpected,
                        "Mismatch for fixture \(fixtureURL.lastPathComponent) (log \(logType.rawValue))"
                    )
                } catch {
                    XCTAssertThrowsError(
                        try openXcresultLogOutput(fixturePath: fixtureURL.path, logType: logType),
                        "Expected log error for \(fixtureURL.lastPathComponent) (log \(logType.rawValue))"
                    )
                }
            }
        }
    }

    func testXCResultToolObjectParity() throws {
        guard let xcrunURL = resolveXcrun() else {
            throw XCTSkip("xcrun not available on this system.")
        }

        let fixtures = try fixtureBundles()
        for fixtureURL in fixtures {
            let expected = try xcresulttoolObjectJSON(
                xcrunURL: xcrunURL,
                fixtureURL: fixtureURL,
                id: nil
            )
            let actual = try openXcresultObjectOutput(
                fixturePath: fixtureURL.path,
                id: nil
            )

            let normalizedActual = try normalizedJSON(actual)
            let normalizedExpected = try normalizedJSON(expected)

            XCTAssertEqual(
                normalizedActual,
                normalizedExpected,
                "Mismatch for fixture \(fixtureURL.lastPathComponent) (object)"
            )

            let expectedObject = try JSONSerialization.jsonObject(with: expected, options: [])
            let referenceId = logReferenceId(in: expectedObject) ?? firstReferenceId(in: expectedObject)
            if let referenceId {
                let expectedReference = try xcresulttoolObjectJSON(
                    xcrunURL: xcrunURL,
                    fixtureURL: fixtureURL,
                    id: referenceId
                )
                let actualReference = try openXcresultObjectOutput(
                    fixturePath: fixtureURL.path,
                    id: referenceId
                )

                let normalizedRefActual = try normalizedJSON(actualReference)
                let normalizedRefExpected = try normalizedJSON(expectedReference)

                XCTAssertEqual(
                    normalizedRefActual,
                    normalizedRefExpected,
                    "Mismatch for fixture \(fixtureURL.lastPathComponent) (object id)"
                )
            }
        }
    }

    private func fixturesDirectory() -> URL {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return root.appendingPathComponent("Tests").appendingPathComponent("Fixtures")
    }

    private func fixtureBundles() throws -> [URL] {
        let directory = fixturesDirectory()
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return contents
            .filter { $0.pathExtension == "xcresult" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func assertMergedRowsAndData(fixtureNames: [String]) throws {
        let outputURL = try mergeFixtures(fixtureNames)
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let outputDB = outputURL.appendingPathComponent("database.sqlite3")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDB.path))

        let tables = try tableNames(in: outputDB)
        let fixtureURLs = fixtureNames.map { fixturesDirectory().appendingPathComponent("\($0).xcresult") }
        for table in tables {
            var expectedCount: Int64 = 0
            for fixtureURL in fixtureURLs {
                expectedCount += try rowCount(
                    in: fixtureURL.appendingPathComponent("database.sqlite3"),
                    table: table
                )
            }
            let actualCount = try rowCount(in: outputDB, table: table)
            XCTAssertEqual(actualCount, expectedCount, "Mismatch merged row count for table \(table)")
        }

        var expectedDataFiles = Set<String>()
        for fixtureURL in fixtureURLs {
            expectedDataFiles.formUnion(try dataFileNames(in: fixtureURL))
        }
        let actualDataFiles = try dataFileNames(in: outputURL)
        XCTAssertEqual(actualDataFiles, expectedDataFiles, "Mismatch merged Data directory contents")
    }

    private func mergeFixtures(_ fixtureNames: [String]) throws -> URL {
        let fixtureURLs = fixtureNames.map { fixturesDirectory().appendingPathComponent("\($0).xcresult") }
        for fixtureURL in fixtureURLs {
            guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
                throw XCTSkip("Fixture not found at \(fixtureURL.path)")
            }
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("merged-\(UUID().uuidString).xcresult")
        let builder = MergeBuilder(
            inputPaths: fixtureURLs.map { $0.path },
            outputPath: outputURL.path
        )
        try builder.merge()
        return outputURL
    }

    private func tableNames(in databaseURL: URL) throws -> [String] {
        let database = try SQLiteDatabase(path: databaseURL.path)
        let names = try database.query(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
            ORDER BY name;
            """
        ) { statement in
            SQLiteDatabase.string(statement, 0) ?? ""
        }
        return names.filter { !$0.isEmpty }
    }

    private func rowCount(in databaseURL: URL, table: String) throws -> Int64 {
        let database = try SQLiteDatabase(path: databaseURL.path)
        let count = try database.queryOne("SELECT COUNT(*) FROM \"\(table)\";") { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        return Int64(count)
    }

    private struct ForeignKeyDefinition {
        let table: String
        let fromColumn: String
        let referenceTable: String
        let referenceColumn: String
    }

    private struct ForeignKeyCheck {
        let table: String
        let column: String
        let referencedTable: String
        let referencedColumn: String

        init(
            table: String,
            column: String,
            referencedTable: String,
            referencedColumn: String = "rowid"
        ) {
            self.table = table
            self.column = column
            self.referencedTable = referencedTable
            self.referencedColumn = referencedColumn
        }
    }

    private func foreignKeyDefinitions(in databaseURL: URL, table: String) throws -> [ForeignKeyDefinition] {
        let database = try SQLiteDatabase(path: databaseURL.path)
        let foreignKeys = try database.query("PRAGMA foreign_key_list(\"\(table)\");") { statement in
            ForeignKeyDefinition(
                table: table,
                fromColumn: SQLiteDatabase.string(statement, 3) ?? "",
                referenceTable: SQLiteDatabase.string(statement, 2) ?? "",
                referenceColumn: SQLiteDatabase.string(statement, 4) ?? ""
            )
        }
        return foreignKeys.filter {
            !$0.fromColumn.isEmpty && !$0.referenceTable.isEmpty && !$0.referenceColumn.isEmpty
        }
    }

    private func foreignKeyMissingReferenceCount(in databaseURL: URL) throws -> Int64 {
        let tables = try tableNames(in: databaseURL)
        var missing: Int64 = 0
        let database = try SQLiteDatabase(path: databaseURL.path)

        for table in tables {
            let foreignKeys = try foreignKeyDefinitions(in: databaseURL, table: table)
            for foreignKey in foreignKeys {
                let sql = """
                SELECT COUNT(*)
                FROM "\(foreignKey.table)"
                WHERE "\(foreignKey.fromColumn)" IS NOT NULL
                  AND "\(foreignKey.fromColumn)" NOT IN (
                    SELECT "\(foreignKey.referenceColumn)" FROM "\(foreignKey.referenceTable)"
                  );
                """
                let count = try database.queryOne(sql) { statement in
                    SQLiteDatabase.int(statement, 0) ?? 0
                } ?? 0
                missing += Int64(count)
            }
        }
        return missing
    }

    private func missingReferenceCount(in databaseURL: URL, check: ForeignKeyCheck) throws -> Int64 {
        let database = try SQLiteDatabase(path: databaseURL.path)
        let sql = """
        SELECT COUNT(*)
        FROM "\(check.table)"
        WHERE "\(check.column)" IS NOT NULL
          AND "\(check.column)" NOT IN (
            SELECT "\(check.referencedColumn)" FROM "\(check.referencedTable)"
          );
        """
        let count = try database.queryOne(sql) { statement in
            SQLiteDatabase.int(statement, 0) ?? 0
        } ?? 0
        return Int64(count)
    }

    private func dataFileNames(in bundleURL: URL) throws -> Set<String> {
        let dataURL = bundleURL.appendingPathComponent("Data")
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            return []
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: dataURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        var names = Set<String>()
        for fileURL in contents {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            names.insert(fileURL.lastPathComponent)
        }
        return names
    }

    private func assertMatchesSnapshots(
        suffix: String,
        build: (String) throws -> Data
    ) throws {
        let fixtureNames = [
            "Test-RandomStuff-2026.01.11_12-36-33-+0200",
            "Test-RandomStuff-2026.01.11_13-41-16-+0200",
            "Test-RandomStuff-2026.01.11_14-12-06-+0200",
            "Test-Kickstarter-Framework-iOS-2026.01.11_21-21-05-+0200",
        ]

        for fixtureName in fixtureNames {
            let fixtureURL = fixturesDirectory().appendingPathComponent("\(fixtureName).xcresult")
            let snapshotURL = fixturesDirectory().appendingPathComponent("\(fixtureName).\(suffix).json")

            let actual = try build(fixtureURL.path)
            let expected = try Data(contentsOf: snapshotURL)

            let normalizedActual = try normalizedJSON(actual)
            let normalizedExpected = try normalizedJSON(expected)

            XCTAssertEqual(normalizedActual, normalizedExpected, "Mismatch for fixture \(fixtureName) (\(suffix))")
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        if #available(macOS 10.15, *) {
            encoder.outputFormatting = [.withoutEscapingSlashes]
        }
        return try encoder.encode(value)
    }

    private func normalizedJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func normalizedText(_ data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedGraphSignatures(_ data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var signatures: [String] = []
        var currentType: String?
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("* ") {
                currentType = String(trimmed.dropFirst(2))
            } else if trimmed.hasPrefix("- Id: ") {
                guard let type = currentType else { continue }
                let id = String(trimmed.dropFirst(6))
                signatures.append("\(type)|\(id)")
                currentType = nil
            }
        }
        return signatures.sorted()
    }

    private func normalizedFormatDescriptionDiff(_ data: Data) -> FormatDescriptionDiffSignature {
        guard let text = String(data: data, encoding: .utf8) else {
            return FormatDescriptionDiffSignature(versionLine: "", changes: [])
        }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let versionLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var changes: [String] = []
        for line in lines {
            if line.hasPrefix("* ") || line.hasPrefix("- ") {
                changes.append(String(line.dropFirst(2)))
            }
        }
        return FormatDescriptionDiffSignature(
            versionLine: versionLine,
            changes: changes.sorted()
        )
    }

    private func normalizedParityJSON(_ data: Data, command: XCResulttoolCommand) throws -> Data {
        switch command {
        case .insights:
            return try normalizedInsightsJSON(data)
        case .testDetails:
            return try normalizedTestDetailsJSON(data)
        case .activities:
            return try normalizedActivitiesJSON(data)
        default:
            return try normalizedJSON(data)
        }
    }

    private func normalizedInsightsJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard var dict = object as? [String: Any] else {
            return try normalizedJSON(data)
        }

        dict["commonFailureInsights"] = normalizeInsightsArray(dict["commonFailureInsights"])
        dict["failureDistributionInsights"] = normalizeInsightsArray(dict["failureDistributionInsights"])
        dict["longestTestRunsInsights"] = normalizeInsightsArray(dict["longestTestRunsInsights"])

        return try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }

    private func normalizedTestDetailsJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard var dict = object as? [String: Any] else {
            return try normalizedJSON(data)
        }

        if var arguments = dict["arguments"] as? [[String: Any]] {
            arguments.sort {
                let left = $0["value"] as? String ?? ""
                let right = $1["value"] as? String ?? ""
                return left < right
            }
            dict["arguments"] = arguments
        }

        return try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }

    private func normalizedActivitiesJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard var dict = object as? [String: Any] else {
            return try normalizedJSON(data)
        }

        if var testRuns = dict["testRuns"] as? [[String: Any]] {
            for index in testRuns.indices {
                if var arguments = testRuns[index]["arguments"] as? [[String: Any]] {
                    arguments.sort {
                        let left = $0["value"] as? String ?? ""
                        let right = $1["value"] as? String ?? ""
                        return left < right
                    }
                    testRuns[index]["arguments"] = arguments
                }
            }
            dict["testRuns"] = testRuns
        }

        return try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }

    private func normalizeInsightsArray(_ value: Any?) -> Any {
        guard var array = value as? [[String: Any]] else { return value ?? [] }

        for index in array.indices {
            if var identifiers = array[index]["associatedTestIdentifiers"] as? [String] {
                identifiers.sort()
                array[index]["associatedTestIdentifiers"] = identifiers
            }
        }

        array.sort {
            let left = $0["title"] as? String ?? ""
            let right = $1["title"] as? String ?? ""
            return left < right
        }

        return array
    }

    private func resolveXcrun() -> URL? {
        let path = "/usr/bin/xcrun"
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func xcresulttoolJSON(
        xcrunURL: URL,
        fixtureURL: URL,
        command: XCResulttoolCommand,
        testId: String? = nil
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        var arguments = [
            "xcresulttool",
            "get",
            "test-results",
            command.rawValue,
            "--path",
            fixtureURL.path,
            "--format",
            "json"
        ]
        if let testId {
            arguments.append(contentsOf: ["--test-id", testId])
        }
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool failed for \(fixtureURL.lastPathComponent) (\(command.rawValue)): \(error)")
        }

        return output
    }

    private func xcresulttoolLogJSON(
        xcrunURL: URL,
        fixtureURL: URL,
        logType: XCResulttoolLogType
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "get",
            "log",
            "--path",
            fixtureURL.path,
            "--format",
            "json",
            "--type",
            logType.rawValue
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool log failed for \(fixtureURL.lastPathComponent) (\(logType.rawValue)): \(error)")
        }

        return output
    }

    private func xcresulttoolBuildResultsJSON(
        xcrunURL: URL,
        fixtureURL: URL
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "get",
            "build-results",
            "--path",
            fixtureURL.path,
            "--format",
            "json"
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool build-results failed for \(fixtureURL.lastPathComponent): \(error)")
        }

        return output
    }

    private func xcresulttoolContentAvailabilityJSON(
        xcrunURL: URL,
        fixtureURL: URL
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "get",
            "content-availability",
            "--path",
            fixtureURL.path,
            "--format",
            "json"
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool content-availability failed for \(fixtureURL.lastPathComponent): \(error)")
        }

        return output
    }

    private func xcresulttoolExportDiagnostics(
        xcrunURL: URL,
        fixtureURL: URL,
        outputURL: URL
    ) throws {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "export",
            "diagnostics",
            "--path",
            fixtureURL.path,
            "--output-path",
            outputURL.path
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool export diagnostics failed for \(fixtureURL.lastPathComponent): \(error)")
        }
    }

    private func xcresulttoolExportAttachments(
        xcrunURL: URL,
        fixtureURL: URL,
        outputURL: URL,
        testId: String?,
        onlyFailures: Bool
    ) throws {
        let process = Process()
        process.executableURL = xcrunURL
        var arguments = [
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            fixtureURL.path,
            "--output-path",
            outputURL.path
        ]
        if let testId {
            arguments.append(contentsOf: ["--test-id", testId])
        }
        if onlyFailures {
            arguments.append("--only-failures")
        }
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool export attachments failed for \(fixtureURL.lastPathComponent): \(error)")
        }
    }

    private func xcresulttoolExportMetrics(
        xcrunURL: URL,
        fixtureURL: URL,
        outputURL: URL,
        testId: String?
    ) throws {
        let process = Process()
        process.executableURL = xcrunURL
        var arguments = [
            "xcresulttool",
            "export",
            "metrics",
            "--path",
            fixtureURL.path,
            "--output-path",
            outputURL.path
        ]
        if let testId {
            arguments.append(contentsOf: ["--test-id", testId])
        }
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool export metrics failed for \(fixtureURL.lastPathComponent): \(error)")
        }
    }

    private func xcresulttoolExportObject(
        xcrunURL: URL,
        fixtureURL: URL,
        outputURL: URL,
        objectId: String
    ) throws {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "export",
            "object",
            "--legacy",
            "--type",
            "directory",
            "--path",
            fixtureURL.path,
            "--output-path",
            outputURL.path,
            "--id",
            objectId
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool export object failed for \(fixtureURL.lastPathComponent): \(error)")
        }
    }

    private func xcresulttoolGraphOutput(
        xcrunURL: URL,
        fixtureURL: URL
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "graph",
            "--legacy",
            "--path",
            fixtureURL.path
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool graph failed for \(fixtureURL.lastPathComponent): \(error)")
        }

        return output
    }

    private func xcresulttoolFormatDescriptionOutput(
        xcrunURL: URL,
        includeEventStreamTypes: Bool,
        hash: Bool
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        var arguments = [
            "xcresulttool",
            "formatDescription",
            "get",
            "--legacy",
            "--format",
            "json"
        ]
        if includeEventStreamTypes {
            arguments.append("--include-event-stream-types")
        }
        if hash {
            arguments.append("--hash")
        }
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool formatDescription failed: \(error)")
        }

        return output
    }

    private func xcresulttoolFormatDescriptionDiffOutput(
        xcrunURL: URL,
        format: String,
        fromURL: URL,
        toURL: URL
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "formatDescription",
            "diff",
            "--legacy",
            "--format",
            format,
            fromURL.path,
            toURL.path
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool formatDescription diff failed: \(error)")
        }

        return output
    }

    private func xcresulttoolCompareOutput(
        xcrunURL: URL,
        comparisonURL: URL,
        baselineURL: URL,
        flags: [String]
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        var arguments = [
            "xcresulttool",
            "compare",
            comparisonURL.path,
            "--baseline-path",
            baselineURL.path
        ]
        arguments.append(contentsOf: flags)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool compare failed: \(error)")
        }

        return output
    }
    private func xcresulttoolMetadataJSON(
        xcrunURL: URL,
        fixtureURL: URL
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        process.arguments = [
            "xcresulttool",
            "metadata",
            "get",
            "--path",
            fixtureURL.path
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool metadata get failed for \(fixtureURL.lastPathComponent): \(error)")
        }

        return output
    }

    private func xcresulttoolAddExternalLocation(
        xcrunURL: URL,
        bundleURL: URL,
        identifier: String,
        link: String,
        description: String?
    ) throws {
        let process = Process()
        process.executableURL = xcrunURL
        var arguments = [
            "xcresulttool",
            "metadata",
            "addExternalLocation",
            "--path",
            bundleURL.path,
            "--identifier",
            identifier,
            "--link",
            link
        ]
        if let description {
            arguments.append(contentsOf: ["--description", description])
        }
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool metadata addExternalLocation failed for \(bundleURL.lastPathComponent): \(error)")
        }
    }

    private func xcresulttoolObjectJSON(
        xcrunURL: URL,
        fixtureURL: URL,
        id: String?
    ) throws -> Data {
        let process = Process()
        process.executableURL = xcrunURL
        var arguments = [
            "xcresulttool",
            "get",
            "object",
            "--legacy",
            "--path",
            fixtureURL.path,
            "--format",
            "json"
        ]
        if let id {
            arguments.append(contentsOf: ["--id", id])
        }
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let error = String(data: output, encoding: .utf8) ?? ""
            throw ProcessFailure("xcresulttool object failed for \(fixtureURL.lastPathComponent): \(error)")
        }

        return output
    }

    private func openXcresultOutput(
        fixturePath: String,
        command: XCResulttoolCommand,
        testId: String? = nil
    ) throws -> Data {
        switch command {
        case .summary:
            let builder = try TestResultsSummaryBuilder(xcresultPath: fixturePath)
            return try encode(builder.summary())
        case .tests:
            let builder = try TestResultsTestsBuilder(xcresultPath: fixturePath)
            return try encode(builder.tests())
        case .insights:
            let builder = try TestResultsInsightsBuilder(xcresultPath: fixturePath)
            return try encode(builder.insights())
        case .metrics:
            let builder = try TestResultsMetricsBuilder(xcresultPath: fixturePath)
            return try encode(builder.metrics(testId: nil))
        case .testDetails:
            guard let testId else {
                throw ProcessFailure("test-id is required for test-details output.")
            }
            let builder = try TestResultsTestDetailsBuilder(xcresultPath: fixturePath)
            return try encode(builder.testDetails(testId: testId))
        case .activities:
            guard let testId else {
                throw ProcessFailure("test-id is required for activities output.")
            }
            let builder = try TestResultsActivitiesBuilder(xcresultPath: fixturePath)
            return try encode(builder.activities(testId: testId))
        }
    }

    private func openXcresultLogOutput(
        fixturePath: String,
        logType: XCResulttoolLogType
    ) throws -> Data {
        let builder = LogBuilder(xcresultPath: fixturePath)
        return try builder.log(type: logType.toLogType(), compact: false)
    }

    private func openXcresultBuildResultsOutput(
        fixturePath: String
    ) throws -> Data {
        let builder = try BuildResultsBuilder(xcresultPath: fixturePath)
        return try encode(builder.buildResults())
    }

    private func openXcresultContentAvailabilityOutput(
        fixturePath: String
    ) throws -> Data {
        let builder = try ContentAvailabilityBuilder(xcresultPath: fixturePath)
        return try encode(builder.contentAvailability())
    }

    private func openXcresultExportDiagnostics(
        fixturePath: String,
        outputURL: URL
    ) throws {
        let exporter = try DiagnosticsExporter(xcresultPath: fixturePath)
        try exporter.export(to: outputURL.path)
    }

    private func openXcresultExportAttachments(
        fixturePath: String,
        outputURL: URL,
        testId: String?,
        onlyFailures: Bool
    ) throws {
        let exporter = try AttachmentsExporter(xcresultPath: fixturePath)
        try exporter.export(to: outputURL.path, testId: testId, onlyFailures: onlyFailures)
    }

    private func openXcresultExportMetrics(
        fixturePath: String,
        outputURL: URL,
        testId: String?
    ) throws {
        let exporter = try MetricsExporter(xcresultPath: fixturePath)
        try exporter.export(to: outputURL.path, testId: testId)
    }

    private func openXcresultExportObject(
        fixturePath: String,
        outputURL: URL,
        objectId: String
    ) throws {
        let exporter = try ObjectExporter(xcresultPath: fixturePath)
        try exporter.export(id: objectId, type: .directory, to: outputURL.path)
    }

    private func openXcresultGraphOutput(
        fixturePath: String
    ) throws -> Data {
        let builder = try GraphBuilder(xcresultPath: fixturePath)
        return try builder.graph(id: nil)
    }

    private func openXcresultFormatDescriptionOutput(
        includeEventStreamTypes: Bool,
        hash: Bool
    ) throws -> Data {
        let builder = FormatDescriptionBuilder()
        if hash {
            let signature = try builder.signature(includeEventStreamTypes: includeEventStreamTypes)
            return Data((signature + "\n").utf8)
        }
        return try builder.descriptionJSON(includeEventStreamTypes: includeEventStreamTypes)
    }

    private func openXcresultFormatDescriptionDiffOutput(
        format: String,
        fromURL: URL,
        toURL: URL
    ) throws -> Data {
        let builder = FormatDescriptionDiffBuilder()
        let diff = try builder.diff(fromURL: fromURL, toURL: toURL)
        let output: String
        switch format {
        case "markdown":
            output = builder.markdownOutput(diff: diff)
        default:
            output = builder.textOutput(diff: diff)
        }
        return Data((output + "\n").utf8)
    }

    private func openXcresultCompareOutput(
        comparisonURL: URL,
        baselineURL: URL,
        flags: [String]
    ) throws -> Data {
        let builder = try CompareBuilder(
            baselinePath: baselineURL.path,
            currentPath: comparisonURL.path
        )
        let result = try builder.compare()

        var output = CompareOutput()
        if flags.isEmpty {
            output.summary = result.summary
            output.testFailures = result.testFailures
            output.testsExecuted = result.testsExecuted
            output.buildWarnings = result.buildWarnings
            output.analyzerIssues = result.analyzerIssues
        } else {
            if flags.contains("--summary") {
                output.summary = result.summary
            }
            if flags.contains("--test-failures") {
                output.testFailures = result.testFailures
            }
            if flags.contains("--tests") {
                output.testsExecuted = result.testsExecuted
            }
            if flags.contains("--build-warnings") {
                output.buildWarnings = result.buildWarnings
            }
            if flags.contains("--analyzer-issues") {
                output.analyzerIssues = result.analyzerIssues
            }
        }

        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting
        return try encoder.encode(output)
    }

    private func openXcresultMetadataOutput(
        fixturePath: String
    ) throws -> Data {
        let builder = MetadataBuilder(xcresultPath: fixturePath)
        return try builder.metadataJSON(compact: false)
    }

    private func openXcresultAddExternalLocation(
        bundleURL: URL,
        identifier: String,
        link: String,
        description: String?
    ) throws {
        let builder = MetadataBuilder(xcresultPath: bundleURL.path)
        try builder.addExternalLocation(
            identifier: identifier,
            link: link,
            description: description
        )
    }

    private func openXcresultObjectOutput(
        fixturePath: String,
        id: String?
    ) throws -> Data {
        let store = try XCResultFileBackedStore(xcresultPath: fixturePath)
        let objectId = id ?? store.rootId
        let rawValue = try store.loadObject(id: objectId)
        let json = rawValue.toLegacyJSONValue()
        return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
    }

    private func firstReferenceId(in object: Any) -> String? {
        if let dict = object as? [String: Any] {
            if let type = dict["_type"] as? [String: Any],
               type["_name"] as? String == "Reference",
               let idDict = dict["id"] as? [String: Any],
               let value = idDict["_value"] as? String {
                return value
            }
            for value in dict.values {
                if let found = firstReferenceId(in: value) {
                    return found
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let found = firstReferenceId(in: value) {
                    return found
                }
            }
        }
        return nil
    }

    private func logReferenceId(in object: Any) -> String? {
        guard let root = object as? [String: Any],
              let actions = root["actions"] as? [String: Any],
              let values = actions["_values"] as? [Any],
              let first = values.first as? [String: Any] else {
            return nil
        }

        if let actionResult = first["actionResult"] as? [String: Any],
           let logRef = actionResult["logRef"] as? [String: Any],
           let idDict = logRef["id"] as? [String: Any],
           let value = idDict["_value"] as? String {
            return value
        }

        if let buildResult = first["buildResult"] as? [String: Any],
           let logRef = buildResult["logRef"] as? [String: Any],
           let idDict = logRef["id"] as? [String: Any],
           let value = idDict["_value"] as? String {
            return value
        }

        return nil
    }

    private func diagnosticsDirectoryId(fixtureURL: URL) throws -> String? {
        let store = try XCResultFileBackedStore(xcresultPath: fixtureURL.path)
        let root = try store.loadObject(id: store.rootId)
        let actions = root.value(for: "actions")?.arrayValues ?? []
        guard let action = actions.first else { return nil }
        return action
            .value(for: "actionResult")?
            .value(for: "diagnosticsRef")?
            .value(for: "id")?
            .stringValue
    }

    private func collectFiles(at root: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]
        let rootURL = root.resolvingSymlinksInPath()
        let rootPath = rootURL.path
        guard let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return files
        }
        for case let url as URL in enumerator {
            let fileURL = url.resolvingSymlinksInPath()
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let path = fileURL.path
            let relative = path.hasPrefix(rootPath + "/")
                ? String(path.dropFirst(rootPath.count + 1))
                : path
            files[relative] = try Data(contentsOf: fileURL)
        }
        return files
    }

    private func assertObjectExportParity(
        xcrunURL: URL,
        fixtureURL: URL,
        objectId: String
    ) throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let expectedURL = baseURL.appendingPathComponent("expected")
        let actualURL = baseURL.appendingPathComponent("actual")

        try FileManager.default.createDirectory(at: expectedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: actualURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: baseURL)
        }

        try xcresulttoolExportObject(
            xcrunURL: xcrunURL,
            fixtureURL: fixtureURL,
            outputURL: expectedURL,
            objectId: objectId
        )
        try openXcresultExportObject(
            fixturePath: fixtureURL.path,
            outputURL: actualURL,
            objectId: objectId
        )

        let expectedFiles = try collectFiles(at: expectedURL)
        let actualFiles = try collectFiles(at: actualURL)

        XCTAssertEqual(
            Set(expectedFiles.keys),
            Set(actualFiles.keys),
            "Mismatch export object file list for fixture \(fixtureURL.lastPathComponent)"
        )

        for (path, expectedData) in expectedFiles {
            let actualData = actualFiles[path]
            XCTAssertEqual(
                actualData,
                expectedData,
                "Mismatch export object file contents for \(fixtureURL.lastPathComponent): \(path)"
            )
        }
    }

    private func assertAttachmentsExportParity(
        xcrunURL: URL,
        fixtureURL: URL,
        testId: String?,
        onlyFailures: Bool
    ) throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let expectedURL = baseURL.appendingPathComponent("expected")
        let actualURL = baseURL.appendingPathComponent("actual")

        try FileManager.default.createDirectory(at: expectedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: actualURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: baseURL)
        }

        try xcresulttoolExportAttachments(
            xcrunURL: xcrunURL,
            fixtureURL: fixtureURL,
            outputURL: expectedURL,
            testId: testId,
            onlyFailures: onlyFailures
        )
        try openXcresultExportAttachments(
            fixturePath: fixtureURL.path,
            outputURL: actualURL,
            testId: testId,
            onlyFailures: onlyFailures
        )

        var expectedFiles = try collectFiles(at: expectedURL)
        var actualFiles = try collectFiles(at: actualURL)

        let expectedManifest = expectedFiles.removeValue(forKey: "manifest.json")
        let actualManifest = actualFiles.removeValue(forKey: "manifest.json")
        XCTAssertNotNil(expectedManifest, "Missing expected manifest for fixture \(fixtureURL.lastPathComponent)")
        XCTAssertNotNil(actualManifest, "Missing actual manifest for fixture \(fixtureURL.lastPathComponent)")

        if let expectedManifest, let actualManifest {
            let normalizedExpected = try normalizedJSON(expectedManifest)
            let normalizedActual = try normalizedJSON(actualManifest)
            XCTAssertEqual(
                normalizedActual,
                normalizedExpected,
                "Mismatch manifest for fixture \(fixtureURL.lastPathComponent)"
            )
        }

        XCTAssertEqual(
            Set(expectedFiles.keys),
            Set(actualFiles.keys),
            "Mismatch attachments file list for fixture \(fixtureURL.lastPathComponent)"
        )

        for (path, expectedData) in expectedFiles {
            let actualData = actualFiles[path]
            XCTAssertEqual(
                actualData,
                expectedData,
                "Mismatch attachment contents for \(fixtureURL.lastPathComponent): \(path)"
            )
        }
    }

    private func assertMetricsExportParity(
        xcrunURL: URL,
        fixtureURL: URL,
        testId: String?
    ) throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let expectedURL = baseURL.appendingPathComponent("expected")
        let actualURL = baseURL.appendingPathComponent("actual")

        try FileManager.default.createDirectory(at: expectedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: actualURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: baseURL)
        }

        try xcresulttoolExportMetrics(
            xcrunURL: xcrunURL,
            fixtureURL: fixtureURL,
            outputURL: expectedURL,
            testId: testId
        )
        try openXcresultExportMetrics(
            fixturePath: fixtureURL.path,
            outputURL: actualURL,
            testId: testId
        )

        let expectedManifest = try loadMetricsManifest(at: expectedURL)
        let actualManifest = try loadMetricsManifest(at: actualURL)

        let expectedKeys = expectedManifest.map { MetricsManifestKey(identifier: $0.testIdentifier, url: $0.testIdentifierURL) }
        let actualKeys = actualManifest.map { MetricsManifestKey(identifier: $0.testIdentifier, url: $0.testIdentifierURL) }
        XCTAssertEqual(
            expectedKeys.sorted(),
            actualKeys.sorted(),
            "Mismatch metrics manifest entries for fixture \(fixtureURL.lastPathComponent)"
        )

        let expectedFiles = try loadMetricsFiles(from: expectedURL, manifest: expectedManifest)
        let actualFiles = try loadMetricsFiles(from: actualURL, manifest: actualManifest)

        XCTAssertEqual(
            Set(expectedFiles.keys),
            Set(actualFiles.keys),
            "Mismatch metrics file list for fixture \(fixtureURL.lastPathComponent)"
        )

        for (key, expectedData) in expectedFiles {
            let actualData = actualFiles[key]
            XCTAssertEqual(
                actualData,
                expectedData,
                "Mismatch metrics contents for \(fixtureURL.lastPathComponent): \(key.identifier)"
            )
        }
    }

    private func loadMetricsManifest(at outputURL: URL) throws -> [MetricsManifestEntry] {
        let manifestURL = outputURL.appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode([MetricsManifestEntry].self, from: data)
    }

    private func loadMetricsFiles(
        from outputURL: URL,
        manifest: [MetricsManifestEntry]
    ) throws -> [MetricsManifestKey: Data] {
        var results: [MetricsManifestKey: Data] = [:]
        for entry in manifest {
            let key = MetricsManifestKey(identifier: entry.testIdentifier, url: entry.testIdentifierURL)
            let fileURL = resolveMetricsFileURL(baseURL: outputURL, fileName: entry.metricsFileName)
            results[key] = try Data(contentsOf: fileURL)
        }
        return results
    }

    private func resolveMetricsFileURL(baseURL: URL, fileName: String) -> URL {
        let candidate = baseURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        if fileName.hasSuffix(".csv") {
            let trimmed = String(fileName.dropLast(4))
            let trimmedURL = baseURL.appendingPathComponent(trimmed)
            if FileManager.default.fileExists(atPath: trimmedURL.path) {
                return trimmedURL
            }
        }
        return candidate
    }

    private func normalizedPlistJSON(at url: URL) throws -> Data {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        let jsonObject = plistToJSON(plist)
        return try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
    }

    private func plistToJSON(_ value: Any) -> Any {
        if let date = value as? Date {
            return plistDateFormatter().string(from: date)
        }
        if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = plistToJSON(value)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { plistToJSON($0) }
        }
        return value
    }

    private func plistDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }
}

private enum XCResulttoolCommand: String {
    case summary
    case tests
    case insights
    case metrics
    case testDetails = "test-details"
    case activities = "activities"
}

private enum XCResulttoolLogType: String {
    case build
    case action
    case console

    func toLogType() -> LogType {
        LogType(rawValue: rawValue) ?? .build
    }
}

private struct ProcessFailure: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}

private struct TestDetailsSnapshot {
    let fixtureName: String
    let testId: String
    let snapshotSuffix: String
}

private struct ActivitiesSnapshot {
    let fixtureName: String
    let testId: String
    let snapshotSuffix: String
}

private struct MetricsSnapshot {
    let fixtureName: String
    let snapshotSuffix: String
}

private struct MetricsTestIdSnapshot {
    let fixtureName: String
    let testId: String
    let snapshotSuffix: String
}

private struct MetricsManifestEntry: Decodable {
    let metricsFileName: String
    let testIdentifier: String
    let testIdentifierURL: String
}

private struct MetricsManifestKey: Hashable, Comparable {
    let identifier: String
    let url: String

    static func < (lhs: MetricsManifestKey, rhs: MetricsManifestKey) -> Bool {
        if lhs.identifier == rhs.identifier {
            return lhs.url < rhs.url
        }
        return lhs.identifier < rhs.identifier
    }
}

private struct FormatDescriptionDiffSignature: Equatable {
    let versionLine: String
    let changes: [String]
}
