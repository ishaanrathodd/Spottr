import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    @State private var selectedIndexes = IndexSet()
    @State private var windowObserver: NSObjectProtocol?
    
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
                            selectedIndexes = IndexSet()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    FileListTableView(filePaths: $appState.collectedPaths, selectedIndexes: $selectedIndexes, onMenuAppear: {
                        // When menu appears, select all files
                        if !appState.collectedPaths.isEmpty {
                            selectedIndexes = IndexSet(integersIn: 0..<appState.collectedPaths.count)
                        }
                    })
                        .frame(minHeight: 120, maxHeight: 160)
                        .padding(.horizontal, 4)
                        .padding(.bottom)
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("Shortcut: \(appState.shortcutDisplayString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
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
        .onAppear {
            // When menu first appears, select all files
            if !appState.collectedPaths.isEmpty {
                selectedIndexes = IndexSet(integersIn: 0..<appState.collectedPaths.count)
            }
            
            // Set up observer for when window becomes key (menu opens)
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { _ in
                if !appState.collectedPaths.isEmpty {
                    selectedIndexes = IndexSet(integersIn: 0..<appState.collectedPaths.count)
                }
            }
        }
        .onDisappear {
            if let observer = windowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
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

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}