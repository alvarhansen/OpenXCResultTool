import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif
import OpenXCResultTool

@main
struct OpenXCResultToolWasmMain {
    static func main() {}
}

@MainActor
private var lastErrorMessage: String?

@_cdecl("openxcresulttool_free")
public func openxcresulttool_free(_ pointer: UnsafeMutablePointer<CChar>?) {
    guard let pointer else {
        return
    }
    pointer.deallocate()
}

@MainActor
@_cdecl("openxcresulttool_alloc")
public func openxcresulttool_alloc(_ size: Int) -> UnsafeMutablePointer<CChar>? {
    guard size > 0 else {
        return nil
    }
    return UnsafeMutablePointer<CChar>.allocate(capacity: size)
}

@MainActor
@_cdecl("openxcresulttool_last_error")
public func openxcresulttool_last_error() -> UnsafeMutablePointer<CChar>? {
    guard let message = lastErrorMessage else {
        return nil
    }
    return makeCString(message)
}

@MainActor
@_cdecl("openxcresulttool_register_database")
public func openxcresulttool_register_database(
    _ pathPointer: UnsafePointer<CChar>?,
    _ dataPointer: UnsafePointer<UInt8>?,
    _ length: Int
) -> Bool {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return false
    }
    guard let dataPointer, length > 0 else {
        lastErrorMessage = "database bytes are required"
        return false
    }
    let data = Data(bytes: dataPointer, count: length)
    #if os(WASI)
    WasiDatabaseRegistry.register(path: path, data: data)
    #endif
    lastErrorMessage = nil
    return true
}

@MainActor
@_cdecl("openxcresulttool_register_file")
public func openxcresulttool_register_file(
    _ pathPointer: UnsafePointer<CChar>?,
    _ dataPointer: UnsafePointer<UInt8>?,
    _ length: Int
) -> Bool {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return false
    }
    let data: Data
    if length == 0 {
        data = Data()
    } else {
        guard let dataPointer else {
            lastErrorMessage = "file bytes are required"
            return false
        }
        data = Data(bytes: dataPointer, count: length)
    }
    #if os(WASI)
    WasiFileRegistry.register(path: path, data: data)
    #endif
    lastErrorMessage = nil
    return true
}

@MainActor
@_cdecl("openxcresulttool_version_json")
public func openxcresulttool_version_json(_ compact: Bool) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(compact: compact) {
        let info = VersionInfo(
            tool: OpenXCResultToolVersion.tool,
            schema: OpenXCResultToolVersion.schema,
            legacyFormat: OpenXCResultToolVersion.legacyFormat
        )
        return try encodeJSON(info, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_metadata_json")
public func openxcresulttool_get_metadata_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = MetadataBuilder(xcresultPath: path)
        let data = try builder.metadataJSON(compact: compact)
        return String(decoding: data, as: UTF8.self)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_metadata_from_plist_json")
public func openxcresulttool_get_metadata_from_plist_json(
    _ dataPointer: UnsafePointer<UInt8>?,
    _ length: Int,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    guard let dataPointer, length > 0 else {
        lastErrorMessage = "plist bytes are required"
        return nil
    }
    let data = Data(bytes: dataPointer, count: length)
    do {
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        guard let dict = plist as? [String: Any] else {
            throw WasmExportError("Invalid Info.plist metadata.")
        }
        let metadata = metadataDictionary(from: dict)
        let options: JSONSerialization.WritingOptions = compact ? [] : [.prettyPrinted]
        let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: options)
        lastErrorMessage = nil
        return makeCString(String(decoding: jsonData, as: UTF8.self))
    } catch {
        lastErrorMessage = String(describing: error)
        return nil
    }
}

@MainActor
@_cdecl("openxcresulttool_format_description_json")
public func openxcresulttool_format_description_json(_ compact: Bool) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(compact: compact) {
        let builder = FormatDescriptionBuilder()
        let data = try builder.descriptionJSON(includeEventStreamTypes: false)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let options: JSONSerialization.WritingOptions = compact ? [] : [.prettyPrinted]
        let normalized = try JSONSerialization.data(withJSONObject: object, options: options)
        return String(decoding: normalized, as: UTF8.self)
    }
}

@MainActor
@_cdecl("openxcresulttool_graph_text")
public func openxcresulttool_graph_text(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    _ = compact
    return buildJSONString(pathPointer: pathPointer, compact: false) { path in
        let builder = try GraphBuilder(xcresultPath: path)
        let data = try builder.graph(id: nil)
        return String(decoding: data, as: UTF8.self)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_object_json")
public func openxcresulttool_get_object_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ idPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let store = try XCResultFileBackedStore(xcresultPath: path)
        let objectId = optionalString(from: idPointer) ?? store.rootId
        let rawValue = try store.loadObject(id: objectId)
        let json = rawValue.toLegacyJSONValue()
        let options: JSONSerialization.WritingOptions = compact ? [] : [.prettyPrinted]
        let data = try JSONSerialization.data(withJSONObject: json, options: options)
        return String(decoding: data, as: UTF8.self)
    }
}

