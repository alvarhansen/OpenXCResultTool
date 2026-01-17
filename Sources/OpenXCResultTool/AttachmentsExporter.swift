import Foundation
import SQLite3

struct AttachmentsExporter {
    private let context: XCResultContext
    private let store: XCResultFileBackedStore

    init(xcresultPath: String) throws {
        self.context = try XCResultContext(xcresultPath: xcresultPath)
        self.store = try XCResultFileBackedStore(xcresultPath: xcresultPath)
    }

    func export(to outputPath: String, testId: String?, onlyFailures: Bool) throws {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true
        )

        let deviceInfo = try loadDeviceInfo()
        let attachments = try fetchAttachments(testId: testId)
        let runIds = Array(Set(attachments.map(\.testCaseRunId)))
        let argumentsByRun = try fetchArguments(runIds: runIds)

        var manifestEntries: [String: AttachmentManifestEntry] = [:]
        var entryOrder: [String] = []

        for attachment in attachments {
            if onlyFailures, attachment.testIssueId == nil {
                continue
            }
            guard let payloadId = attachment.payloadId, !payloadId.isEmpty else {
                continue
            }

            let exportedFileName = buildExportedFileName(
                uuid: attachment.uuid,
                filenameOverride: attachment.filenameOverride,
                uniformTypeIdentifier: attachment.uniformTypeIdentifier,
                name: attachment.name
            )
            let suggestedName = buildSuggestedName(
                filenameOverride: attachment.filenameOverride,
                name: attachment.name,
                exportedFileName: exportedFileName
            )

            let data = try store.loadRawObjectData(id: payloadId)
            let targetURL = outputURL.appendingPathComponent(exportedFileName)
            try data.write(to: targetURL, options: [.atomic])

            let arguments = argumentsByRun[attachment.testCaseRunId] ?? []
            let manifestAttachment = AttachmentManifestAttachment(
                arguments: arguments,
                configurationName: attachment.configurationName,
                deviceId: deviceInfo.id,
                deviceName: deviceInfo.name,
                exportedFileName: exportedFileName,
                isAssociatedWithFailure: attachment.testIssueId != nil,
                suggestedHumanReadableName: suggestedName,
                timestamp: toUnixTime(attachment.timestamp)
            )

            let key = attachment.testIdentifierURL
            if manifestEntries[key] == nil {
                manifestEntries[key] = AttachmentManifestEntry(
                    attachments: [],
                    testIdentifier: attachment.testIdentifier,
                    testIdentifierURL: attachment.testIdentifierURL
                )
                entryOrder.append(key)
            }
            manifestEntries[key]?.attachments.append(manifestAttachment)
        }

