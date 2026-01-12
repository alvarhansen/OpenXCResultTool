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

    private func openXcresultMetadataOutput(
        fixturePath: String
    ) throws -> Data {
        let builder = MetadataBuilder(xcresultPath: fixturePath)
        return try builder.metadataJSON(compact: false)
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
