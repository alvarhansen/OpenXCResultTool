import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            throw SQLiteError("Database not found at \(path).")
        }
        if sqlite3_open(path, &db) != SQLITE_OK {
            let message = "Unable to open database at \(path): \(SQLiteDatabase.lastErrorMessage(db))"
            sqlite3_close(db)
            throw SQLiteError(message)
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func query<T>(
        _ sql: String,
        binder: ((OpaquePointer) throws -> Void)? = nil,
        row: (OpaquePointer) throws -> T
    ) throws -> [T] {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteError(SQLiteDatabase.lastErrorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        if let binder {
            try binder(statement!)
        }

        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try row(statement!))
        }
        return results
    }

    func queryOne<T>(
        _ sql: String,
        binder: ((OpaquePointer) throws -> Void)? = nil,
        row: (OpaquePointer) throws -> T
    ) throws -> T? {
        return try query(sql, binder: binder, row: row).first
    }

    static func string(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    static func int(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }

    static func double(_ statement: OpaquePointer, _ index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }

    private static func lastErrorMessage(_ db: OpaquePointer?) -> String {
        guard let db else { return "Unknown SQLite error." }
        if let cString = sqlite3_errmsg(db) {
            return String(cString: cString)
        }
        return "Unknown SQLite error."
    }
}

struct SQLiteError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String {
        message
    }
}
