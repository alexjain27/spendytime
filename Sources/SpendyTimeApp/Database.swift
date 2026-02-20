import Foundation
import SQLite3

// Swift equivalent of the C macro ((sqlite3_destructor_type)-1)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class Database {
    private var db: OpaquePointer?

    init() {
        let fileURL = Database.databaseURL()
        Database.ensureDirectoryExists(for: fileURL)
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Failed to open database at \(fileURL.path)")
            return
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
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
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

