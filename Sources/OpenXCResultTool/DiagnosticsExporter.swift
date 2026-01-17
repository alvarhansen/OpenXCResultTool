import Foundation

struct DiagnosticsExporter {
    private let context: XCResultContext
    private let store: XCResultFileBackedStore

    init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
        self.store = try XCResultFileBackedStore(xcresultPath: xcresultPath)
    }

    func export(to outputPath: String) throws {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true
        )

        guard let diagnosticsId = try resolveDiagnosticsId() else {
            throw DiagnosticsExportError("No diagnostics available in the result bundle.")
        }

        let rootName = try diagnosticsRootName()
        let rootURL = outputURL.appendingPathComponent(rootName)
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        try exportDirectory(id: diagnosticsId, to: rootURL)
    }

    private func diagnosticsRootName() throws -> String {
        let actionIndex = context.action.orderInInvocation
        let actionName = context.action.name
        let runDestinationName = try context
            .fetchRunDestination(runDestinationId: context.action.runDestinationId)?
            .name ?? ""
        let components = [String(actionIndex), actionName, runDestinationName, "Diagnostics"]
        return components.filter { !$0.isEmpty }.joined(separator: "_")
    }

    private func resolveDiagnosticsId() throws -> String? {
        let root = try store.loadObject(id: store.rootId)
        let actions = root.value(for: "actions")?.arrayValues ?? []
        guard let action = actions.first else { return nil }
        return action
            .value(for: "actionResult")?
            .value(for: "diagnosticsRef")?
            .value(for: "id")?
            .stringValue
    }

    private func exportDirectory(id: String, to directoryURL: URL) throws {
        let entries = try loadDirectoryEntries(id: id)
        let refs = try loadRefs(id: id)

        guard entries.count == refs.count else {
            throw DiagnosticsExportError("Diagnostics directory mismatch for id \(id).")
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

    private func loadDirectoryEntries(id: String) throws -> [DiagnosticsDirectoryEntry] {
        let data = try store.loadRawObjectData(id: id)
        return try JSONDecoder().decode([DiagnosticsDirectoryEntry].self, from: data)
    }

    private func loadRefs(id: String) throws -> [String] {
        let refsURL = store.dataURL.appendingPathComponent("refs.\(id)")
        let data = try Data(contentsOf: refsURL)
        guard let count = data.first else { return [] }

        let entrySize = 66
        let expectedSize = 1 + Int(count) * entrySize
        guard data.count >= expectedSize else {
            throw DiagnosticsExportError("Invalid refs data for id \(id).")
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

private struct DiagnosticsDirectoryEntry: Decodable {
    let type: Int
    let name: String
}

struct DiagnosticsExportError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
