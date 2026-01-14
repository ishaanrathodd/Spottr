import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isWatching = false
    @Published var collectedPaths: [String] = []
    @Published var watchFolder: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var shortcutDisplayString: String = ""
    
    private var fileMonitor: FileMonitor?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load saved watch folder
        watchFolder = SettingsManager.shared.watchFolder
        // Load saved shortcut display string
        shortcutDisplayString = SettingsManager.shared.shortcutDisplayString
    }
    
    func updateShortcutDisplay() {
        shortcutDisplayString = SettingsManager.shared.shortcutDisplayString
    }
    
    func toggleWatching() {
        if isWatching {
            stopWatching()
        } else {
            startWatching()
        }
    }
    
    func startWatching() {
        guard !watchFolder.isEmpty else {
            statusMessage = "Please select a folder first"
            return
        }
        
        // Clear previous paths
        collectedPaths = []
        isWatching = true
        statusMessage = "Watching for new files..."
        
        // Start file monitoring
        fileMonitor = FileMonitor(path: watchFolder) { [weak self] newFilePath in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !self.collectedPaths.contains(newFilePath) {
                    self.collectedPaths.append(newFilePath)
                    self.statusMessage = "\(self.collectedPaths.count) file(s) collected"
                }
            }
        }
        fileMonitor?.start()
        
        // Register paste trigger automation if enabled
        if SettingsManager.shared.smartPasteEnabled {
            GlobalHotKey.shared.registerPasteTrigger { [weak self] in
                self?.handlePasteTrigger()
            }
        }
    }
    
    func stopWatching(discard: Bool = false) {
        // Unregister paste trigger immediately
        GlobalHotKey.shared.unregisterPasteTrigger()
        
        fileMonitor?.stop()
        fileMonitor = nil
        isWatching = false
        
        if discard {
            // Just clear paths and update status
            collectedPaths = []
            statusMessage = "Watch cancelled (Paste in unsupported app)"
            return
        }
        
        // Copy paths to clipboard with template formatting
        if !collectedPaths.isEmpty {
            let formattedContent = SettingsManager.shared.formatClipboardContent(paths: collectedPaths)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(formattedContent, forType: .string)
            statusMessage = "\(collectedPaths.count) path(s) copied to clipboard!"
        } else {
            statusMessage = "No files were added"
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to watch for new files"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            watchFolder = url.path
            SettingsManager.shared.watchFolder = url.path
            statusMessage = "Folder selected"
        }
    }
    
    func clearPaths() {
        collectedPaths = []
        statusMessage = "Cleared"
    }
    
    func removePath(at index: Int) {
        guard index < collectedPaths.count else { return }
        collectedPaths.remove(at: index)
    }
    
    private func handlePasteTrigger() {
        print("Paste trigger detected!")
        
        // Check if Smart Paste is enabled
        guard SettingsManager.shared.smartPasteEnabled else {
            // Loophole: If we registered the hotkey but it's disabled? 
            // Better to handle this at registration time or just stop normally.
            stopWatching()
            return // Or simulate paste of what we just deprecated? 
            // Actually if it's disabled, we shouldn't have registered it.
            // But if we did, default behavior: Stop & Copy (standard behavior)
        }
        
        // Get frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            // Can't identify app, default to stop & copy
            stopWatching()
            return
        }
        
        let pid = frontApp.processIdentifier
        print("Paste in app: \(bundleID) (PID: \(pid))")
        
        // Ensure the target app is definitely active/focused
        if let runningApp = NSRunningApplication(processIdentifier: pid) {
            runningApp.activate(options: .activateIgnoringOtherApps)
        }
        
        let allowedApps = SettingsManager.shared.allowedAppBundleIDs
        
        if allowedApps.contains(bundleID) {
            // ALLOWED APP: Stop Watch -> Copy Paths -> Paste
            stopWatching(discard: false)
            
            print("Performing Smart Paste (Allowed App)...")
            GlobalHotKey.shared.simulatePaste(to: pid)
        } else {
            // UNALLOWED APP: Stop Watch -> Discard Paths -> Paste Original
            stopWatching(discard: true)
            
            print("Performing Smart Paste (Unallowed App)...")
            GlobalHotKey.shared.simulatePaste(to: pid)
        }
    }
}