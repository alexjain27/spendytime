import Foundation

final class ActivityStore: ObservableObject {
    private let db = Database()
    private var currentActivityId: Int64?
    private var currentSnapshot: ActivitySnapshot?

    @Published private(set) var latestSessions: [ActivitySession] = []
    @Published private(set) var latestAppTotals: [AppTotal] = []
    @Published private(set) var latestWebsiteTotals: [WebsiteTotal] = []

    func record(snapshot: ActivitySnapshot, at date: Date) {
        if let currentSnapshot = currentSnapshot, currentSnapshot == snapshot {
            updateCurrentActivityEndTime(to: date)
            return
        }

        if currentActivityId != nil {
            updateCurrentActivityEndTime(to: date)
        }

        let id = insertActivity(snapshot: snapshot, start: date, end: date)
        currentActivityId = id
        currentSnapshot = snapshot
    }

    func refreshTodayViews() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        latestSessions = fetchTimeline(from: startOfDay)
        latestAppTotals = fetchAppTotals(from: startOfDay)
        latestWebsiteTotals = fetchWebsiteTotals(from: startOfDay)
    }

    private func insertActivity(snapshot: ActivitySnapshot, start: Date, end: Date) -> Int64? {
        let sql = """
        INSERT INTO activities (start_time, end_time, app_name, bundle_id, window_title, url, website_host)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        let bindings: [SQLiteValue] = [
            .double(start.timeIntervalSince1970),
            .double(end.timeIntervalSince1970),
            .text(snapshot.appName),
            .text(snapshot.bundleId),
            snapshot.windowTitle.map { .text($0) } ?? .null,
            snapshot.url.map { .text($0) } ?? .null,
            snapshot.websiteHost.map { .text($0) } ?? .null
        ]
        if db.execute(sql: sql, bindings: bindings) {
            let row = db.query(sql: "SELECT last_insert_rowid() AS id;", bindings: []).first
            return row?["id"]?.intValue
        }
        return nil
    }

    private func updateCurrentActivityEndTime(to date: Date) {
        guard let id = currentActivityId else { return }
        let sql = "UPDATE activities SET end_time = ? WHERE id = ?;"
        _ = db.execute(sql: sql, bindings: [.double(date.timeIntervalSince1970), .int(id)])
    }

    private func fetchTimeline(from startDate: Date) -> [ActivitySession] {
        let sql = """
        SELECT id, start_time, end_time, app_name, window_title, url, website_host
        FROM activities
        WHERE start_time >= ?
        ORDER BY start_time DESC
        LIMIT 300;
        """
        let rows = db.query(sql: sql, bindings: [.double(startDate.timeIntervalSince1970)])
        return rows.compactMap { row in
            guard
                let id = row["id"]?.intValue,
                let start = row["start_time"]?.doubleValue,
                let end = row["end_time"]?.doubleValue,
                let app = row["app_name"]?.textValue
            else { return nil }
            return ActivitySession(
                id: id,
                start: Date(timeIntervalSince1970: start),
                end: Date(timeIntervalSince1970: end),
                appName: app,
                windowTitle: row["window_title"]?.textValue,
                url: row["url"]?.textValue,
                websiteHost: row["website_host"]?.textValue
            )
        }
    }

    private func fetchAppTotals(from startDate: Date) -> [AppTotal] {
        let sql = """
        SELECT app_name, SUM(end_time - start_time) AS total
        FROM activities
        WHERE start_time >= ?
        GROUP BY app_name
        ORDER BY total DESC
        LIMIT 100;
        """
        let rows = db.query(sql: sql, bindings: [.double(startDate.timeIntervalSince1970)])
        return rows.compactMap { row in
            guard
                let app = row["app_name"]?.textValue,
                let total = row["total"]?.doubleValue
            else { return nil }
            return AppTotal(appName: app, duration: total)
        }
    }

    private func fetchWebsiteTotals(from startDate: Date) -> [WebsiteTotal] {
        let sql = """
        SELECT website_host, SUM(end_time - start_time) AS total
        FROM activities
        WHERE start_time >= ? AND website_host IS NOT NULL
        GROUP BY website_host
        ORDER BY total DESC
        LIMIT 100;
        """
        let rows = db.query(sql: sql, bindings: [.double(startDate.timeIntervalSince1970)])
        return rows.compactMap { row in
            guard
                let host = row["website_host"]?.textValue,
                let total = row["total"]?.doubleValue
            else { return nil }
            return WebsiteTotal(host: host, duration: total)
        }
    }
}
