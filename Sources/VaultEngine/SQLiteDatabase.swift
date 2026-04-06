import Foundation
import SQLite3

/// Lightweight wrapper around SQLite3 C API.
final class SQLiteDatabase {
    private var db: OpaquePointer?
    let path: String

    init(path: String) throws {
        self.path = path
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &db, flags, nil)
        guard result == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw VaultError.databaseError("Failed to open: \(msg)")
        }
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
    }

    deinit {
        sqlite3_close(db)
    }

    private var errorMessage: String {
        db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard result == SQLITE_OK, let s = stmt else {
            throw VaultError.databaseError("Prepare: \(errorMessage)")
        }
        return s
    }

    // MARK: - Execute (no results)

    @discardableResult
    func execute(_ sql: String, params: [Any?] = []) throws -> Int {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bind(stmt, params: params)
        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw VaultError.databaseError(errorMessage)
        }
        return Int(sqlite3_changes(db))
    }

    // MARK: - Query (returns rows)

    func query(_ sql: String, params: [Any?] = []) throws -> [[String: Any?]] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bind(stmt, params: params)
        var rows: [[String: Any?]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any?] = [:]
            let colCount = sqlite3_column_count(stmt)
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                row[name] = value(from: stmt, at: i)
            }
            rows.append(row)
        }
        return rows
    }

    // MARK: - Scalar (single value)

    func scalar<T>(_ sql: String, params: [Any?] = []) throws -> T? {
        let rows = try query(sql, params: params)
        guard let first = rows.first, let col = first.first else { return nil }
        return col.value as? T
    }

    // MARK: - Bind parameters

    private func bind(_ stmt: OpaquePointer, params: [Any?]) throws {
        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            var rc: Int32
            switch param {
            case nil:
                rc = sqlite3_bind_null(stmt, idx)
            case let v as String:
                rc = sqlite3_bind_text(
                    stmt, idx, (v as NSString).utf8String, -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                )
            case let v as Int:
                rc = sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Int64:
                rc = sqlite3_bind_int64(stmt, idx, v)
            case let v as Double:
                rc = sqlite3_bind_double(stmt, idx, v)
            case let v as Data:
                rc = v.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(
                        stmt, idx, ptr.baseAddress, Int32(v.count),
                        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    )
                }
            default:
                let s = "\(param!)"
                rc = sqlite3_bind_text(
                    stmt, idx, (s as NSString).utf8String, -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                )
            }
            guard rc == SQLITE_OK else {
                throw VaultError.databaseError("Bind \(i): \(errorMessage)")
            }
        }
    }

    // MARK: - Read column value

    private func value(from stmt: OpaquePointer, at index: Int32) -> Any? {
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_NULL:
            return nil
        case SQLITE_INTEGER:
            return Int64(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT:
            return sqlite3_column_double(stmt, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(stmt, index))
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(stmt, index)
            let count = Int(sqlite3_column_bytes(stmt, index))
            if let bytes = bytes {
                return Data(bytes: bytes, count: count)
            }
            return nil
        default:
            return nil
        }
    }
}
