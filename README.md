# Spottr

A native macOS menu bar app that watches a folder for new files and copies their paths to your clipboard.

## Purpose

This app is designed to help you quickly collect file paths. I made it for my use with AI agents (like GLM 4.7) that require file paths instead of direct file attachments for image analysis.

## Features

<img width="303" height="308" alt="image" src="https://github.com/user-attachments/assets/ec3a9c75-6d67-446c-afb7-0e61c22dca47" /> <img width="525" height="531" alt="image" src="https://github.com/user-attachments/assets/72df5354-582b-4237-8ec3-8e95e1eda09c" />



- **Native macOS UI** - Built with SwiftUI for authentic macOS experience
- **Global Keyboard Shortcut** - Toggle watching from anywhere (default: ⌃⇧W)
- **Folder Watching** - Monitor any folder for new files using FSEvents
- **Clipboard Integration** - Automatically copies all collected paths to clipboard when stopping
- **Settings Panel** - Native macOS settings for configuring shortcut and folder
- **Menu Bar App** - Runs in menu bar, no dock icon

## How It Works

1. **Click the menu bar icon** (folder icon)
2. **Select a folder** to watch using the "Browse..." button
3. **Press `⌃⇧W`** or click "Start Watching"
4. **Add files** to the watched folder
5. **Press `⌃⇧W` again** to stop - all paths are copied to clipboard
6. **Paste the paths** into your AI agent!

## Default Shortcut

`Control + Shift + W` (⌃⇧W)

You can change this in Settings (gear icon in the menu bar dropdown).

## Output Format

When multiple files are collected, paths are copied as a comma-separated list:
```
/path/to/file1.png, /path/to/file2.jpg, /path/to/file3.webp
```

## Building

### Requirements
- macOS 13.0+
- Xcode 15.0+

### Build Steps

1. Open the project in Xcode:
   ```bash
   open FolderWatcher.xcodeproj
   ```

2. Select "My Mac" as the build target

3. Press ⌘B to build or ⌘R to build and run

## Technical Details

- **File System Monitoring**: Uses `FSEvents` API for efficient, low-overhead folder monitoring
- **Global Shortcuts**: Uses `NSEvent.addGlobalMonitorForEvents` for system-wide hotkey capture
- **Settings Storage**: Uses `UserDefaults` for persistent settings
- **No Sandbox**: App runs unsandboxed to allow global hotkey access and file system monitoring

## Use Case

This app is perfect for workflows where you need to:
- Quickly collect multiple image paths for AI analysis
- Work with AI agents that need file system paths (like GLM 4.7 with Vision MCP Server)
- Batch collect file paths for any purpose
