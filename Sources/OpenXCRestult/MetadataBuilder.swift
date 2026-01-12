import Foundation

struct MetadataBuilder {
    private let plistURL: URL

    init(xcresultPath: String) {
        self.plistURL = MetadataBuilder.infoPlistURL(for: xcresultPath)
    }

    func metadataJSON(compact: Bool) throws -> Data {
        let metadata = try loadMetadata()
        let options: JSONSerialization.WritingOptions = compact ? [] : [.prettyPrinted]
        return try JSONSerialization.data(withJSONObject: metadata, options: options)
    }

    private func loadMetadata() throws -> [String: Any] {
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plist as? [String: Any] else {
            throw MetadataError("Invalid Info.plist metadata.")
        }

        let dateCreated = (dict["dateCreated"] as? Date).map { formatDate($0) } ?? ""
        let externalLocations = dict["externalLocations"] as? [[String: Any]] ?? []
        let rootId = dict["rootId"] as? [String: Any] ?? [:]
        let storage = dict["storage"] as? [String: Any] ?? [:]
        let version = dict["version"] as? [String: Any] ?? [:]

        return [
            "dateCreated": dateCreated,
            "externalLocations": externalLocations,
            "rootId": rootId,
            "storage": storage,
            "version": version
        ]
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.string(from: date)
    }

    private static func infoPlistURL(for path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "xcresult" {
            return url.appendingPathComponent("Info.plist")
        }
        if url.lastPathComponent == "Info.plist" {
            return url
        }
        return url.appendingPathComponent("Info.plist")
    }
}

struct MetadataError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
