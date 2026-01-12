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
