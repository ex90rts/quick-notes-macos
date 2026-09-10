# Quick Notes

A lightweight, Apple Silicon-native macOS menu bar notes app built with SwiftUI.

## Requirements

- macOS 15 or later
- Apple Silicon (arm64)
- Xcode 16+ with the matching Command Line Tools

## Features

- Add plain-text notes with optional titles and tags
- Filter by tag and search note titles or content
- Manage tags in Settings with validations
- Export all notes as a Markdown document from Settings
- Copy, delete, expand/collapse notes
- Local SwiftData persistence

## Build & Run

### Using Xcode

1. Open `QuickNotes.xcodeproj`
2. Choose the shared `QuickNotes` scheme
3. Run the app with `⌘R`, or run the test suite with `⌘U`

The Xcode project and `Package.swift` reference the same source and test files.

### Using Terminal

Build explicitly for Apple Silicon with SwiftPM:

```sh
cd quick-notes-macos
swift build --arch arm64
swift run QuickNotes
```

Run the tests with `swift test --arch arm64`.

### Release package

With Xcode selected as the active developer directory, build, test, ad-hoc sign, and package the current version with:

```sh
./scripts/build-release.sh
```

The Apple Silicon `.app`, versioned zip archive, and disk image are written to `dist/`:

- `QuickNotes.app`
- `QuickNotes-<version>-macOS-arm64.zip`
- `QuickNotes-<version>-macOS-arm64.dmg`

## Storage

Notes and tags are stored as independent SwiftData records in `~/Library/Application Support/QuickNotes/QuickNotes.store`.
