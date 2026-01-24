import ArgumentParser
import Foundation
import OpenXCResultTool

struct OpenXCResultToolCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "openxcresulttool",
        abstract: "Read xcresult bundles without Xcode tooling.",
        subcommands: [Get.self, Export.self, Metadata.self, GraphCommand.self, FormatDescriptionCommand.self, CompareCommand.self, MergeCommand.self, VersionCommand.self]
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
        try writeJSON(results, compact: compact)
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
        try writeJSON(availability, compact: compact)
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Export data from an xcresult bundle.",
        subcommands: [DiagnosticsExport.self, AttachmentsExport.self, MetricsExport.self, ObjectExport.self]
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

struct ObjectExport: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "object",
        abstract: "Export a file or directory represented by an object id."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("output-path"), help: "Destination path for the exported object.")
    var outputPath: String

    @Option(name: .customLong("id"), help: "Object identifier.")
    var id: String

    @Option(name: .customLong("type"), help: "Export type (file or directory).")
    var type: ExportObjectType

    @Flag(name: .customLong("legacy"), help: "Use legacy xcresulttool output behavior.")
    var legacy = false

    func run() throws {
        guard legacy else {
            throw ValidationError("Legacy format is required for object export.")
        }
        let exporter = try ObjectExporter(xcresultPath: path)
        try exporter.export(id: id, type: type.toExportKind(), to: outputPath)
    }
}

enum ExportObjectType: String, ExpressibleByArgument {
    case file
    case directory

    func toExportKind() -> ObjectExportKind {
        ObjectExportKind(rawValue: rawValue) ?? .file
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
        try writeJSON(summary, compact: compact)
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
        try writeJSON(tests, compact: compact)
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
        try writeJSON(details, compact: compact)
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
        try writeJSON(activities, compact: compact)
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
        try writeJSON(metrics, compact: compact)
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
        try writeJSON(insights, compact: compact)
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
        subcommands: [MetadataGet.self, MetadataAddExternalLocation.self]
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

struct MetadataAddExternalLocation: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "addExternalLocation",
        abstract: "Record an external location associated with the result bundle."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("identifier"), help: "External location identifier.")
    var identifier: String

    @Option(name: .customLong("link"), help: "External location link.")
    var link: String

    @Option(name: .customLong("description"), help: "Optional external location description.")
    var description: String?

    func run() throws {
        let builder = MetadataBuilder(xcresultPath: path)
        try builder.addExternalLocation(
            identifier: identifier,
            link: link,
            description: description
        )
    }
}

struct GraphCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "graph",
        abstract: "Print the object graph of the given result bundle."
    )

    @Option(name: .customLong("path"), help: "Path to the .xcresult bundle.")
    var path: String

    @Option(name: .customLong("id"), help: "Optional object identifier to use as the graph root.")
    var id: String?

    @Flag(name: .customLong("legacy"), help: "Use legacy xcresulttool output behavior.")
    var legacy = false

    @Option(name: .customLong("version"), help: "Schema version in major.minor.patch format (unsupported).")
    var version: String?

    func run() throws {
        guard legacy else {
            throw ValidationError("Legacy format is required for graph output.")
        }
        guard version == nil else {
            throw ValidationError("Versioned output is not supported yet.")
        }

        let builder = try GraphBuilder(xcresultPath: path)
        let data = try builder.graph(id: id)
        FileHandle.standardOutput.write(data)
    }
}

struct FormatDescriptionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "formatDescription",
        abstract: "Format description commands.",
        subcommands: [FormatDescriptionGet.self, FormatDescriptionDiff.self],
        defaultSubcommand: FormatDescriptionGet.self
    )
}

struct FormatDescriptionGet: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print a description of the types making up the result bundle."
    )

    @Option(name: .customLong("format"), help: "Output format (json).")
    var format: String = "json"

    @Flag(name: .customLong("hash"), help: "Print only the format description signature hash.")
    var hash = false

    @Flag(name: .customLong("include-event-stream-types"), help: "Include event stream types in the description.")
    var includeEventStreamTypes = false

    @Flag(name: .customLong("legacy"), help: "Use legacy xcresulttool output behavior.")
    var legacy = false

    @Option(name: .customLong("version"), help: "Schema version in major.minor.patch format (unsupported).")
    var version: String?

    func run() throws {
        guard legacy else {
            throw ValidationError("Legacy format is required for formatDescription output.")
        }
        guard version == nil else {
            throw ValidationError("Versioned output is not supported yet.")
        }
        if !hash, format != "json" {
            throw ValidationError("Only --format json is supported.")
        }

        let builder = FormatDescriptionBuilder()
        if hash {
            let signature = try builder.signature(includeEventStreamTypes: includeEventStreamTypes)
            FileHandle.standardOutput.write(Data((signature + "\n").utf8))
        } else {
            let data = try builder.descriptionJSON(includeEventStreamTypes: includeEventStreamTypes)
            FileHandle.standardOutput.write(data)
            if data.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
        }
    }
}

