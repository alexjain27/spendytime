import Foundation
import AppKit
import ApplicationServices

final class ActivityTracker {
    private let store: ActivityStore
    private let browserScripts = BrowserScriptRunner()
    private var timer: Timer?

    private let pollInterval: TimeInterval = 10

    init(store: ActivityStore) {
        self.store = store
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 2
        poll()
    }

    private func poll() {
        let now = Date()
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let appName = frontmost.localizedName,
              let bundleId = frontmost.bundleIdentifier
        else { return }

        var windowTitle: String? = nil
        var url: String? = nil
        var host: String? = nil

        if bundleId == BrowserType.safari.bundleId {
            let activity = browserScripts.fetchActiveTab(for: .safari)
            url = activity.url
            host = activity.host
            windowTitle = activity.title
        } else if bundleId == BrowserType.chrome.bundleId {
            let activity = browserScripts.fetchActiveTab(for: .chrome)
            url = activity.url
            host = activity.host
            windowTitle = activity.title
        } else {
            windowTitle = AccessibilityHelper.frontWindowTitle(for: frontmost.processIdentifier)
        }

        let snapshot = ActivitySnapshot(
            appName: appName,
            bundleId: bundleId,
            windowTitle: windowTitle,
            url: url,
            websiteHost: host
        )
        store.record(snapshot: snapshot, at: now)
        store.refreshTodayViews()
    }
}

enum AccessibilityHelper {
    static func frontWindowTitle(for pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var windowRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard result == .success, let window = windowRef else { return nil }

        var titleRef: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
        guard titleResult == .success else { return nil }
        return titleRef as? String
    }
}
