import Foundation
import Carbon
import AppKit
import os.log
import AppKit
import os.log
import CoreGraphics
import ApplicationServices

private let logger = Logger(subsystem: "com.ishaanrathod.FolderWatcher", category: "GlobalHotKey")

/// Enum to identify different hotkeys
enum HotKeyID: UInt32 {
    case startWatching = 1
    case stopWatching = 2
    case pasteTrigger = 3
}

/// A class that manages global hotkey registration using Carbon APIs
/// This is the proper way to register system-wide hotkeys that work from any application
final class GlobalHotKey {
    
    // MARK: - Types
    
    typealias Handler = () -> Void
    
    // MARK: - Singleton
    
    static let shared = GlobalHotKey()
    
    // MARK: - Properties
    
    private struct HotKeyInfo {
        var ref: EventHotKeyRef?
        var handler: Handler
    }
    
    private var hotKeys: [UInt32: HotKeyInfo] = [:]
    private var eventHandler: EventHandlerRef?
    
    private static var carbonEventSignature: UInt32 = {
        // FourCharCode for "FWHk" (FolderWatcher HotKey)
        let string = "FWHk"
        var result: FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Register a global hotkey with the given key code, modifiers, and ID
    /// - Parameters:
    ///   - id: The hotkey identifier
    ///   - keyCode: The virtual key code (same as NSEvent.keyCode)
    ///   - modifiers: The modifier flags (NSEvent.ModifierFlags)
    ///   - handler: The closure to call when the hotkey is pressed
    func register(id: HotKeyID, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, handler: @escaping Handler) {
        // Unregister any existing hotkey with this ID first
        unregister(id: id)
        
        // Convert NSEvent.ModifierFlags to Carbon modifiers
        let carbonMods = carbonModifiers(from: modifiers)
        
        // Debug logging
        var modNames: [String] = []
        if modifiers.contains(.control) { modNames.append("Control") }
        if modifiers.contains(.option) { modNames.append("Option") }
        if modifiers.contains(.shift) { modNames.append("Shift") }
        if modifiers.contains(.command) { modNames.append("Command") }
        logger.info("Attempting to register \(String(describing: id)) - keyCode: \(keyCode), modifiers: \(modNames.joined(separator: "+")) (carbon: \(carbonMods))")
        
        // Install the event handler if not already installed
        if eventHandler == nil {
            installEventHandler()
        }
        
        // Register the hotkey
        var hotKeyRef: EventHotKeyRef?
        let hotKeyEventID = EventHotKeyID(signature: GlobalHotKey.carbonEventSignature, id: id.rawValue)
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonMods,
            hotKeyEventID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            hotKeys[id.rawValue] = HotKeyInfo(ref: hotKeyRef, handler: handler)
            logger.info("Successfully registered \(String(describing: id)) (keyCode: \(keyCode), carbonModifiers: \(carbonMods))")
        } else {
            logger.error("Failed to register \(String(describing: id)), error: \(status)")
        }
    }
    
    /// Legacy register method for backward compatibility (uses startWatching ID)
    func register(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, handler: @escaping Handler) {
        register(id: .startWatching, keyCode: keyCode, modifiers: modifiers, handler: handler)
    }
    
    /// Unregister a specific hotkey by ID
    func unregister(id: HotKeyID) {
        if let info = hotKeys[id.rawValue], let ref = info.ref {
            UnregisterEventHotKey(ref)
            hotKeys.removeValue(forKey: id.rawValue)
            logger.info("Unregistered \(String(describing: id))")
        }
    }
    
    /// Unregister all hotkeys
    func unregisterAll() {
        for (id, info) in hotKeys {
            if let ref = info.ref {
                UnregisterEventHotKey(ref)
            }
            logger.info("Unregistered hotkey ID \(id)")
        }
    }
    
    // MARK: - Paste Automation
    
    func registerPasteTrigger(handler: @escaping Handler) {
        // kVK_ANSI_V is 0x09
        register(id: .pasteTrigger, keyCode: 0x09, modifiers: [.command], handler: handler)
    }
    
    func unregisterPasteTrigger() {
        unregister(id: .pasteTrigger)
    }
    
