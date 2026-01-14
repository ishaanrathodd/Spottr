import Foundation
import Carbon
import AppKit
import os.log

private let logger = Logger(subsystem: "com.ishaanrathod.FolderWatcher", category: "GlobalHotKey")

/// Enum to identify different hotkeys
enum HotKeyID: UInt32 {
    case startWatching = 1
    case stopWatching = 2
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
        hotKeys.removeAll()
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