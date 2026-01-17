import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public struct MergeBuilder {
    public let inputPaths: [String]
    public let outputPath: String

    public init(inputPaths: [String], outputPath: String) {
        self.inputPaths = inputPaths
        self.outputPath = outputPath
    }

    public func merge() throws {
        guard inputPaths.count >= 2 else {
            throw MergeError("Two or more result bundle paths are required to merge.")
        }

        let outputURL = URL(fileURLWithPath: outputPath)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let baseURL = URL(fileURLWithPath: inputPaths[0])
        try FileManager.default.copyItem(at: baseURL, to: outputURL)

        for path in inputPaths.dropFirst() {
            try mergeBundle(from: URL(fileURLWithPath: path), into: outputURL)
        }

        try updateInfoPlist(at: outputURL)
    }

    private func mergeBundle(from sourceURL: URL, into outputURL: URL) throws {
        try mergeData(from: sourceURL, into: outputURL)
        try mergeDatabase(from: sourceURL, into: outputURL)
    }

    private func mergeData(from sourceURL: URL, into outputURL: URL) throws {
        let sourceDataURL = sourceURL.appendingPathComponent("Data")
        let outputDataURL = outputURL.appendingPathComponent("Data")

        guard FileManager.default.fileExists(atPath: sourceDataURL.path) else {
            return
        }
        if !FileManager.default.fileExists(atPath: outputDataURL.path) {
            try FileManager.default.createDirectory(
                at: outputDataURL,
                withIntermediateDirectories: true
            )
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: sourceDataURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        for fileURL in contents {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let targetURL = outputDataURL.appendingPathComponent(fileURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                let existing = try Data(contentsOf: targetURL)
                let incoming = try Data(contentsOf: fileURL)
                if existing != incoming {
                    throw MergeError("Data file collision for \(fileURL.lastPathComponent).")
                }
                continue
            }
            try FileManager.default.copyItem(at: fileURL, to: targetURL)
        }
    }

    private func mergeDatabase(from sourceURL: URL, into outputURL: URL) throws {
        let sourceDB = sourceURL.appendingPathComponent("database.sqlite3")
        let outputDB = outputURL.appendingPathComponent("database.sqlite3")

        guard FileManager.default.fileExists(atPath: sourceDB.path) else {
            return
        }

        var outputHandle: OpaquePointer?
        var sourceHandle: OpaquePointer?
        guard sqlite3_open(outputDB.path, &outputHandle) == SQLITE_OK else {
            throw MergeError("Unable to open output database at \(outputDB.path).")
        }
        defer { sqlite3_close(outputHandle) }

        guard sqlite3_open(sourceDB.path, &sourceHandle) == SQLITE_OK else {
            throw MergeError("Unable to open source database at \(sourceDB.path).")
        }
        defer { sqlite3_close(sourceHandle) }

        try execute(db: outputHandle, sql: "PRAGMA foreign_keys = OFF;")
        let tables = try tableNames(db: outputHandle)
        let offsets = try tableOffsets(db: outputHandle, tables: tables)

        try execute(db: outputHandle, sql: "BEGIN IMMEDIATE;")
        defer { _ = try? execute(db: outputHandle, sql: "COMMIT;") }

        for table in tables {
            let columns = try tableColumns(db: outputHandle, table: table)
            guard !columns.isEmpty else { continue }
            let foreignKeys = try foreignKeyMap(db: outputHandle, table: table)
            let offset = offsets[table] ?? 0
            try copyRows(
                table: table,
                columns: columns,
                foreignKeys: foreignKeys,
                offsets: offsets,
                source: sourceHandle,
                target: outputHandle,
                rowOffset: offset
            )
        }
    }

    private func updateInfoPlist(at outputURL: URL) throws {
        let plistURL = outputURL.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }

        let data = try Data(contentsOf: plistURL)
        var format: PropertyListSerialization.PropertyListFormat = .binary
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        guard var dict = plist as? [String: Any] else { return }

        dict["dateCreated"] = Date()
        let updated = try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)
        try updated.write(to: plistURL, options: [.atomic])
    }

    private func tableNames(db: OpaquePointer?) throws -> [String] {
        let sql = """
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MergeError(lastErrorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                names.append(String(cString: cString))
            }
        }
        return names
    }

    private func tableOffsets(db: OpaquePointer?, tables: [String]) throws -> [String: Int64] {
        var offsets: [String: Int64] = [:]
        for table in tables {
            let sql = "SELECT COALESCE(MAX(rowid), 0) FROM \"\(table)\";"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MergeError(lastErrorMessage(db))
            }
            defer { sqlite3_finalize(statement) }
            if sqlite3_step(statement) == SQLITE_ROW {
                offsets[table] = sqlite3_column_int64(statement, 0)
            } else {
                offsets[table] = 0
            }
        }
        return offsets
    }

    private func tableColumns(db: OpaquePointer?, table: String) throws -> [String] {
        let sql = "PRAGMA table_info(\"\(table)\");"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MergeError(lastErrorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        var columns: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 1) {
                columns.append(String(cString: cString))
            }
        }
        return columns
    }

    private func foreignKeyMap(db: OpaquePointer?, table: String) throws -> [String: String] {
        let sql = "PRAGMA foreign_key_list(\"\(table)\");"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MergeError(lastErrorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        var map: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let tableName = sqlite3_column_text(statement, 2),
                  let fromColumn = sqlite3_column_text(statement, 3) else {
                continue
            }
            map[String(cString: fromColumn)] = String(cString: tableName)
        }
        return map
    }

    private func copyRows(
        table: String,
        columns: [String],
        foreignKeys: [String: String],
        offsets: [String: Int64],
        source: OpaquePointer?,
        target: OpaquePointer?,
        rowOffset: Int64
    ) throws {
        let columnList = columns.map { "\"\($0)\"" }.joined(separator: ", ")
        let selectSQL = "SELECT rowid, \(columnList) FROM \"\(table)\" ORDER BY rowid;"
        let placeholders = Array(repeating: "?", count: columns.count + 1).joined(separator: ", ")
        let insertSQL = "INSERT INTO \"\(table)\" (rowid, \(columnList)) VALUES (\(placeholders));"

        var selectStatement: OpaquePointer?
        guard sqlite3_prepare_v2(source, selectSQL, -1, &selectStatement, nil) == SQLITE_OK else {
            throw MergeError(lastErrorMessage(source))
        }
        defer { sqlite3_finalize(selectStatement) }

        var insertStatement: OpaquePointer?
        guard sqlite3_prepare_v2(target, insertSQL, -1, &insertStatement, nil) == SQLITE_OK else {
            throw MergeError(lastErrorMessage(target))
        }
        defer { sqlite3_finalize(insertStatement) }

        while sqlite3_step(selectStatement) == SQLITE_ROW {
            sqlite3_reset(insertStatement)
            sqlite3_clear_bindings(insertStatement)

            let rowId = sqlite3_column_int64(selectStatement, 0)
            sqlite3_bind_int64(insertStatement, 1, rowId + rowOffset)

            for (index, name) in columns.enumerated() {
                let sourceIndex = Int32(index + 1)
                let targetIndex = Int32(index + 2)
                let type = sqlite3_column_type(selectStatement, sourceIndex)
                if type == SQLITE_NULL {
                    sqlite3_bind_null(insertStatement, targetIndex)
                    continue
                }

                if let referencedTable = foreignKeys[name],
                   type == SQLITE_INTEGER,
                   let offset = offsets[referencedTable] {
                    let value = sqlite3_column_int64(selectStatement, sourceIndex)
                    sqlite3_bind_int64(insertStatement, targetIndex, value + offset)
                    continue
                }

                switch type {
                case SQLITE_INTEGER:
                    sqlite3_bind_int64(insertStatement, targetIndex, sqlite3_column_int64(selectStatement, sourceIndex))
                case SQLITE_FLOAT:
                    sqlite3_bind_double(insertStatement, targetIndex, sqlite3_column_double(selectStatement, sourceIndex))
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(selectStatement, sourceIndex) {
                        sqlite3_bind_text(insertStatement, targetIndex, text, -1, sqliteTransient)
                    } else {
                        sqlite3_bind_null(insertStatement, targetIndex)
                    }
                case SQLITE_BLOB:
                    let bytes = sqlite3_column_blob(selectStatement, sourceIndex)
                    let size = sqlite3_column_bytes(selectStatement, sourceIndex)
                    sqlite3_bind_blob(insertStatement, targetIndex, bytes, size, sqliteTransient)
                default:
                    sqlite3_bind_null(insertStatement, targetIndex)
                }
            }

            guard sqlite3_step(insertStatement) == SQLITE_DONE else {
                throw MergeError(lastErrorMessage(target))
            }
        }
    }

    private func execute(db: OpaquePointer?, sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage(db)
            sqlite3_free(errorMessage)
            throw MergeError(message)
        }
    }

    private func lastErrorMessage(_ db: OpaquePointer?) -> String {
        guard let db, let cString = sqlite3_errmsg(db) else {
            return "Unknown SQLite error."
        }
        return String(cString: cString)
    }
}

struct MergeError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
