import Cocoa
import SwiftUI

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    private var windowController: NSWindowController?
    
    private override init() {
        super.init()
    }
    
    func openSettings() {
        NSApp.setActivationPolicy(.regular)
        
        NSApp.activate(ignoringOtherApps: true)
        
        if window == nil {
            let settingsView = SettingsView()
                .environmentObject(AppState.shared)
                .frame(width: 500, height: 480)
            
            let hostingController = NSHostingController(rootView: settingsView)
            
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            newWindow.title = "Settings"
            newWindow.contentViewController = hostingController
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            
            newWindow.level = .normal
            newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            self.window = newWindow
            self.windowController = NSWindowController(window: newWindow)
        }
        
        if let window = self.window {
            window.contentView?.layoutSubtreeIfNeeded()
            
            if let screen = window.screen ?? NSScreen.main {
                let screenRect = screen.visibleFrame
                let width: CGFloat = 500
                let height: CGFloat = 480
                
                let newX = screenRect.origin.x + (screenRect.width - width) / 2
                let newY = screenRect.origin.y + (screenRect.height - height) / 2 + 30
                
                window.setFrame(NSRect(x: newX, y: newY, width: width, height: height), display: true)
            } else {
                window.center()
            }
            
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}