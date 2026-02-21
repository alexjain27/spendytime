# SpendyTime

SpendyTime is a macOS menu-bar app that tracks active app and browser usage, showing a timeline plus daily totals. It’s designed for lightweight time awareness and easy export.

## Primary Use Case
You sit down to work. Hours later: "Oh no, I didn't track my time. When did I start? What was I working on? When did I take a break?"

SpendyTime answers those questions automatically—no start/stop timers, no remembering to click anything. It shows what you did and when you did it.

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

## Distributing Without Xcode
End users do not need Xcode. Build and package a `.app` once, then distribute it as a zip or dmg:

```bash
./scripts/package-macos.sh
```

The app bundle will be at:
`build/SpendyTime.app`

### SQLCipher Dependency (Required)
SpendyTime encrypts its local database with SQLCipher. Install it before building:
```bash
brew install sqlcipher
```

If you have SQLCipher in a non-standard location, pass:
```bash
LIBSQLCIPHER_PATH="/path/to/libsqlcipher.dylib" ./scripts/package-macos.sh
```

### Versioning
Override the app version when packaging:
```bash
./scripts/package-macos.sh --version 1.2.3
```

### App Icon
Provide a 1024x1024 PNG to generate an `.icns` bundle icon:
```bash
./scripts/package-macos.sh --icon /path/to/icon-1024.png
```

### DMG
Create a DMG installer:
```bash
./scripts/package-macos.sh --dmg
```

### Optional: Code Signing
To avoid Gatekeeper warnings for external distribution, sign and notarize:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package-macos.sh
```

Then notarize with:
```bash
xcrun notarytool submit "build/SpendyTime.app" --keychain-profile "YOUR_PROFILE" --wait
```

## Data Location
SQLite database is stored at:
`~/Library/Application Support/SpendyTime/spendytime.sqlite`

## Data Security
- Database is encrypted at rest using SQLCipher.
- App data directory is created with `0700` permissions; DB file uses `0600`.
- Encryption key is stored in the user's Keychain (per-user access).
