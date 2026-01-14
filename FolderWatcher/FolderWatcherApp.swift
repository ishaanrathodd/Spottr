import SwiftUI
import Combine

@main
struct FolderWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isWatching ? "binoculars.fill" : "binoculars")
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowController.shared.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global hotkeys using Carbon API
        setupHotKeys()
        
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)
        
        // Prevent stealing focus on launch (especially when running from Xcode)
        NSApp.deactivate()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotKey.shared.unregisterAll()
    }
    
    func setupHotKeys() {
        let settings = SettingsManager.shared
        
        // If shortcuts are the same, register one hotkey that toggles
        if settings.shortcutsAreSame {
            GlobalHotKey.shared.register(
                id: .startWatching,
                keyCode: settings.startShortcutKeyCode,
                modifiers: settings.startShortcutModifiers
            ) {
                AppState.shared.toggleWatching()
            }
            // Unregister the stop hotkey if it was previously different
            GlobalHotKey.shared.unregister(id: .stopWatching)
        } else {
            // Register separate start and stop hotkeys
            GlobalHotKey.shared.register(
                id: .startWatching,
                keyCode: settings.startShortcutKeyCode,
                modifiers: settings.startShortcutModifiers
            ) {
                if !AppState.shared.isWatching {
                    AppState.shared.startWatching()
                }
            }
            
            GlobalHotKey.shared.register(
                id: .stopWatching,
                keyCode: settings.stopShortcutKeyCode,
                modifiers: settings.stopShortcutModifiers
            ) {
                if AppState.shared.isWatching {
                    AppState.shared.stopWatching()
                }
            }
        }
    }
    
    func updateHotKeys() {
        setupHotKeys()
    }
    
    @objc func openSettings() {
        SettingsWindowController.shared.openSettings()
    }
}