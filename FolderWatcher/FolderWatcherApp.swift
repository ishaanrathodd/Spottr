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
        // Register global hotkey using Carbon API
        setupHotKey()
        
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)
        
        // Prevent stealing focus on launch (especially when running from Xcode)
        NSApp.deactivate()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotKey.shared.unregister()
    }
    
    func setupHotKey() {
        let settings = SettingsManager.shared
        let keyCode = settings.shortcutKeyCode
        let modifiers = settings.shortcutModifiers
        
        GlobalHotKey.shared.register(keyCode: keyCode, modifiers: modifiers) {
            AppState.shared.toggleWatching()
        }
    }
    
    func updateHotKey() {
        setupHotKey()
    }
    
    @objc func openSettings() {
        SettingsWindowController.shared.openSettings()
    }
}