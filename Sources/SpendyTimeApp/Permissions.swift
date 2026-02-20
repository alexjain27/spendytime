import Foundation
import AppKit
import ApplicationServices

final class PermissionCenter: ObservableObject {
    @Published private(set) var accessibilityGranted: Bool = AXIsProcessTrusted()
    @Published private(set) var safariAutomationGranted: Bool = false
    @Published private(set) var chromeAutomationGranted: Bool = false
    @Published private(set) var safariInstalled: Bool = true
    @Published private(set) var chromeInstalled: Bool = true

    private var timer: Timer?
    private let browserScripts = BrowserScriptRunner()

    init() {
        startPolling()
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 1
        refresh()
    }

    func refresh() {
        let newValue = AXIsProcessTrusted()
        if newValue != accessibilityGranted {
            accessibilityGranted = newValue
        }

        let safariIsInstalled = BrowserInstallChecker.isInstalled(browser: .safari)
        if safariIsInstalled != safariInstalled {
            safariInstalled = safariIsInstalled
        }
        let chromeIsInstalled = BrowserInstallChecker.isInstalled(browser: .chrome)
        if chromeIsInstalled != chromeInstalled {
            chromeInstalled = chromeIsInstalled
        }

        let safariValue = safariIsInstalled ? browserScripts.canAccess(browser: .safari) : true
        if safariValue != safariAutomationGranted {
            safariAutomationGranted = safariValue
        }

        let chromeValue = chromeIsInstalled ? browserScripts.canAccess(browser: .chrome) : true
        if chromeValue != chromeAutomationGranted {
            chromeAutomationGranted = chromeValue
        }
    }

    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        openSystemSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openAutomationSettings() {
        openSystemSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private func openSystemSettings(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

enum BrowserInstallChecker {
    static func isInstalled(browser: BrowserType) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleId) != nil
    }
}
