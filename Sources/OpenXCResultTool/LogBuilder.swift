import Foundation

public struct LogBuilder {
    public let xcresultPath: String

    public init(xcresultPath: String) {
        self.xcresultPath = xcresultPath
    }

    public func log(type: LogType, compact: Bool) throws -> Data {
        let store = try XCResultFileBackedStore(xcresultPath: xcresultPath)
        let logId = try resolveLogId(store: store, type: type)
        let rawValue = try store.loadObject(id: logId)
        let dateParser = XCResultDateParser()
        let json = rawValue.toLogJSONValue(dateParser: dateParser)

        let options: JSONSerialization.WritingOptions = compact ? [] : [.prettyPrinted]
        return try JSONSerialization.data(withJSONObject: json, options: options)
    }

    private func resolveLogId(store: XCResultFileBackedStore, type: LogType) throws -> String {
        let root = try store.loadObject(id: store.rootId)
        let actions = root.value(for: "actions")?.arrayValues ?? []
        guard let action = actions.first else {
            throw LogError("No actions found in result bundle.")
        }

        let actionResult = action.value(for: "actionResult")
        let buildResult = action.value(for: "buildResult")
        let logRef: XCResultRawValue?

        switch type {
        case .action:
            logRef = actionResult?.value(for: "logRef")
        case .build:
            logRef = buildResult?.value(for: "logRef")
        case .console:
            logRef = nil
        }

        guard let logRef else {
            throw LogError("No \(type.rawValue) log available.")
        }
        guard let id = logRef.value(for: "id")?.stringValue else {
            throw LogError("Missing log reference id for \(type.rawValue) log.")
        }
        return id
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
