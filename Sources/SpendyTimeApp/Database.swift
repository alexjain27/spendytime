import Foundation
import SQLite3
import Security

// Swift equivalent of the C macro ((sqlite3_destructor_type)-1)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@_silgen_name("sqlite3_key")
private func sqlite3_key(_ db: OpaquePointer?, _ key: UnsafeRawPointer?, _ keyLen: Int32) -> Int32

final class Database {
    private var db: OpaquePointer?

    init() {
        let fileURL = Database.databaseURL()
        Database.ensureDirectoryExists(for: fileURL)
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Failed to open database at \(fileURL.path)")
            return
        }
        Database.applyFilePermissions(for: fileURL)
        guard let key = applyEncryptionKey() else {
            print("Failed to apply database encryption key.")
            return
        }
        _ = execute(sql: "PRAGMA cipher_migrate;", bindings: [])
        if !isReadableDatabase() {
            if Database.migratePlaintextDatabase(at: fileURL, key: key) {
                sqlite3_close(db)
                db = nil
                if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
                    print("Failed to reopen encrypted database at \(fileURL.path)")
                    return
                }
                Database.applyFilePermissions(for: fileURL)
                guard applyEncryptionKey() != nil else {
                    print("Failed to apply database encryption key after migration.")
                    return
                }
            } else {
                print("Failed to migrate plaintext database.")
                return
            }
        }
        createTables()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS activities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time REAL NOT NULL,
            end_time REAL NOT NULL,
            app_name TEXT NOT NULL,
            bundle_id TEXT NOT NULL,
            window_title TEXT,
            url TEXT,
            website_host TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_activities_start_time ON activities(start_time);
        CREATE INDEX IF NOT EXISTS idx_activities_app_name ON activities(app_name);
        CREATE INDEX IF NOT EXISTS idx_activities_website_host ON activities(website_host);
        """
        _ = execute(sql: sql, bindings: [])
    }

    static func databaseURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SpendyTime", isDirectory: true).appendingPathComponent("spendytime.sqlite")
    }

    private static func ensureDirectoryExists(for fileURL: URL) {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } else {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        }
    }

    private static func applyFilePermissions(for fileURL: URL) {
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func applyEncryptionKey() -> Data? {
        guard let db else { return nil }
        guard let key = KeychainStore.loadOrCreateKey() else { return nil }
        let result = key.withUnsafeBytes { bytes -> Int32 in
            guard let base = bytes.baseAddress else { return SQLITE_ERROR }
            return sqlite3_key(db, base, Int32(bytes.count))
        }
        if result != SQLITE_OK {
            return nil
        }
        return key
    }

    private func isReadableDatabase() -> Bool {
        guard let db else { return false }
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master LIMIT 1;", -1, &statement, nil)
        if status != SQLITE_OK {
            sqlite3_finalize(statement)
            return false
        }
        sqlite3_finalize(statement)
        return true
    }

    private static func migratePlaintextDatabase(at url: URL, key: Data) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return true
        }
        let tmpURL = url.deletingLastPathComponent().appendingPathComponent("spendytime-encrypted.sqlite")
        try? FileManager.default.removeItem(at: tmpURL)

        var db: OpaquePointer?
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            return false
        }
        defer { sqlite3_close(db) }

        let keyHex = key.map { String(format: "%02x", $0) }.joined()
        let attachSQL = "ATTACH DATABASE '\(tmpURL.path)' AS encrypted KEY \"x'\(keyHex)'\";"
        let exportSQL = "SELECT sqlcipher_export('encrypted');"
        let detachSQL = "DETACH DATABASE encrypted;"

        if sqlite3_exec(db, attachSQL, nil, nil, nil) != SQLITE_OK {
            return false
        }
        if sqlite3_exec(db, exportSQL, nil, nil, nil) != SQLITE_OK {
            _ = sqlite3_exec(db, detachSQL, nil, nil, nil)
            return false
        }
        if sqlite3_exec(db, detachSQL, nil, nil, nil) != SQLITE_OK {
            return false
        }

        do {
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: tmpURL, to: url)
            applyFilePermissions(for: url)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func execute(sql: String, bindings: [SQLiteValue]) -> Bool {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            print("Failed to prepare SQL: \(sql)")
            return false
        }
        bind(values: bindings, to: statement)
        let result = sqlite3_step(statement)
        sqlite3_finalize(statement)
        return result == SQLITE_DONE
    }

    func query(sql: String, bindings: [SQLiteValue]) -> [[String: SQLiteValue]] {
        var rows: [[String: SQLiteValue]] = []
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            print("Failed to prepare SQL: \(sql)")
            return rows
        }
        bind(values: bindings, to: statement)
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: SQLiteValue] = [:]
            for i in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, i))
                let type = sqlite3_column_type(statement, i)
                switch type {
                case SQLITE_INTEGER:
                    row[name] = .int(sqlite3_column_int64(statement, i))
                case SQLITE_FLOAT:
                    row[name] = .double(sqlite3_column_double(statement, i))
                case SQLITE_TEXT:
                    row[name] = .text(String(cString: sqlite3_column_text(statement, i)))
                case SQLITE_NULL:
                    row[name] = .null
                default:
                    row[name] = .null
                }
            }
            rows.append(row)
        }
        sqlite3_finalize(statement)
        return rows
    }

    private func bind(values: [SQLiteValue], to statement: OpaquePointer?) {
        for (index, value) in values.enumerated() {
            let idx = Int32(index + 1)
            switch value {
            case .int(let v):
                sqlite3_bind_int64(statement, idx, v)
            case .double(let v):
                sqlite3_bind_double(statement, idx, v)
            case .text(let v):
                sqlite3_bind_text(statement, idx, v, -1, SQLITE_TRANSIENT)
            case .null:
                sqlite3_bind_null(statement, idx)
            }
        }
    }
}

enum SQLiteValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case null

    var intValue: Int64? {
        if case .int(let v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    var textValue: String? {
        if case .text(let v) = self { return v }
        return nil
    }
}

