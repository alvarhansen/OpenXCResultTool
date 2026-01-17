import Foundation

public struct GraphBuilder {
    private let store: XCResultFileBackedStore
    private let fileManager = FileManager.default

    public init(xcresultPath: String) throws {
        self.store = try XCResultFileBackedStore(xcresultPath: xcresultPath)
    }

    public func graph(id: String?) throws -> Data {
        var lines: [String] = []
        let rootId = id ?? store.rootId
        try appendNode(id: rootId, indent: 0, lines: &lines)
        let output = lines.joined(separator: "\n") + "\n"
        return Data(output.utf8)
    }

    private func appendNode(id: String, indent: Int, lines: inout [String]) throws {
        let indentPrefix = String(repeating: "  ", count: indent)
        let detailPrefix = indentPrefix + "  "
        let size = dataSize(id: id)

        if let directory = try loadDirectoryNode(id: id) {
            lines.append("\(indentPrefix)* CASTree (file or dir)")
            lines.append("\(detailPrefix)- Id: \(id)")
            lines.append("\(detailPrefix)- Size: \(size)")
            lines.append("\(detailPrefix)- Refs: \(directory.refs.count)")
            for (entry, refId) in zip(directory.entries, directory.refs) {
                let entryType = entryTypeDescription(entry.type)
                lines.append("\(detailPrefix)+ \(entry.name) (\(entryType))")
                try appendNode(id: refId, indent: indent + 2, lines: &lines)
            }
            return
        }

        do {
            let object = try store.loadObject(id: id)
            guard let typeName = object.typeName else {
                throw GraphError("Missing type name for id \(id).")
            }
            let refs = collectReferenceIds(from: object)
            lines.append("\(indentPrefix)* \(typeName)")
            lines.append("\(detailPrefix)- Id: \(id)")
            lines.append("\(detailPrefix)- Size: \(size)")
            if !refs.isEmpty {
                lines.append("\(detailPrefix)- Refs: \(refs.count)")
            }
            for refId in refs {
                try appendNode(id: refId, indent: indent + 2, lines: &lines)
            }
            return
        } catch {
            lines.append("\(indentPrefix)* raw")
            lines.append("\(detailPrefix)- Id: \(id)")
            lines.append("\(detailPrefix)- Size: \(size)")
        }
    }

    private func loadDirectoryNode(id: String) throws -> GraphDirectoryNode? {
        let refsURL = store.dataURL.appendingPathComponent("refs.\(id)")
        guard fileManager.fileExists(atPath: refsURL.path) else {
            return nil
        }
        let data = try store.loadRawObjectData(id: id)
        guard isJSONArray(data) else { return nil }
        guard let entries = try? JSONDecoder().decode([GraphDirectoryEntry].self, from: data) else {
            return nil
        }
        let refs = try loadRefs(id: id)
        guard entries.count == refs.count else {
            return nil
        }
        return GraphDirectoryNode(entries: entries, refs: refs)
    }

    private func loadRefs(id: String) throws -> [String] {
        let refsURL = store.dataURL.appendingPathComponent("refs.\(id)")
        let data = try Data(contentsOf: refsURL)
        guard let count = data.first else { return [] }

        let entrySize = 66
        let expectedSize = 1 + Int(count) * entrySize
        guard data.count >= expectedSize else {
            throw GraphError("Invalid refs data for id \(id).")
        }

        var refs: [String] = []
        var offset = 1
        for _ in 0..<count {
            let chunk = data[offset..<offset + entrySize]
            let rawId = Data(chunk[chunk.startIndex.advanced(by: 2)..<chunk.endIndex])
            let base64 = rawId.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
            refs.append("0~\(base64)")
            offset += entrySize
        }
        return refs
    }

    private func isJSONArray(_ data: Data) -> Bool {
        guard let index = data.firstIndex(where: { !Self.jsonWhitespace.contains($0) }) else {
            return false
        }
        return data[index] == 0x5B
    }

    private func dataSize(id: String) -> Int {
        let dataURL = store.dataURL.appendingPathComponent("data.\(id)")
        guard let attributes = try? fileManager.attributesOfItem(atPath: dataURL.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.intValue
    }

    private static let jsonWhitespace: Set<UInt8> = [0x09, 0x0A, 0x0D, 0x20]

    private func collectReferenceIds(from value: XCResultRawValue) -> [String] {
        if value.typeName == "Reference" {
            if let id = value.value(for: "id")?.stringValue {
                return [id]
            }
            return []
        }

        var refs: [String] = []
        let keys = value.fields.keys.sorted()
        for key in keys where !key.hasPrefix("_") {
            if let child = value.fields[key] {
                refs.append(contentsOf: collectReferenceIds(from: child))
            }
        }
        for element in value.elements {
            refs.append(contentsOf: collectReferenceIds(from: element))
        }
        return refs
    }

    private func entryTypeDescription(_ type: Int) -> String {
        switch type {
        case 1:
            return "plainFile"
        case 2:
            return "directory"
        default:
            return "unknown"
        }
    }
}

private struct GraphDirectoryEntry: Decodable {
    let type: Int
    let name: String
}

private struct GraphDirectoryNode {
    let entries: [GraphDirectoryEntry]
    let refs: [String]
}

struct GraphError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
