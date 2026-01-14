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
    }
    
    func stopWatching() {
        fileMonitor?.stop()
        fileMonitor = nil
        isWatching = false
        
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
}