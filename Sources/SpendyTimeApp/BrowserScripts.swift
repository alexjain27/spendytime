import Foundation
import AppKit

enum BrowserType: String {
    case safari = "Safari"
    case chrome = "Google Chrome"

    var bundleId: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        }
    }

    var appName: String { rawValue }
}

struct BrowserActivity {
    let url: String?
    let title: String?
    let host: String?
}

final class BrowserScriptRunner {
    // Toggle to use NSAppleScript instead of launching osascript
    private let useNSAppleScript: Bool = false

    // Cooldown to avoid spamming AppleScript calls when permission is denied
    private var denyCooldownUntil: Date = .distantPast
    private let denyCooldownInterval: TimeInterval = 60 // seconds

    struct ScriptResult {
        let output: String
        let exitCode: Int32
    }

    func fetchActiveTab(for browser: BrowserType) -> BrowserActivity {
        // Respect cooldown if we recently detected denied permissions or errors
        if Date() < denyCooldownUntil {
            // Skipping AppleScript calls due to cooldown
            return BrowserActivity(url: nil, title: nil, host: nil)
        }
        switch browser {
        case .safari:
            return runSafariScript()
        case .chrome:
            return runChromeScript()
        }
    }

    private func runSafariScript() -> BrowserActivity {
        let script = """
        tell application "Safari"
            if not (exists document 1) then return ""
            set theURL to URL of current tab of document 1
            set theTitle to name of current tab of document 1
            return theURL & "||" & theTitle
        end tell
        """
        let result = runScript(script)
        if result.exitCode != 0 {
            print("[AppleScript][Safari] Error: \(result.output)")
            // If it's a permission-related error, back off for a while
            denyCooldownUntil = Date().addingTimeInterval(denyCooldownInterval)
            return BrowserActivity(url: nil, title: nil, host: nil)
        }
        return parseResult(result.output)
    }

    private func runChromeScript() -> BrowserActivity {
        let script = """
        tell application "Google Chrome"
            if not (exists active tab of front window) then return ""
            set theURL to URL of active tab of front window
            set theTitle to title of active tab of front window
            return theURL & "||" & theTitle
        end tell
        """
        let result = runScript(script)
        if result.exitCode != 0 {
            print("[AppleScript][Chrome] Error: \(result.output)")
            denyCooldownUntil = Date().addingTimeInterval(denyCooldownInterval)
            return BrowserActivity(url: nil, title: nil, host: nil)
        }
        return parseResult(result.output)
    }

    func canAccess(browser: BrowserType) -> Bool {
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application "Safari"
                return count of windows
            end tell
            """
        case .chrome:
            script = """
            tell application "Google Chrome"
                return count of windows
            end tell
            """
        }
        if Date() < denyCooldownUntil {
            // In cooldown; report inaccessible without hitting AppleScript
            return false
        }
        let result = runScript(script)
        if result.exitCode != 0 {
            print("[AppleScript][Access][\(browser.appName)] Error: \(result.output)")
            denyCooldownUntil = Date().addingTimeInterval(denyCooldownInterval)
        }
        return result.exitCode == 0
    }

    private func runScript(_ source: String) -> ScriptResult {
        if useNSAppleScript {
            return runAppleScriptInProcess(source)
        } else {
            return runAppleScript(source)
        }
    }

    private func runAppleScriptInProcess(_ source: String) -> ScriptResult {
        // NSAppleScript still requires Automation permission. Errors will be returned in the error dict.
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: source)
        let outputDesc = script?.executeAndReturnError(&errorDict)
        if let error = errorDict {
            return ScriptResult(output: String(describing: error), exitCode: 1)
        }
        let output = outputDesc?.stringValue ?? ""
        return ScriptResult(output: output, exitCode: 0)
    }

    private func runAppleScript(_ source: String) -> ScriptResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ScriptResult(output: "", exitCode: -1)
        }

        // Add a timeout to avoid indefinite hangs
        let timeout: TimeInterval = 5
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        if process.isRunning {
            process.terminate()
        }

        process.waitUntilExit()

        let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 && !errorOutput.isEmpty {
            return ScriptResult(output: errorOutput, exitCode: process.terminationStatus)
        }

        return ScriptResult(output: output, exitCode: process.terminationStatus)
    }

    private func parseResult(_ result: String) -> BrowserActivity {
        guard !result.isEmpty else {
            return BrowserActivity(url: nil, title: nil, host: nil)
        }
        let parts = result.components(separatedBy: "||")
        let urlString = parts.first
        let title = parts.count > 1 ? parts[1] : nil
        let host = urlString.flatMap { URL(string: $0)?.host }
        return BrowserActivity(url: urlString, title: title, host: host)
    }
}
