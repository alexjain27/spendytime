import SwiftUI
import AppKit

@main
struct SpendyTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tracker: ActivityTracker?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = ActivityStore()
        let tracker = ActivityTracker(store: store)
        self.tracker = tracker
        tracker.start()

        let contentView = MenuBarRootView(store: store)
        let hostingController = NSHostingController(rootView: contentView)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hostingController
        self.popover = popover

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "SpendyTime"
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        self.statusItem = statusItem
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
