import Foundation
#if os(WASI)
import SQLite3WASI
#else
import SQLite3
#endif

final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: String) throws {
        var lastMessage = "Unable to open database at \(path)."
        #if os(WASI)
        if let data = WasiDatabaseRegistry.data(for: path) {
            db = try SQLiteDatabase.deserializeDatabase(data: data)
            return
        }
        #endif
        for attempt in SQLiteDatabase.openAttempts(for: path) {
            if sqlite3_open_v2(attempt.path, &db, attempt.flags, nil) == SQLITE_OK {
                return
            }
            lastMessage = SQLiteDatabase.openErrorMessage(db, path: path, attempted: attempt.path)
            sqlite3_close(db)
            db = nil
        }
        #if os(WASI)
        do {
            db = try SQLiteDatabase.deserializeDatabase(path: path)
            return
        } catch {
            lastMessage = "Unable to open database at \(path). Deserialize fallback failed: \(error)"
        }
        #endif
        throw SQLiteError(lastMessage)
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
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_ROW {
                results.append(try row(statement!))
                continue
            }
            if rc == SQLITE_DONE {
                break
            }
            throw SQLiteError(SQLiteDatabase.lastErrorMessage(db))
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

    private struct OpenAttempt {
        let path: String
        let flags: Int32
    }

    private static func openAttempts(for path: String) -> [OpenAttempt] {
        #if os(WASI)
        let uriBase = URL(fileURLWithPath: path).absoluteString
        return [
            OpenAttempt(path: "\(uriBase)?mode=ro&immutable=1", flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI),
            OpenAttempt(path: "\(uriBase)?mode=ro", flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI),
            OpenAttempt(path: path, flags: SQLITE_OPEN_READONLY)
        ]
        #else
        return [OpenAttempt(path: path, flags: SQLITE_OPEN_READONLY)]
        #endif
    }

    private static func openErrorMessage(_ db: OpaquePointer?, path: String, attempted: String) -> String {
        let errCode = db.map { sqlite3_errcode($0) } ?? 0
        let extCode = db.map { sqlite3_extended_errcode($0) } ?? 0
        let sysErr = db.map { sqlite3_system_errno($0) } ?? 0
        let message = lastErrorMessage(db)
        return "Unable to open database at \(path) (attempted \(attempted)): \(message) [err=\(errCode), xerr=\(extCode), sys=\(sysErr)]"
    }

    #if os(WASI)
    private static func deserializeDatabase(data: Data) throws -> OpaquePointer {
        var db: OpaquePointer?
        if sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            let message = "Unable to open in-memory database: \(lastErrorMessage(db))"
            sqlite3_close(db)
            throw SQLiteError(message)
        }
        guard let db else {
            throw SQLiteError("Unable to initialize in-memory database.")
        }

        let size = data.count
        guard let buffer = sqlite3_malloc64(UInt64(size)) else {
            sqlite3_close(db)
            throw SQLiteError("Unable to allocate memory for database deserialization.")
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
            let message = "Unable to deserialize database: \(lastErrorMessage(db))"
            sqlite3_close(db)
            throw SQLiteError(message)
        }
        return db
    }

    private static func deserializeDatabase(path: String) throws -> OpaquePointer {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try deserializeDatabase(data: data)
    }
    #endif
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
