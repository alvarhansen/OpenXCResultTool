import Foundation

public struct FormatDescriptionBuilder {
    public init() {}

    public func descriptionJSON(includeEventStreamTypes: Bool) throws -> Data {
        try loadResource(includeEventStreamTypes: includeEventStreamTypes)
    }

    public func signature(includeEventStreamTypes: Bool) throws -> String {
        let data = try loadResource(includeEventStreamTypes: includeEventStreamTypes)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = object as? [String: Any],
              let signature = dict["signature"] as? String else {
            throw FormatDescriptionError("Missing signature in format description.")
        }
        return signature
    }

    private func loadResource(includeEventStreamTypes: Bool) throws -> Data {
        let name = includeEventStreamTypes
            ? "formatDescription-event-stream"
            : "formatDescription"
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw FormatDescriptionError("Format description resource not found.")
        }
        return try Data(contentsOf: url)
    }
}

struct FormatDescriptionError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
