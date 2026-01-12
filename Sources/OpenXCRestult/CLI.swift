import ArgumentParser
import Foundation

struct OpenXCRestultCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "openxcrestult",
        abstract: "Read xcresult bundles without Xcode tooling.",
        subcommands: [Get.self, Export.self, Metadata.self]
    )
}

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Fetch data from an xcresult bundle.",
        subcommands: [BuildResultsCommand.self, ContentAvailabilityCommand.self, TestResults.self, ObjectCommand.self, LogCommand.self]
    )
}

struct BuildResultsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build-results",
        abstract: "Print the build action details."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try BuildResultsBuilder(xcresultPath: path)
        let results = try builder.buildResults()
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(results)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct ContentAvailabilityCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "content-availability",
        abstract: "Print details about the different types of content contained by the bundle."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try ContentAvailabilityBuilder(xcresultPath: path)
        let availability = try builder.contentAvailability()
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(availability)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export data from an xcresult bundle.",
        subcommands: [DiagnosticsExport.self, AttachmentsExport.self, MetricsExport.self]
    )
}

struct DiagnosticsExport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diagnostics",
        abstract: "Export the diagnostics directory from a result bundle."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("output-path"), help: "Destination path for exported diagnostics.")
    var outputPath: String

    func run() throws {
        let exporter = try DiagnosticsExporter(xcresultPath: path)
        try exporter.export(to: outputPath)
    }
}

struct AttachmentsExport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "attachments",
        abstract: "Export attachments for a given test from a result bundle."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("output-path"), help: "Destination path for exported attachments.")
    var outputPath: String

    @Option(name: .customLong("test-id"), help: "Optional test identifier to filter attachments.")
    var testId: String?

    @Flag(name: .customLong("only-failures"), help: "Export only attachments associated with failures.")
    var onlyFailures = false

    func run() throws {
        let exporter = try AttachmentsExporter(xcresultPath: path)
        try exporter.export(to: outputPath, testId: testId, onlyFailures: onlyFailures)
    }
}

struct MetricsExport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "metrics",
        abstract: "Export CSV file with performance measurements for a given test."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("output-path"), help: "Destination path for exported metrics.")
    var outputPath: String

    @Option(name: .customLong("test-id"), help: "Optional test identifier to filter metrics.")
    var testId: String?

    func run() throws {
        let exporter = try MetricsExporter(xcresultPath: path)
        try exporter.export(to: outputPath, testId: testId)
    }
}

struct TestResults: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Test results queries.",
        subcommands: [Summary.self, TestsList.self, TestDetails.self, ActivitiesCommand.self, MetricsCommand.self, InsightsCommand.self]
    )
}

struct Summary: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the test results summary."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try TestResultsSummaryBuilder(xcresultPath: path)
        let summary = try builder.summary()
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(summary)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct TestsList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tests",
        abstract: "Print the tests structure."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try TestResultsTestsBuilder(xcresultPath: path)
        let tests = try builder.tests()
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(tests)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct TestDetails: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test-details",
        abstract: "Print the detailed information about a specific test."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("test-id"), help: "Test identifier from test results.")
    var testId: String

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try TestResultsTestDetailsBuilder(xcresultPath: path)
        let details = try builder.testDetails(testId: testId)
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(details)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct ActivitiesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "activities",
        abstract: "Print the activity trees for a specific test."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("test-id"), help: "Test identifier from test results.")
    var testId: String

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try TestResultsActivitiesBuilder(xcresultPath: path)
        let activities = try builder.activities(testId: testId)
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(activities)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct MetricsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "metrics",
        abstract: "Print the performance metrics for test runs."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("test-id"), help: "Optional test identifier to filter metrics.")
    var testId: String?

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try TestResultsMetricsBuilder(xcresultPath: path)
        let metrics = try builder.metrics(testId: testId)
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(metrics)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct InsightsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "insights",
        abstract: "Print the test insights."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = try TestResultsInsightsBuilder(xcresultPath: path)
        let insights = try builder.insights()
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting

        let data = try encoder.encode(insights)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct LogCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "log",
        abstract: "Print build, action, or console logs."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("type"), help: "Log type (build, action, console).")
    var type: LogType = .build

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard format == "json" else {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = LogBuilder(xcresultPath: path)
        let data = try builder.log(type: type, compact: compact)
        FileHandle.standardOutput.write(data)
        if data.last != 0x0A {
            FileHandle.standardOutput.write(Data([0x0A]))
        }
    }
}

struct Metadata: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Metadata commands.",
        subcommands: [MetadataGet.self]
    )
}

struct MetadataGet: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print metadata."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    func run() throws {
        let builder = MetadataBuilder(xcresultPath: path)
        let data = try builder.metadataJSON(compact: compact)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

struct ObjectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "object",
        abstract: "Print a raw result object by id."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("id"), help: "Object identifier. Defaults to the root object.")
    var id: String?

    @Option(name: .customLong("format"), help: "Output format (json, raw).")
    var format: String = "json"

    @Flag(name: .customLong("compact"), help: "Emit compact JSON output.")
    var compact = false

    @Flag(name: .customLong("legacy"), help: "Use legacy xcresulttool output shape.")
    var legacy = false

    @Option(name: .customLong("version"), help: "Schema version in major.minor.patch format (unsupported).")
    var version: String?

    func run() throws {
        guard version == nil else {
            throw ValidationError("Versioned output is not supported yet.")
        }
        guard format == "json" || format == "raw" else {
            throw ValidationError("Only --format json or raw is supported.")
        }
        if !legacy {
            throw ValidationError("Legacy format is required for object output.")
        }

        let store = try XCResultFileBackedStore(xcresultPath: path)
        let objectId = id ?? store.rootId

        switch format {
        case "raw":
            let data = try store.loadRawObjectData(id: objectId)
            FileHandle.standardOutput.write(data)
            if data.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
        case "json":
            let rawValue = try store.loadObject(id: objectId)
            let json = rawValue.toLegacyJSONValue()
            let options: JSONSerialization.WritingOptions = compact ? [] : [.prettyPrinted]
            let data = try JSONSerialization.data(withJSONObject: json, options: options)
            FileHandle.standardOutput.write(data)
            if data.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
        default:
            break
        }
    }
}

extension LogType: ExpressibleByArgument {}