@MainActor
@_cdecl("openxcresulttool_compare_json")
public func openxcresulttool_compare_json(
    _ baselinePointer: UnsafePointer<CChar>?,
    _ currentPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(
        baselinePointer: baselinePointer,
        currentPointer: currentPointer,
        compact: compact
    ) { baselinePath, currentPath in
        let builder = try CompareBuilder(baselinePath: baselinePath, currentPath: currentPath)
        let result = try builder.compare()
        var output = CompareOutput()
        output.summary = result.summary
        output.testFailures = result.testFailures
        output.testsExecuted = result.testsExecuted
        output.buildWarnings = result.buildWarnings
        output.analyzerIssues = result.analyzerIssues
        return try encodeJSON(output, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_export_diagnostics")
public func openxcresulttool_export_diagnostics(
    _ pathPointer: UnsafePointer<CChar>?,
    _ outputPointer: UnsafePointer<CChar>?
) -> Bool {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return false
    }
    guard let outputPath = optionalString(from: outputPointer) else {
        lastErrorMessage = "output path is required"
        return false
    }
    do {
        let exporter = try DiagnosticsExporter(xcresultPath: path)
        try exporter.export(to: outputPath)
        lastErrorMessage = nil
        return true
    } catch {
        lastErrorMessage = String(describing: error)
        return false
    }
}

@MainActor
@_cdecl("openxcresulttool_export_attachments")
public func openxcresulttool_export_attachments(
    _ pathPointer: UnsafePointer<CChar>?,
    _ outputPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?,
    _ onlyFailures: Int32
) -> Bool {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return false
    }
    guard let outputPath = optionalString(from: outputPointer) else {
        lastErrorMessage = "output path is required"
        return false
    }
    let testId = optionalString(from: testIdPointer)
    let onlyFailuresFlag = onlyFailures != 0
    do {
        let exporter = try AttachmentsExporter(xcresultPath: path)
        try exporter.export(to: outputPath, testId: testId, onlyFailures: onlyFailuresFlag)
        lastErrorMessage = nil
        return true
    } catch {
        lastErrorMessage = String(describing: error)
        return false
    }
}

@MainActor
@_cdecl("openxcresulttool_export_metrics")
public func openxcresulttool_export_metrics(
    _ pathPointer: UnsafePointer<CChar>?,
    _ outputPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?
) -> Bool {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return false
    }
    guard let outputPath = optionalString(from: outputPointer) else {
        lastErrorMessage = "output path is required"
        return false
    }
    let testId = optionalString(from: testIdPointer)
    do {
        let exporter = try MetricsExporter(xcresultPath: path)
        try exporter.export(to: outputPath, testId: testId)
        lastErrorMessage = nil
        return true
    } catch {
        lastErrorMessage = String(describing: error)
        return false
    }
}

