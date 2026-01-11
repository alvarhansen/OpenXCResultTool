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
