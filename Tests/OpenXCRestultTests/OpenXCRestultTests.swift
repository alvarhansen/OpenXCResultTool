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
                let insights = builder.insights()
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

    private func fixturesDirectory() -> URL {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return root.appendingPathComponent("Tests").appendingPathComponent("Fixtures")
    }

    private func assertMatchesSnapshots(
        suffix: String,
        build: (String) throws -> Data
    ) throws {
        let fixtureNames = [
            "Test-RandomStuff-2026.01.11_12-36-33-+0200",
            "Test-RandomStuff-2026.01.11_13-41-16-+0200",
            "Test-RandomStuff-2026.01.11_14-12-06-+0200",
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