struct FormatDescriptionDiff: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diff",
        abstract: "Compute a list of changes between format descriptions."
    )

    @Option(name: .customLong("format"), help: "Output format (text or markdown).")
    var format: String = "text"

    @Flag(name: .customLong("legacy"), help: "Use legacy xcresulttool output behavior.")
    var legacy = false

    @Argument(help: "Format description JSON files.")
    var paths: [String]

    func run() throws {
        guard legacy else {
            throw ValidationError("Legacy format is required for formatDescription output.")
        }
        guard format == "text" || format == "markdown" else {
            throw ValidationError("Only --format text or markdown is supported.")
        }
        guard paths.count == 2 else {
            throw ValidationError("Exactly two format description files are required.")
        }

        let builder = FormatDescriptionDiffBuilder()
        let diff = try builder.diff(
            fromURL: URL(fileURLWithPath: paths[0]),
            toURL: URL(fileURLWithPath: paths[1])
        )
        let output: String
        switch format {
        case "markdown":
            output = builder.markdownOutput(diff: diff)
        default:
            output = builder.textOutput(diff: diff)
        }
        FileHandle.standardOutput.write(Data((output + "\n").utf8))
    }
}

struct CompareCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "compare",
        abstract: "Compare result bundles."
    )

    @Flag(name: .customLong("schema"), help: "Print output as JSON Schema (unsupported).")
    var schema = false

    @Option(name: .customLong("schema-version"), help: "Schema version in major.minor.patch format (unsupported).")
    var schemaVersion: String?

    @Option(name: .customLong("baseline-path"), help: "Baseline result bundle path.")
    var baselinePath: String

    @Flag(name: .customLong("summary"), help: "Include differential summary info.")
    var summary = false

    @Flag(name: .customLong("test-failures"), help: "Include differential test failures info.")
    var testFailures = false

    @Flag(name: .customLong("tests"), help: "Include differential tests info.")
    var tests = false

    @Flag(name: .customLong("build-warnings"), help: "Include differential build warnings info.")
    var buildWarnings = false

    @Flag(name: .customLong("analyzer-issues"), help: "Include differential analyzer issues info.")
    var analyzerIssues = false

    @Argument(help: "Result bundle path(s) to compare.")
    var comparisonPaths: [String]

    func run() throws {
        guard !schema, schemaVersion == nil else {
            throw ValidationError("Schema output is not supported yet.")
        }
        guard comparisonPaths.count == 1, let comparisonPath = comparisonPaths.first else {
            throw ValidationError("Exactly one comparison path is required.")
        }

        let builder = try CompareBuilder(
            baselinePath: baselinePath,
            currentPath: comparisonPath
        )
        let result = try builder.compare()

        let anyFlag = summary || testFailures || tests || buildWarnings || analyzerIssues
        var output = CompareOutput()
        if anyFlag {
            if summary {
                output.summary = result.summary
            }
            if testFailures {
                output.testFailures = result.testFailures
            }
            if tests {
                output.testsExecuted = result.testsExecuted
            }
            if buildWarnings {
                output.buildWarnings = result.buildWarnings
            }
            if analyzerIssues {
                output.analyzerIssues = result.analyzerIssues
            }
        } else {
            output.summary = result.summary
            output.testFailures = result.testFailures
            output.testsExecuted = result.testsExecuted
            output.buildWarnings = result.buildWarnings
            output.analyzerIssues = result.analyzerIssues
        }

        try writeJSON(output, compact: false)
    }
}

struct MergeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "merge",
        abstract: "Merge multiple xcresult bundles into one."
    )

    @Option(name: .customLong("output-path"), help: "Destination path for the merged .xcresult bundle.")
    var outputPath: String

    @Argument(help: "Result bundle paths to merge.")
    var inputPaths: [String]

    func run() throws {
        guard inputPaths.count >= 2 else {
            throw ValidationError("Two or more result bundle paths are required to merge.")
        }

        let builder = MergeBuilder(inputPaths: inputPaths, outputPath: outputPath)
        try builder.merge()

        let output = "[v3] Merged to: \(outputPath)\n"
        FileHandle.standardOutput.write(Data(output.utf8))
    }
}

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print the version of OpenXCResultTool."
    )

    func run() throws {
        let output = """
        openxcresulttool version \(OpenXCResultToolVersion.tool) (schema version: \(OpenXCResultToolVersion.schema), legacy commands format version: \(OpenXCResultToolVersion.legacyFormat))
        """
        FileHandle.standardOutput.write(Data((output + "\n").utf8))
    }
}

private func makeJSONEncoder(compact: Bool) -> JSONEncoder {
    let encoder = JSONEncoder()
    var formatting: JSONEncoder.OutputFormatting = compact ? [] : [.prettyPrinted]
    if #available(macOS 10.15, *) {
        formatting.insert(.withoutEscapingSlashes)
    }
    encoder.outputFormatting = formatting
    return encoder
}

private func writeJSON<T: Encodable>(_ value: T, compact: Bool) throws {
    let data = try makeJSONEncoder(compact: compact).encode(value)
    writeOutput(data)
}

private func writeOutput(_ data: Data) {
    FileHandle.standardOutput.write(data)
    if data.last != 0x0A {
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
