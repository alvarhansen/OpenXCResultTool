import Foundation

public struct XCResultFileBackedStore {
    public let xcresultURL: URL
    public let dataURL: URL
    public let rootId: String

    public init(xcresultPath: String) throws {
        let url = URL(fileURLWithPath: xcresultPath)
        self.xcresultURL = url
        self.dataURL = url.appendingPathComponent("Data")
        self.rootId = try XCResultFileBackedStore.loadRootId(from: url)
    }

    public func loadObject(id: String) throws -> XCResultRawValue {
        let rawData = try loadRawData(id: id)
        var parser = XCResultRawParser(data: rawData)
        return try parser.parse()
    }

    public func loadRawObjectData(id: String) throws -> Data {
        try loadRawData(id: id)
    }

    private func loadRawData(id: String) throws -> Data {
        let dataFile = dataURL.appendingPathComponent("data.\(id)")
        let data = try FileAccess.readData(at: dataFile)
        if data.starts(with: XCResultFileBackedStore.zstdMagic) {
            return try ZstdDecompressor.decompress(data)
        }
        return data
    }

    private static func loadRootId(from url: URL) throws -> String {
        let plistURL = url.appendingPathComponent("Info.plist")
        let data = try FileAccess.readData(at: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plist as? [String: Any],
              let root = dict["rootId"] as? [String: Any],
              let hash = root["hash"] as? String else {
            throw XCResultStoreError("Unable to read rootId from Info.plist.")
        }
        return hash
    }

    private static let zstdMagic: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD]
}

struct XCResultStoreError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
