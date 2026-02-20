import Foundation

struct ActivitySnapshot: Equatable {
    let appName: String
    let bundleId: String
    let windowTitle: String?
    let url: String?
    let websiteHost: String?
}

struct ActivitySession: Identifiable {
    let id: Int64
    let start: Date
    let end: Date
    let appName: String
    let windowTitle: String?
    let url: String?
    let websiteHost: String?

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }
}

struct AppTotal: Identifiable {
    let id = UUID()
    let appName: String
    let duration: TimeInterval
}

struct WebsiteTotal: Identifiable {
    let id = UUID()
    let host: String
    let duration: TimeInterval
}