        let manifest = entryOrder.compactMap { manifestEntries[$0] }
        try writeManifest(manifest, to: outputURL)
    }

    private func writeManifest(_ entries: [AttachmentManifestEntry], to outputURL: URL) throws {
        let manifestURL = outputURL.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.prettyPrinted]
        if #available(macOS 10.15, *) {
            formatting.insert(.withoutEscapingSlashes)
        }
        encoder.outputFormatting = formatting
        let data = try encoder.encode(entries)
        try data.write(to: manifestURL, options: [.atomic])
    }

    private func loadDeviceInfo() throws -> (id: String, name: String) {
        guard let runDestination = try context.fetchRunDestination(runDestinationId: context.action.runDestinationId),
              let device = try context.fetchDevice(deviceId: runDestination.deviceId) else {
            return (id: "", name: "")
        }
        return (id: device.identifier, name: runDestination.name)
    }

    private func fetchAttachments(testId: String?) throws -> [AttachmentRow] {
        let sql = """
        SELECT Attachments.rowid,
               Attachments.name,
               Attachments.filenameOverride,
               Attachments.uuid,
               Attachments.uniformTypeIdentifier,
               Attachments.timestamp,
               Attachments.testIssue_fk,
               Attachments.xcResultKitPayloadRefId,
               Activities.testCaseRun_fk,
               TestCases.identifier,
               TestCases.identifierURL,
               TestPlanConfigurations.name
        FROM Attachments
        JOIN Activities ON Activities.rowid = Attachments.activity_fk
        JOIN TestCaseRuns ON TestCaseRuns.rowid = Activities.testCaseRun_fk
        JOIN TestCases ON TestCases.rowid = TestCaseRuns.testCase_fk
        JOIN TestSuiteRuns ON TestSuiteRuns.rowid = TestCaseRuns.testSuiteRun_fk
        JOIN TestableRuns ON TestableRuns.rowid = TestSuiteRuns.testableRun_fk
        JOIN TestPlanRuns ON TestPlanRuns.rowid = TestableRuns.testPlanRun_fk
        JOIN TestPlanConfigurations ON TestPlanConfigurations.rowid = TestPlanRuns.configuration_fk
        ORDER BY Attachments.rowid;
        """

        let rows = try context.database.query(sql) { statement in
            AttachmentRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                filenameOverride: SQLiteDatabase.string(statement, 2),
                uuid: SQLiteDatabase.string(statement, 3) ?? "",
                uniformTypeIdentifier: SQLiteDatabase.string(statement, 4),
                timestamp: SQLiteDatabase.double(statement, 5) ?? 0,
                testIssueId: SQLiteDatabase.int(statement, 6),
                payloadId: SQLiteDatabase.string(statement, 7),
                testCaseRunId: SQLiteDatabase.int(statement, 8) ?? 0,
                testIdentifier: SQLiteDatabase.string(statement, 9) ?? "",
                testIdentifierURL: SQLiteDatabase.string(statement, 10) ?? "",
                configurationName: SQLiteDatabase.string(statement, 11) ?? ""
            )
        }

        guard let testId else { return rows }
        return rows.filter { $0.testIdentifier == testId || $0.testIdentifierURL == testId }
    }

    private func fetchArguments(runIds: [Int]) throws -> [Int: [String]] {
        guard !runIds.isEmpty else { return [:] }
        let placeholders = Array(repeating: "?", count: runIds.count).joined(separator: ",")
        let sql = """
        SELECT Arguments.testCaseRun_fk,
               TestValues.description,
               Arguments.orderInTestCaseRun
        FROM Arguments
        JOIN TestValues ON TestValues.rowid = Arguments.testValue_fk
        WHERE Arguments.testCaseRun_fk IN (\(placeholders))
        ORDER BY Arguments.testCaseRun_fk, Arguments.orderInTestCaseRun;
        """
        let rows = try context.database.query(sql, binder: { statement in
            for (index, id) in runIds.enumerated() {
                sqlite3_bind_int(statement, Int32(index + 1), Int32(id))
            }
        }) { statement in
            ArgumentRow(
                runId: SQLiteDatabase.int(statement, 0) ?? 0,
                value: SQLiteDatabase.string(statement, 1) ?? "",
                orderInTestCaseRun: SQLiteDatabase.int(statement, 2) ?? 0
            )
        }

        let grouped = Dictionary(grouping: rows, by: { $0.runId })
        var results: [Int: [String]] = [:]
        for (runId, values) in grouped {
            let sorted = values.sorted { $0.orderInTestCaseRun < $1.orderInTestCaseRun }
            results[runId] = sorted.map(\.value)
        }
        return results
    }

    private func buildExportedFileName(
        uuid: String,
        filenameOverride: String?,
        uniformTypeIdentifier: String?,
        name: String
    ) -> String {
        let ext = resolveExtension(
            filenameOverride: filenameOverride,
            uniformTypeIdentifier: uniformTypeIdentifier,
            name: name
        )
        guard !ext.isEmpty else { return uuid }
        return "\(uuid).\(ext)"
    }

    private func buildSuggestedName(
        filenameOverride: String?,
        name: String,
        exportedFileName: String
    ) -> String {
        if let filenameOverride, !filenameOverride.isEmpty {
            return filenameOverride
        }
        if !name.isEmpty {
            if let ext = exportedFileName.split(separator: ".").last, exportedFileName.contains(".") {
                return "\(name).\(ext)"
            }
            return name
        }
        return exportedFileName
    }

    private func resolveExtension(
        filenameOverride: String?,
        uniformTypeIdentifier: String?,
        name: String
    ) -> String {
        if let filenameOverride, let ext = fileExtension(from: filenameOverride) {
            return ext
        }
        if let ext = fileExtension(from: name) {
            return ext
        }
        guard let uniformTypeIdentifier else { return "" }
        switch uniformTypeIdentifier {
        case "public.png":
            return "png"
        case "public.jpeg", "public.jpg":
            return "jpg"
        case "public.tiff":
            return "tiff"
        case "public.plain-text", "public.text":
            return "txt"
        case "public.xml":
            return "xml"
        default:
            return ""
        }
    }

    private func fileExtension(from name: String) -> String? {
        guard let dotIndex = name.lastIndex(of: "."),
              dotIndex != name.startIndex else { return nil }
        let ext = name[name.index(after: dotIndex)...]
        return ext.isEmpty ? nil : String(ext)
    }

    private func toUnixTime(_ coreDataTime: Double) -> Double {
        let unixTime = coreDataTime + 978_307_200
        return (unixTime * 1000).rounded() / 1000
    }
}

private struct AttachmentRow {
    let id: Int
    let name: String
    let filenameOverride: String?
    let uuid: String
    let uniformTypeIdentifier: String?
    let timestamp: Double
    let testIssueId: Int?
    let payloadId: String?
    let testCaseRunId: Int
    let testIdentifier: String
    let testIdentifierURL: String
    let configurationName: String
}

private struct ArgumentRow {
    let runId: Int
    let value: String
    let orderInTestCaseRun: Int
}

struct AttachmentManifestEntry: Encodable {
    var attachments: [AttachmentManifestAttachment]
    let testIdentifier: String
    let testIdentifierURL: String
}

struct AttachmentManifestAttachment: Encodable {
    let arguments: [String]
    let configurationName: String
    let deviceId: String
    let deviceName: String
    let exportedFileName: String
    let isAssociatedWithFailure: Bool
    let suggestedHumanReadableName: String
    let timestamp: Double
}
