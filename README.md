# SpendyTime

SpendyTime is a macOS menu-bar app that tracks active app and browser usage, showing a timeline plus daily totals. It’s designed for lightweight time awareness and easy export.

## Features
- Menu-bar popover with timeline, app totals, and website totals
- Safari + Chrome tab tracking (URL + title)
- Idle detection (pauses tracking after 5 minutes of inactivity)
- CSV export for daily activity
- Local SQLite storage

## Quick Start
1. Open `Package.swift` in Xcode.
2. Select the `SpendyTime` scheme and press `Command + R`.
3. Click the **SpendyTime** menu-bar icon to view the tracker.

## Permissions
SpendyTime needs:
- **Accessibility** for window titles (non-browser apps).
- **Automation** for Safari and Chrome tab details.

Use the permission cards in the popover to open System Settings and trigger prompts.

## Exporting CSV
Click **Export CSV** in the popover. The exported file includes:
`start_time, end_time, app_name, window_title, url, website_host, duration_seconds`

## Idle Detection
Tracking pauses after 5 minutes of inactivity. When you’re idle, the current session is ended and no new sessions are recorded until activity resumes.

## Xcode Project
This repo is a Swift Package. You can open it directly in Xcode by double-clicking `Package.swift`.

If you want a `.xcodeproj`, run:
```bash
swift package generate-xcodeproj
```

## Data Location
SQLite database is stored at:
`~/Library/Application Support/SpendyTime/spendytime.sqlite`
