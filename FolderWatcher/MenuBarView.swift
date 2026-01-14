import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("Spottr")
                        .font(.headline)
                    
                    Spacer()
                }
                
                HStack {
                    Circle()
                        .fill(appState.isWatching ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Text(appState.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Watch Folder
            VStack(alignment: .leading, spacing: 8) {
                Text("Watch Folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    if appState.watchFolder.isEmpty {
                        Text("No folder selected")
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(shortPath(appState.watchFolder))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        appState.selectFolder()
                    }) {
                        Text("Browse...")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            
            Divider()
            
            // Toggle Button
            Button(action: {
                appState.toggleWatching()
            }) {
                HStack {
                    Image(systemName: appState.isWatching ? "stop.fill" : "play.fill")
                    Text(appState.isWatching ? "Stop & Copy Paths" : "Start Watching")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.isWatching ? .red : .accentColor)
            .controlSize(.large)
            .padding()
            .disabled(appState.watchFolder.isEmpty && !appState.isWatching)
            
            // Collected Files
            if !appState.collectedPaths.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Collected Files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Clear") {
                            appState.clearPaths()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(appState.collectedPaths.enumerated()), id: \.offset) { index, path in
                                HStack {
                                    Image(systemName: "doc")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        appState.removePath(at: index)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Shortcut: \(appState.shortcutDisplayString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    // Add a slight delay to allow the menu interaction to complete
                    // effectively simulating a fresh activation like the hotkey
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                         SettingsWindowController.shared.openSettings()
                    }
                }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300)
    }
    
    private func shortPath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        if components.count > 2 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return path
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}