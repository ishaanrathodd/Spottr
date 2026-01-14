import SwiftUI
import Carbon.HIToolbox

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecordingShortcut = false
    @State private var tempModifiers: NSEvent.ModifierFlags = []
    @State private var tempKeyCode: UInt16 = 0
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
                    Label("Toggle Shortcut", systemImage: "keyboard")
                    
                    Spacer()
                    
                    ShortcutRecorderView(
                        isRecording: $isRecordingShortcut,
                        modifiers: $tempModifiers,
                        keyCode: $tempKeyCode
                    )
                }
                
                Text("This shortcut will start/stop folder watching from anywhere in macOS.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Keyboard Shortcut")
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
        .frame(width: 500, height: 480)
        .onAppear {
            tempModifiers = SettingsManager.shared.shortcutModifiers
            tempKeyCode = SettingsManager.shared.shortcutKeyCode
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

struct ShortcutRecorderView: View {
    @Binding var isRecording: Bool
    @Binding var modifiers: NSEvent.ModifierFlags
    @Binding var keyCode: UInt16
    
    @State private var localEventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
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
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check for Escape to cancel
            if event.keyCode == 53 { // Escape
                self.stopRecording()
                return nil
            }
            
            // Need at least one modifier
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.isEmpty {
                return event
            }
            
            // Record the shortcut
            self.modifiers = mods
            self.keyCode = event.keyCode
            
            // Save to settings
            SettingsManager.shared.shortcutModifiers = mods
            SettingsManager.shared.shortcutKeyCode = event.keyCode
            
            // Update the app's hotkey
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.updateHotKey()
            }
            
            self.stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
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