# Spottr v1.1.0 Release Notes

## 🎉 What's New

### ⌨️ Separate Start/Stop Shortcuts
You can now configure **different keyboard shortcuts** for starting and stopping the folder watcher!

- **Start Watching Shortcut** - Trigger to begin monitoring your folder
- **Stop Watching Shortcut** - Trigger to stop and copy paths to clipboard
- **Toggle Mode** - Set both to the same shortcut for classic toggle behavior

### 🐛 Bug Fixes

- **Fixed shortcut recording issues** - Option key was being incorrectly interpreted as Command key
- **Fixed modifier persistence** - Shortcuts are now stored reliably and won't reset unexpectedly
- **Fixed live shortcut updates** - Changing shortcuts in Settings now takes effect immediately without restarting the app
- **Fixed shortcut conflicts** - You can now set the same shortcut for both Start and Stop (enables toggle mode)

### ✨ Improvements

- **Better shortcut display** - Menu bar now shows both shortcuts if they're different (e.g., `⌘1 / ⌘2`)
- **Improved Settings UI** - Separate fields for Start and Stop shortcuts with clear icons
- **Enhanced reliability** - Hotkeys are properly managed when recording new shortcuts

---

## 📦 Installation

1. Download `Spottr.dmg`
2. Open the DMG file
3. Drag **Spottr** to your Applications folder
4. Launch Spottr from Applications
5. Grant Accessibility permissions when prompted (required for global shortcuts)

## ⚙️ Configuration

1. Click the Spottr icon in the menu bar
2. Click the gear (⚙️) icon to open Settings
3. Configure your preferred shortcuts and watch folder
4. Set clipboard templates for single/multiple files

## 🔧 System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## 📝 Default Shortcuts

- **Start Watching**: `⌃⇧W` (Control + Shift + W)
- **Stop Watching**: `⌃⇧W` (Control + Shift + W)

Both default to the same shortcut, acting as a toggle.

---

## 🔗 Links

- [GitHub Repository](https://github.com/ishaanrathod/Spottr)
- [Report Issues](https://github.com/ishaanrathod/Spottr/issues)

---

**Full Changelog**: v1.0.0...v1.1.0
