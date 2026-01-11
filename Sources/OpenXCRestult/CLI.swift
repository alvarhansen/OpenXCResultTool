import Foundation

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct CLI {
    func run() -> Int32 {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.isEmpty || args.contains("--help") || args.contains("-h") {
            printUsage()
            return 0
        }

        guard args.count >= 3 else {
            printUsage()
            return 1
        }

        guard args[0] == "get", args[1] == "test-results", args[2] == "summary" else {
            writeError("Unsupported command. Only `get test-results summary` is available.")
            return 2
        }

        var path: String?
        var compact = false
        var format = "json"

        var index = 3
        while index < args.count {
            let arg = args[index]
            switch arg {
            case "--path":
                guard index + 1 < args.count else {
                    writeError("Missing value for --path.")
                    return 2
                }
                path = args[index + 1]
                index += 2
            case "--compact":
                compact = true
                index += 1
            case "--format":
                guard index + 1 < args.count else {
                    writeError("Missing value for --format.")
                    return 2
                }
                format = args[index + 1]
                index += 2
            case "--schema", "--schema-version":
                writeError("Schema output is not supported yet.")
                return 2
            default:
                writeError("Unknown argument: \(arg)")
                return 2
            }
        }

        guard let path else {
            writeError("Missing required --path argument.")
            return 2
        }
        guard format == "json" else {
            writeError("Only --format json is supported.")
            return 2
        }

        do {
            let builder = try TestResultsSummaryBuilder(xcresultPath: path)
            let summary = try builder.summary()
            let encoder = JSONEncoder()
            if compact {
                encoder.outputFormatting = []
            } else {
                encoder.outputFormatting = [.prettyPrinted]
            }
            let data = try encoder.encode(summary)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0A]))
            return 0
        } catch {
            writeError("Failed to read xcresult: \(error)")
            return 1
        }
    }

    private func printUsage() {
        let usage = """
        Usage:
          openxcrestult get test-results summary --path <bundle.xcresult> [--format json] [--compact]
        """
        print(usage)
    }

    private func writeError(_ message: String) {
        let data = Data((message + "\n").utf8)
        FileHandle.standardError.write(data)
    }
}
