import Foundation

struct LogBuilder {
    let xcresultPath: String

    func log(type: LogType, compact: Bool) throws -> Data {
        let xcrunPath = "/usr/bin/xcrun"
        guard FileManager.default.isExecutableFile(atPath: xcrunPath) else {
            throw LogError("xcrun is required to read logs from xcresult bundles.")
        }

        var arguments = [
            "xcresulttool",
            "get",
            "log",
            "--path",
            xcresultPath,
            "--format",
            "json",
            "--type",
            type.rawValue
        ]
        if compact {
            arguments.append("--compact")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: xcrunPath)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let message = String(data: output, encoding: .utf8) ?? ""
            throw LogError("xcresulttool get log failed: \(message)")
        }

        return output
    }
}

struct LogError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
