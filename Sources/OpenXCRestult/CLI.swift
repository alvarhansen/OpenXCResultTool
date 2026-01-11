import ArgumentParser
import Foundation

struct OpenXCRestultCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "openxcrestult",
        abstract: "Read xcresult bundles without Xcode tooling.",
        subcommands: [Get.self]
    )
}

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Fetch data from an xcresult bundle.",
        subcommands: [TestResults.self]
    )
}

struct TestResults: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Test results queries.",
        subcommands: [Summary.self]
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
