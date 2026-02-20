import SwiftUI
import AppKit

struct MenuBarRootView: View {
    @ObservedObject var store: ActivityStore
    @State private var selection: Int = 0
    @StateObject private var permissions = PermissionCenter()
    private let browserScripts = BrowserScriptRunner()

    var body: some View {
        VStack(spacing: 12) {
            if !permissions.accessibilityGranted {
                PermissionCardView(
                    title: "Accessibility Needed",
                    message: "Enable Accessibility to capture window titles for non-browser apps.",
                    primaryButtonTitle: "Request",
                    primaryAction: {
                        permissions.requestAccessibilityPermission()
                    },
                    secondaryButtonTitle: "Open Settings",
                    secondaryAction: {
                        permissions.openAccessibilitySettings()
                    }
                )
            }

            if !(permissions.safariAutomationGranted && permissions.chromeAutomationGranted) {
                PermissionCardView(
                    title: "Browser Access",
                    message: "Allow Automation access so SpendyTime can read Safari and Chrome tabs.",
                    primaryButtonTitle: "Open Automation",
                    primaryAction: {
                        permissions.openAutomationSettings()
                    },
                    secondaryButtonTitle: "Trigger Prompt",
                    secondaryAction: {
                        _ = browserScripts.fetchActiveTab(for: .safari)
                        _ = browserScripts.fetchActiveTab(for: .chrome)
                    }
                )
            }

            Picker("View", selection: $selection) {
                Text("Timeline").tag(0)
                Text("Apps").tag(1)
                Text("Websites").tag(2)
            }
            .pickerStyle(.segmented)

            if selection == 0 {
                TimelineListView(sessions: store.latestSessions)
            } else if selection == 1 {
                TotalsListView(title: "Apps", items: store.latestAppTotals.map { ($0.appName, $0.duration) })
            } else {
                TotalsListView(title: "Websites", items: store.latestWebsiteTotals.map { ($0.host, $0.duration) })
            }

            HStack {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit SpendyTime") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut("q", modifiers: [.command])
                Button("Refresh") {
                    store.refreshTodayViews()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(width: 380, height: 420)
        .onAppear {
            store.refreshTodayViews()
            permissions.refresh()
        }
    }
}

struct TimelineListView: View {
    let sessions: [ActivitySession]

    var body: some View {
        List(sessions) { session in
            VStack(alignment: .leading, spacing: 4) {
                Text(session.appName)
                    .font(.headline)
                if let url = session.url {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let title = session.windowTitle {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack {
                    Text(timeRange(start: session.start, end: session.end))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(durationString(session.duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct TotalsListView: View {
    let title: String
    let items: [(String, TimeInterval)]

    var body: some View {
        List(items, id: \.0) { item in
            HStack {
                Text(item.0)
                    .lineLimit(1)
                Spacer()
                Text(durationString(item.1))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PermissionCardView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryAction: () -> Void
    let secondaryButtonTitle: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(primaryButtonTitle) { primaryAction() }
                    .buttonStyle(.borderedProminent)
                Button(secondaryButtonTitle) { secondaryAction() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

private func timeRange(start: Date, end: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
}

private func durationString(_ duration: TimeInterval) -> String {
    let totalSeconds = Int(duration)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}
