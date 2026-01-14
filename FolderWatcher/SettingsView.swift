import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    // Start shortcut state
    @State private var isRecordingStartShortcut = false
    @State private var startModifiers: NSEvent.ModifierFlags = []
    @State private var startKeyCode: UInt16 = 0
    
    // Stop shortcut state
    @State private var isRecordingStopShortcut = false
    @State private var stopModifiers: NSEvent.ModifierFlags = []
    @State private var stopKeyCode: UInt16 = 0
    
    @State private var singleFileTemplate: String = ""
    @State private var multipleFilesTemplate: String = ""
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Watch Folder", systemImage: "folder")
                    
                    Spacer()
                    
                    if appState.watchFolder.isEmpty {
                        Text("Not selected")
                            .foregroundColor(.secondary)
                    } else {
                        Text(shortPath(appState.watchFolder))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 200, alignment: .trailing)
                    }
                    
                    Button("Choose...") {
                        appState.selectFolder()
                    }
                }
            } header: {
                Text("General")
            }
            
            Section {
                HStack {
                    Label("Start Watching", systemImage: "play.circle")
                    
                    Spacer()
                    
                    ShortcutRecorderView(
                        shortcutType: .start,
                        isRecording: $isRecordingStartShortcut,
                        modifiers: $startModifiers,
                        keyCode: $startKeyCode,
                        otherRecording: $isRecordingStopShortcut
                    )
                }
                
                HStack {
                    Label("Stop Watching", systemImage: "stop.circle")
                    
                    Spacer()
                    
                    ShortcutRecorderView(
                        shortcutType: .stop,
                        isRecording: $isRecordingStopShortcut,
                        modifiers: $stopModifiers,
                        keyCode: $stopKeyCode,
                        otherRecording: $isRecordingStartShortcut
                    )
                }
                
                Text("If both shortcuts are the same, it acts as a toggle. Set different shortcuts to have separate start/stop keys.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Keyboard Shortcuts")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Single File Template")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Template for single file", text: $singleFileTemplate)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: singleFileTemplate) { newValue in
                            SettingsManager.shared.singleFileTemplate = newValue
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multiple Files Template")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Template for multiple files", text: $multipleFilesTemplate)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: multipleFilesTemplate) { newValue in
                            SettingsManager.shared.multipleFilesTemplate = newValue
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use {path} as a placeholder for the file path(s).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Example: \"analyze this image: {path}\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            } header: {
                Text("Clipboard Templates")
            }
            
            Section {
                Text("Spottr monitors a folder for new files and collects their paths. When you stop watching, all paths are automatically copied to your clipboard with the configured template.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 520)
        .onAppear {
            // Load start shortcut
            startModifiers = SettingsManager.shared.startShortcutModifiers
            startKeyCode = SettingsManager.shared.startShortcutKeyCode
            // Load stop shortcut
            stopModifiers = SettingsManager.shared.stopShortcutModifiers
            stopKeyCode = SettingsManager.shared.stopShortcutKeyCode
            // Load templates
            singleFileTemplate = SettingsManager.shared.singleFileTemplate
            multipleFilesTemplate = SettingsManager.shared.multipleFilesTemplate
        }
    }
    
    private func shortPath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        if components.count > 2 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return path
    }
}

enum ShortcutType {
    case start
    case stop
}

struct ShortcutRecorderView: View {
    let shortcutType: ShortcutType
    @Binding var isRecording: Bool
    @Binding var modifiers: NSEvent.ModifierFlags
    @Binding var keyCode: UInt16
    @Binding var otherRecording: Bool  // To stop the other recorder if active
    
    @State private var localEventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                // Stop the other recorder if it's active
                if otherRecording {
                    otherRecording = false
                }
                startRecording()
            }
        }) {
            HStack(spacing: 2) {
                if isRecording {
                    Text("Press shortcut...")
                        .foregroundColor(.accentColor)
                } else {
                    Text(displayString)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var displayString: String {
        var parts: [String] = []
        
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        
        parts.append(keyCodeToString(keyCode))
        
        return parts.joined()
    }
    
    private func startRecording() {
        isRecording = true
        
        // Temporarily unregister all hotkeys so they don't interfere with recording
        // (allows setting the same shortcut for both start and stop)
        GlobalHotKey.shared.unregisterAll()
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check for Escape to cancel
            if event.keyCode == 53 { // Escape
                self.stopRecording(cancelled: true)
                return nil
            }
            
            // Extract only the modifiers we care about (not numericPad, function, etc.)
            var cleanMods: NSEvent.ModifierFlags = []
            if event.modifierFlags.contains(.control) { cleanMods.insert(.control) }
            if event.modifierFlags.contains(.option) { cleanMods.insert(.option) }
            if event.modifierFlags.contains(.shift) { cleanMods.insert(.shift) }
            if event.modifierFlags.contains(.command) { cleanMods.insert(.command) }
            
            // Need at least one modifier
            if cleanMods.isEmpty {
                return event
            }
            
            // Record the shortcut with clean modifiers only
            self.modifiers = cleanMods
            self.keyCode = event.keyCode
            
            // Save to settings based on shortcut type
            switch self.shortcutType {
            case .start:
                SettingsManager.shared.startShortcutModifiers = cleanMods
                SettingsManager.shared.startShortcutKeyCode = event.keyCode
            case .stop:
                SettingsManager.shared.stopShortcutModifiers = cleanMods
                SettingsManager.shared.stopShortcutKeyCode = event.keyCode
            }
            
            // Re-register ALL hotkeys directly (AppDelegate cast can fail in Settings window context)
            let settings = SettingsManager.shared
            
            if settings.shortcutsAreSame {
                // Same shortcut = toggle mode
                GlobalHotKey.shared.register(
                    id: .startWatching,
                    keyCode: settings.startShortcutKeyCode,
                    modifiers: settings.startShortcutModifiers
                ) {
                    AppState.shared.toggleWatching()
                }
                GlobalHotKey.shared.unregister(id: .stopWatching)
            } else {
                // Different shortcuts = separate start/stop
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
            
            // Update the menu bar display
            AppState.shared.updateShortcutDisplay()
            
            self.stopRecording()
            return nil
        }
    }
    
    private func stopRecording(cancelled: Bool = false) {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // If cancelled, re-register the existing hotkeys
        if cancelled {
            reregisterHotkeys()
        }
    }
    
    private func reregisterHotkeys() {
        let settings = SettingsManager.shared
        
        if settings.shortcutsAreSame {
            GlobalHotKey.shared.register(
                id: .startWatching,
                keyCode: settings.startShortcutKeyCode,
                modifiers: settings.startShortcutModifiers
            ) {
                AppState.shared.toggleWatching()
            }
        } else {
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
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyCodeMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`"
        ]
        return keyCodeMap[keyCode] ?? "?"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}