@MainActor
@_cdecl("openxcresulttool_export_object")
public func openxcresulttool_export_object(
    _ pathPointer: UnsafePointer<CChar>?,
    _ outputPointer: UnsafePointer<CChar>?,
    _ idPointer: UnsafePointer<CChar>?,
    _ typePointer: UnsafePointer<CChar>?
) -> Bool {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return false
    }
    guard let outputPath = optionalString(from: outputPointer) else {
        lastErrorMessage = "output path is required"
        return false
    }
    guard let objectId = optionalString(from: idPointer) else {
        lastErrorMessage = "object id is required"
        return false
    }
    let typeValue = optionalString(from: typePointer) ?? "file"
    let exportType = ObjectExportKind(rawValue: typeValue) ?? .file
    do {
        let exporter = try ObjectExporter(xcresultPath: path)
        try exporter.export(id: objectId, type: exportType, to: outputPath)
        lastErrorMessage = nil
        return true
    } catch {
        lastErrorMessage = String(describing: error)
        return false
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_summary_json")
public func openxcresulttool_get_test_results_summary_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsSummaryBuilder(xcresultPath: path)
        let summary = try builder.summary()
        return try encodeJSON(summary, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_tests_json")
public func openxcresulttool_get_test_results_tests_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsTestsBuilder(xcresultPath: path)
        let tests = try builder.tests()
        return try encodeJSON(tests, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_test_details_json")
public func openxcresulttool_get_test_results_test_details_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        guard let testId = optionalString(from: testIdPointer) else {
            throw WasmExportError("testId is required")
        }
        let builder = try TestResultsTestDetailsBuilder(xcresultPath: path)
        let details = try builder.testDetails(testId: testId)
        return try encodeJSON(details, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_activities_json")
public func openxcresulttool_get_test_results_activities_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        guard let testId = optionalString(from: testIdPointer) else {
            throw WasmExportError("testId is required")
        }
        let builder = try TestResultsActivitiesBuilder(xcresultPath: path)
        let activities = try builder.activities(testId: testId)
        return try encodeJSON(activities, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_metrics_json")
public func openxcresulttool_get_test_results_metrics_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ testIdPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsMetricsBuilder(xcresultPath: path)
        let testId = optionalString(from: testIdPointer)
        let metrics = try builder.metrics(testId: testId)
        return try encodeJSON(metrics, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_get_test_results_insights_json")
public func openxcresulttool_get_test_results_insights_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let builder = try TestResultsInsightsBuilder(xcresultPath: path)
        let insights = try builder.insights()
        return try encodeJSON(insights, compact: compact)
    }
}

@MainActor
@_cdecl("openxcresulttool_sqlite_smoke_test_json")
public func openxcresulttool_sqlite_smoke_test_json(
    _ pathPointer: UnsafePointer<CChar>?,
    _ compact: Bool
) -> UnsafeMutablePointer<CChar>? {
    return buildJSONString(pathPointer: pathPointer, compact: compact) { path in
        let databasePath = databasePath(for: path)
        let db = try openSQLiteDatabase(path: databasePath)
        defer { sqlite3_close(db) }
        let tableCount = try fetchTableCount(db: db)
        let tables = try fetchTableNames(db: db, limit: 5)
        let result = SQLiteSmokeResult(databasePath: databasePath, tableCount: tableCount, sampleTables: tables)
        return try encodeJSON(result, compact: compact)
    }
}

@MainActor
private func buildJSONString(
    pathPointer: UnsafePointer<CChar>?,
    compact: Bool,
    work: (String) throws -> String
) -> UnsafeMutablePointer<CChar>? {
    guard let path = optionalString(from: pathPointer) else {
        lastErrorMessage = "path is required"
        return nil
    }
    do {
        let value = try work(path)
        lastErrorMessage = nil
        return makeCString(value)
    } catch {
        lastErrorMessage = String(describing: error)
        return nil
    }
}

@MainActor
private func buildJSONString(
    baselinePointer: UnsafePointer<CChar>?,
    currentPointer: UnsafePointer<CChar>?,
    compact: Bool,
    work: (String, String) throws -> String
) -> UnsafeMutablePointer<CChar>? {
    guard let baselinePath = optionalString(from: baselinePointer) else {
        lastErrorMessage = "baseline path is required"
        return nil
    }
    guard let currentPath = optionalString(from: currentPointer) else {
        lastErrorMessage = "current path is required"
        return nil
    }
    do {
        let value = try work(baselinePath, currentPath)
        lastErrorMessage = nil
        return makeCString(value)
    } catch {
        lastErrorMessage = String(describing: error)
        return nil
    }
}

@MainActor
private func buildJSONString(
    compact: Bool,
    work: () throws -> String
) -> UnsafeMutablePointer<CChar>? {
    do {
        let value = try work()
        lastErrorMessage = nil
        return makeCString(value)
    } catch {
        lastErrorMessage = String(describing: error)
        return nil
    }
}

private func optionalString(from pointer: UnsafePointer<CChar>?) -> String? {
    guard let pointer else {
        return nil
    }
    return String(cString: pointer)
}

private func encodeJSON<T: Encodable>(_ value: T, compact: Bool) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = compact ? [] : [.prettyPrinted]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}

private func makeCString(_ value: String) -> UnsafeMutablePointer<CChar>? {
    var utf8 = Array(value.utf8)
    utf8.append(0)
    let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    for (index, byte) in utf8.enumerated() {
        pointer[index] = CChar(bitPattern: byte)
    }
    return pointer
}

private func databasePath(for path: String) -> String {
    let url = URL(fileURLWithPath: path)
    if url.pathExtension == "xcresult" {
        return url.appendingPathComponent("database.sqlite3").path
    }
    if url.lastPathComponent == "database.sqlite3" {
        return url.path
    }
    return url.appendingPathComponent("database.sqlite3").path
}

private func metadataDictionary(from dict: [String: Any]) -> [String: Any] {
    let dateCreated = (dict["dateCreated"] as? Date).map { formatMetadataDate($0) } ?? ""
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

private func formatMetadataDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return formatter.string(from: date)
}

private struct SQLiteOpenAttempt {
    let path: String
    let flags: Int32
}

private func sqliteOpenAttempts(for path: String) -> [SQLiteOpenAttempt] {
    #if os(WASI)
    let uriBase = URL(fileURLWithPath: path).absoluteString
    return [
        SQLiteOpenAttempt(path: "\(uriBase)?mode=ro&immutable=1", flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI),
        SQLiteOpenAttempt(path: "\(uriBase)?mode=ro", flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI),
        SQLiteOpenAttempt(path: path, flags: SQLITE_OPEN_READONLY),
    ]
    #else
    return [SQLiteOpenAttempt(path: path, flags: SQLITE_OPEN_READONLY)]
    #endif
}

private func openSQLiteDatabase(path: String) throws -> OpaquePointer {
    var db: OpaquePointer?
    var lastMessage = "Unable to open database at \(path)."
    #if os(WASI)
    if let data = WasiDatabaseRegistry.data(for: path) {
        return try deserializeSQLiteDatabase(data: data)
    }
    #endif
    for attempt in sqliteOpenAttempts(for: path) {
        if sqlite3_open_v2(attempt.path, &db, attempt.flags, nil) == SQLITE_OK, let db {
            return db
        }
        lastMessage = sqliteOpenErrorMessage(db, path: path, attempted: attempt.path)
        sqlite3_close(db)
        db = nil
    }
    #if os(WASI)
    do {
        return try deserializeSQLiteDatabase(path: path)
    } catch {
        lastMessage = "Unable to open database at \(path). Deserialize fallback failed: \(error)"
    }
    #endif
    throw WasmExportError(lastMessage)
}

private func sqliteOpenErrorMessage(_ db: OpaquePointer?, path: String, attempted: String) -> String {
    let errCode = db.map { sqlite3_errcode($0) } ?? 0
    let extCode = db.map { sqlite3_extended_errcode($0) } ?? 0
    let sysErr = db.map { sqlite3_system_errno($0) } ?? 0
    let message = sqliteLastErrorMessage(db)
    return "Unable to open database at \(path) (attempted \(attempted)): \(message) [err=\(errCode), xerr=\(extCode), sys=\(sysErr)]"
}

private func sqliteLastErrorMessage(_ db: OpaquePointer?) -> String {
    guard let db else { return "Unknown SQLite error." }
    if let cString = sqlite3_errmsg(db) {
        return String(cString: cString)
    }
    return "Unknown SQLite error."
}

private func fetchTableCount(db: OpaquePointer) throws -> Int {
    let sql = "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table';"
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
        throw WasmExportError(sqliteLastErrorMessage(db))
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else {
        return 0
    }
    return Int(sqlite3_column_int64(statement, 0))
}

private func fetchTableNames(db: OpaquePointer, limit: Int) throws -> [String] {
    let sql = """
    SELECT name
    FROM sqlite_master
    WHERE type = 'table'
    ORDER BY name
    LIMIT ?;
    """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
        throw WasmExportError(sqliteLastErrorMessage(db))
    }
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_int(statement, 1, Int32(limit))
    var results: [String] = []
    while sqlite3_step(statement) == SQLITE_ROW {
        if let cString = sqlite3_column_text(statement, 0) {
            results.append(String(cString: cString))
        }
    }
    return results
}

#if os(WASI)
private func deserializeSQLiteDatabase(path: String) throws -> OpaquePointer {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try deserializeSQLiteDatabase(data: data)
}

private func deserializeSQLiteDatabase(data: Data) throws -> OpaquePointer {
    var db: OpaquePointer?
    if sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
        let message = "Unable to open in-memory database: \(sqliteLastErrorMessage(db))"
        sqlite3_close(db)
        throw WasmExportError(message)
    }
    guard let db else {
        throw WasmExportError("Unable to initialize in-memory database.")
    }

    let size = data.count
    guard let buffer = sqlite3_malloc64(UInt64(size)) else {
        sqlite3_close(db)
        throw WasmExportError("Unable to allocate memory for database deserialization.")
    }
    let target = buffer.bindMemory(to: UInt8.self, capacity: size)
    data.withUnsafeBytes { bytes in
        if let base = bytes.baseAddress {
            memcpy(target, base, size)
        }
    }

    let rc = sqlite3_deserialize(
        db,
        "main",
        target,
        sqlite3_int64(size),
        sqlite3_int64(size),
        UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_READONLY)
    )
    if rc != SQLITE_OK {
        sqlite3_free(buffer)
        let message = "Unable to deserialize database: \(sqliteLastErrorMessage(db))"
        sqlite3_close(db)
        throw WasmExportError(message)
    }
    return db
}
#endif

private struct WasmExportError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}

private struct SQLiteSmokeResult: Encodable {
    let databasePath: String
    let tableCount: Int
    let sampleTables: [String]
}

private struct VersionInfo: Encodable {
    let tool: String
    let schema: String
    let legacyFormat: String
}
