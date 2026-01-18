import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

public struct MetricsExporter {
    private let context: XCResultContext

    public init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
    }

    public func export(to outputPath: String, testId: String?) throws {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true
        )

        let destination = try loadDestination()
        let rows = try fetchMetricRows(testId: testId)
        let grouped = groupMetrics(rows: rows)

        var manifestEntries: [MetricsManifestEntry] = []
        for group in grouped {
            let csvName = UUID().uuidString + ".csv"
            let csvURL = outputURL.appendingPathComponent(csvName)
            let content = buildCSV(
                destination: destination,
                runs: group.runs
            )
            guard let data = content.data(using: .utf8) else {
                throw MetricsExportError("Unable to encode CSV for \(group.testIdentifier).")
            }
            try data.writeAtomic(to: csvURL)

            manifestEntries.append(
                MetricsManifestEntry(
                    metricsFileName: csvName + ".csv",
                    testIdentifier: group.testIdentifier,
                    testIdentifierURL: group.testIdentifierURL
                )
            )
        }

        try writeManifest(entries: manifestEntries, to: outputURL)
    }

    private func writeManifest(entries: [MetricsManifestEntry], to outputURL: URL) throws {
        let manifestURL = outputURL.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting
        let data = try encoder.encode(entries)
        try data.writeAtomic(to: manifestURL)
    }

    private func loadDestination() throws -> String {
        guard let runDestination = try context.fetchRunDestination(runDestinationId: context.action.runDestinationId),
              let device = try context.fetchDevice(deviceId: runDestination.deviceId),
              let platform = try context.fetchPlatform(platformId: device.platformId) else {
            return ""
        }
        return "\(runDestination.name) \(platform.userDescription) \(device.operatingSystemVersion)"
    }

    private func fetchMetricRows(testId: String?) throws -> [MetricRow] {
        let sql = """
        SELECT TestCases.identifier,
               TestCases.identifierURL,
               TestCaseRuns.rowid,
               TestCaseRuns.orderInTestSuiteRun,
               TestPlanConfigurations.name,
               PerformanceMetrics.displayName,
               PerformanceMetrics.unitOfMeasurement,
               PerformanceMetrics.measurements,
               PerformanceMetrics.baselineAverage,
               PerformanceMetrics.orderInTestCase
        FROM PerformanceMetrics
        JOIN TestCaseRuns ON TestCaseRuns.rowid = PerformanceMetrics.testCaseRun_fk
        JOIN TestCases ON TestCases.rowid = TestCaseRuns.testCase_fk
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestableRuns ON TestableRuns.rowid = TestSuiteRuns.testableRun_fk
        JOIN TestPlanRuns ON TestPlanRuns.rowid = TestableRuns.testPlanRun_fk
        JOIN TestPlanConfigurations ON TestPlanConfigurations.rowid = TestPlanRuns.configuration_fk
        ORDER BY TestCases.identifier, TestCaseRuns.orderInTestSuiteRun, PerformanceMetrics.orderInTestCase;
        """

        let rows = try context.database.query(sql) { statement in
            MetricRow(
                testIdentifier: SQLiteDatabase.string(statement, 0) ?? "",
                testIdentifierURL: SQLiteDatabase.string(statement, 1) ?? "",
                testCaseRunId: SQLiteDatabase.int(statement, 2) ?? 0,
                orderInTestSuiteRun: SQLiteDatabase.int(statement, 3) ?? 0,
                configurationName: SQLiteDatabase.string(statement, 4) ?? "",
                displayName: SQLiteDatabase.string(statement, 5) ?? "",
                unitOfMeasurement: SQLiteDatabase.string(statement, 6) ?? "",
                measurements: SQLiteDatabase.string(statement, 7) ?? "",
                baselineAverage: SQLiteDatabase.double(statement, 8) ?? 0,
                orderInTestCase: SQLiteDatabase.int(statement, 9) ?? 0
            )
        }

        guard let testId else { return rows }
        return rows.filter {
            $0.testIdentifier == testId || $0.testIdentifierURL == testId
        }
    }

    private func groupMetrics(rows: [MetricRow]) -> [MetricsGroup] {
        var groups: [MetricsGroup] = []
        var currentKey: MetricsKey?
        var currentRuns: [MetricsRun] = []

        let sortedRows = rows.sorted {
            if $0.testIdentifier == $1.testIdentifier {
                if $0.orderInTestSuiteRun == $1.orderInTestSuiteRun {
                    return $0.orderInTestCase < $1.orderInTestCase
                }
                return $0.orderInTestSuiteRun < $1.orderInTestSuiteRun
            }
            return $0.testIdentifier < $1.testIdentifier
        }

        for row in sortedRows {
            let key = MetricsKey(
                testIdentifier: row.testIdentifier,
                testIdentifierURL: row.testIdentifierURL
            )
            if currentKey != key {
                if let currentKey {
                    groups.append(
                        MetricsGroup(
                            testIdentifier: currentKey.testIdentifier,
                            testIdentifierURL: currentKey.testIdentifierURL,
                            runs: currentRuns
                        )
                    )
                }
                currentKey = key
                currentRuns = []
            }

            if currentRuns.last?.runId != row.testCaseRunId {
                currentRuns.append(
                    MetricsRun(
                        runId: row.testCaseRunId,
                        configurationName: row.configurationName,
                        metrics: []
                    )
                )
            }

            let values = row.measurements
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            currentRuns[currentRuns.count - 1].metrics.append(
                MetricsValue(
                    displayName: row.displayName,
                    unit: row.unitOfMeasurement,
                    measurements: values,
                    baselineAverage: row.baselineAverage,
                    orderInTestCase: row.orderInTestCase
                )
            )
        }

        if let currentKey {
            groups.append(
                MetricsGroup(
                    testIdentifier: currentKey.testIdentifier,
                    testIdentifierURL: currentKey.testIdentifierURL,
                    runs: currentRuns
                )
            )
        }

        return groups
    }

    private func buildCSV(destination: String, runs: [MetricsRun]) -> String {
        guard let firstRun = runs.first else { return "" }
        let orderedMetrics = firstRun.metrics.sorted { $0.orderInTestCase < $1.orderInTestCase }

        var headers = ["Destination", "Configuration"]
        for metric in orderedMetrics {
            headers.append("\(metric.displayName) (Average)")
            headers.append("\(metric.displayName) (Iterations)")
            headers.append("\(metric.displayName) (Baseline)")
        }

        var rows: [String] = []
        rows.append(csvLine(headers))

        for run in runs {
            var fields: [String] = [destination, run.configurationName]
            for metric in orderedMetrics {
                guard let runMetric = run.metrics.first(where: { $0.displayName == metric.displayName }) else {
                    fields.append("")
                    fields.append("")
                    fields.append("")
                    continue
                }
                let average = averageValue(runMetric.measurements)
                let averageString = formatNumber(average)
                let iterations = "[\(runMetric.measurements.joined(separator: ", "))]"
                let baseline = formatNumber(runMetric.baselineAverage)

                let averageWithUnit = runMetric.unit.isEmpty
                    ? averageString
                    : "\(averageString) \(runMetric.unit)"

                fields.append(averageWithUnit)
                fields.append(iterations)
                fields.append(baseline)
            }
            rows.append(csvLine(fields))
        }

        return rows.joined(separator: "\n")
    }

    private func averageValue(_ measurements: [String]) -> Double {
        let values = measurements.compactMap { Double($0) }
        guard !values.isEmpty else { return 0 }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 10
        formatter.locale = Locale.current
        if let formatted = formatter.string(from: NSNumber(value: value)) {
            return formatted
        }
        return String(value)
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map { "\"\(escapeCSV($0))\"" }.joined(separator: ",")
    }

    private func escapeCSV(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
}

private struct MetricRow {
    let testIdentifier: String
    let testIdentifierURL: String
    let testCaseRunId: Int
    let orderInTestSuiteRun: Int
    let configurationName: String
    let displayName: String
    let unitOfMeasurement: String
    let measurements: String
    let baselineAverage: Double
    let orderInTestCase: Int
}

private struct MetricsKey: Hashable {
    let testIdentifier: String
    let testIdentifierURL: String
}

private struct MetricsGroup {
    let testIdentifier: String
    let testIdentifierURL: String
    let runs: [MetricsRun]
}

private struct MetricsRun {
    let runId: Int
    let configurationName: String
    var metrics: [MetricsValue]
}

private struct MetricsValue {
    let displayName: String
    let unit: String
    let measurements: [String]
    let baselineAverage: Double
    let orderInTestCase: Int
}

struct MetricsManifestEntry: Encodable {
    let metricsFileName: String
    let testIdentifier: String
    let testIdentifierURL: String
}

struct MetricsExportError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
