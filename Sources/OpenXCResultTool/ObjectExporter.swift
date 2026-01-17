import Foundation

public enum ObjectExportKind: String {
    case file
    case directory
}

public struct ObjectExporter {
    private let store: XCResultFileBackedStore

    public init(xcresultPath: String) throws {
        self.store = try XCResultFileBackedStore(xcresultPath: xcresultPath)
    }

    public func export(id: String, type: ObjectExportKind, to outputPath: String) throws {
        let outputURL = URL(fileURLWithPath: outputPath)
        switch type {
        case .file:
            let data = try store.loadRawObjectData(id: id)
            let parent = outputURL.deletingLastPathComponent()
            if parent.path != outputURL.path {
                try FileManager.default.createDirectory(
                    at: parent,
                    withIntermediateDirectories: true
                )
            }
            try data.write(to: outputURL, options: [.atomic])
        case .directory:
            try FileManager.default.createDirectory(
                at: outputURL,
                withIntermediateDirectories: true
            )
            try exportDirectory(id: id, to: outputURL)
        }
    }

    private func exportDirectory(id: String, to directoryURL: URL) throws {
        let entries = try loadDirectoryEntries(id: id)
        let refs = try loadRefs(id: id)

        guard entries.count == refs.count else {
            throw ObjectExportError("Directory refs mismatch for id \(id).")
        }

        for (entry, refId) in zip(entries, refs) {
            let targetURL = directoryURL.appendingPathComponent(entry.name)
            switch entry.type {
            case 2:
                try FileManager.default.createDirectory(
                    at: targetURL,
                    withIntermediateDirectories: true
                )
                try exportDirectory(id: refId, to: targetURL)
            case 1:
                let data = try store.loadRawObjectData(id: refId)
                try data.write(to: targetURL, options: [.atomic])
            default:
                continue
            }
        }
    }

    private func loadDirectoryEntries(id: String) throws -> [ObjectDirectoryEntry] {
        let data = try store.loadRawObjectData(id: id)
        return try JSONDecoder().decode([ObjectDirectoryEntry].self, from: data)
    }

    private func loadRefs(id: String) throws -> [String] {
        let refsURL = store.dataURL.appendingPathComponent("refs.\(id)")
        let data = try Data(contentsOf: refsURL)
        guard let count = data.first else { return [] }

        let entrySize = 66
        let expectedSize = 1 + Int(count) * entrySize
        guard data.count >= expectedSize else {
            throw ObjectExportError("Invalid refs data for id \(id).")
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
}

private struct ObjectDirectoryEntry: Decodable {
    let type: Int
    let name: String
}

struct ObjectExportError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