    func simulatePaste(to pid: pid_t) {
        // Diagnostic: Check Accessibility Permissions
        let isTrusted = AXIsProcessTrusted()
        logger.info("AXIsProcessTrusted: \(isTrusted)")
        if !isTrusted {
            logger.error("⚠️ App does not have Accessibility permissions! Simulated paste will likely fail.")
        }
    
        // Wait for physical key release before simulating events
        waitForKeyRelease { [weak self] in
            guard let self = self else { return }
            
            // Check focus before we start
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                 logger.info("Frontmost App before paste: \(frontApp.bundleIdentifier ?? "unknown") (PID: \(frontApp.processIdentifier))")
            }
            
            // 1. Try Accessibility API (Edit -> Paste)
            if self.pasteViaAccessibility(pid: pid) {
                logger.info("Successfully pasted via Accessibility API")
            } else {
                // 2. Fallback to AppleScript / CGEvent
                logger.info("Accessibility paste failed, attempting fallbacks...")
                self.simulatePasteFallback(to: pid)
            }
        }
    }
    
    private func waitForKeyRelease(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            // kVK_ANSI_V = 0x09
            let vKeyCode: CGKeyCode = 0x09
            
            // Poll until 'V' key is released (max 1 second)
            var attempts = 0
            while attempts < 10 {
                // Check if V is still pressed
                if CGEventSource.keyState(.combinedSessionState, key: vKeyCode) {
                    usleep(100000) // 100ms
                    attempts += 1
                } else {
                    break
                }
            }
            
            // Give a tiny buffer after release
            usleep(50000) // 50ms buffer restored for reliability
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func pasteViaAccessibility(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var menuBar: CFTypeRef?
        
        // Get Menu Bar
        let result = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar)
        guard result == .success, let menuBar = menuBar else {
            logger.warning("AX: Failed to get menu bar (Error: \(String(describing: result)))")
            return false
        }
        let menuBarElement = menuBar as! AXUIElement
        
        // Function to find "Edit" menu
        func findMenu(named name: String, in element: AXUIElement) -> AXUIElement? {
            var children: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
                  let childrenArray = children as? [AXUIElement] else { return nil }
            
            for child in childrenArray {
                var title: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title) == .success,
                   let titleString = title as? String,
                   titleString == name {
                    return child
                }
            }
            return nil
        }
        
        // Find Edit Menu
        guard let editMenuItem = findMenu(named: "Edit", in: menuBarElement) else {
            logger.warning("AX: 'Edit' menu not found")
            return false
        }
        
        // Get the submenu of "Edit"
        var editMenu: CFTypeRef?
        guard AXUIElementCopyAttributeValue(editMenuItem, kAXChildrenAttribute as CFString, &editMenu) == .success else {
            logger.warning("AX: Failed to get 'Edit' submenu")
            return false
        }
        
        // Let's traverse down
        guard let editChildren = editMenu as? [AXUIElement], let actualEditMenu = editChildren.first else {
            logger.warning("AX: 'Edit' submenu children empty or invalid")
            return false
        }
        
        // Find "Paste" in Edit Menu
        guard let pasteItem = findMenu(named: "Paste", in: actualEditMenu) else {
            logger.warning("AX: 'Paste' menu item not found")
            return false
        }
        
        // Perform Action "Pick" or "Press"
        let actionStatus = AXUIElementPerformAction(pasteItem, kAXPressAction as CFString)
        if actionStatus != .success {
            logger.error("AX: Failed to press 'Paste' (Error: \(String(describing: actionStatus)))")
        }
        return actionStatus == .success
    }

    private func simulatePasteFallback(to pid: pid_t) {
        // Method 1: AppleScript (via Terminal/Process) - Robust Version
        logger.info("Attempting paste via AppleScript (Targeting PID: \(pid))...")
        
        // precise script: focus process -> delay -> key code 9 (v) using command -> beep
        let script = """
        tell application "System Events"
            set frontmost of every process whose unix id is \(pid) to true
            delay 0.05
            key code 9 using command down
            beep
        end tell
        """
        
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]
        
        do {
            try process.run()
            process.waitUntilExit() // Wait for it to actually finish
            
            if process.terminationStatus == 0 {
                logger.info("Executed AppleScript successfully (Exit 0)")
            } else {
                logger.error("AppleScript exited with error code: \(process.terminationStatus)")
                // Try fallback if script failed
                simulatePasteCGEvent()
            }
        } catch {
            logger.error("Failed to launch AppleScript process: \(error)")
            simulatePasteCGEvent()
        }
    }
    
    private func simulatePasteCGEvent() {
        // Use HID System State to mimic hardware event source
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V
        let cmdKeyCode: CGKeyCode = 0x37 // kVK_Command
        
        // Helper to post event
        func postKey(_ key: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
        
        // 1. Cmd Down
        postKey(cmdKeyCode, down: true, flags: .maskCommand)
        usleep(10000) // 10ms
        
        // 2. V Down (with Cmd flag)
        postKey(vKeyCode, down: true, flags: .maskCommand)
        usleep(10000) 
        
        // 3. V Up (with Cmd flag)
        postKey(vKeyCode, down: false, flags: .maskCommand)
        usleep(10000)
        
        // 4. Cmd Up (No flags)
        postKey(cmdKeyCode, down: false, flags: [])
        
        logger.info("Simulated explicit Cmd+V sequence (Global Tap via CGEvent)")
    }
    
    // MARK: - Private Methods
    
    private func installEventHandler() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]
        
        // We need to store self in a way the C callback can access
        let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()
        
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let event = event, let userData = userData else {
                    return OSStatus(eventNotHandledErr)
                }
                
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                return hotKey.handleEvent(event)
            },
            eventTypes.count,
            &eventTypes,
            unmanagedSelf,
            &eventHandler
        )
        
        if status == noErr {
            logger.info("Event handler installed successfully")
        } else {
            logger.error("Failed to install event handler, error: \(status)")
        }
    }
    
    private func handleEvent(_ event: EventRef) -> OSStatus {
        logger.info("Event received!")
        
        // Get the hotkey ID from the event
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        guard status == noErr else {
            logger.error("Failed to get event parameter, status: \(status)")
            return status
        }
        
        // Verify this is our hotkey signature
        guard hotKeyID.signature == GlobalHotKey.carbonEventSignature else {
            logger.info("Event is not for our app")
            return OSStatus(eventNotHandledErr)
        }
        
        // Find the handler for this hotkey ID
        guard let info = hotKeys[hotKeyID.id] else {
            logger.warning("No handler registered for hotkey ID \(hotKeyID.id)")
            return OSStatus(eventNotHandledErr)
        }
        
        // Call the handler on the main thread
        logger.info("Calling handler for hotkey ID \(hotKeyID.id)")
        DispatchQueue.main.async {
            info.handler()
        }
        return noErr
    }
    
    /// Convert NSEvent.ModifierFlags to Carbon modifier flags
    private func carbonModifiers(from modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonMods: UInt32 = 0
        
        if modifiers.contains(.command) {
            carbonMods |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            carbonMods |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonMods |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            carbonMods |= UInt32(shiftKey)
        }
        
        return carbonMods
    }
    
    deinit {
        unregisterAll()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}