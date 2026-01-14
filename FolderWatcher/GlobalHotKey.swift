import Foundation
import Carbon
import AppKit

/// A class that manages global hotkey registration using Carbon APIs
/// This is the proper way to register system-wide hotkeys that work from any application
final class GlobalHotKey {
    
    // MARK: - Types
    
    typealias Handler = () -> Void
    
    // MARK: - Singleton
    
    static let shared = GlobalHotKey()
    
    // MARK: - Properties
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var keyDownHandler: Handler?
    
    private static var carbonEventSignature: UInt32 = {
        // FourCharCode for "FWHk" (FolderWatcher HotKey)
        let string = "FWHk"
        var result: FourCharCode = 0
        for char in string.utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }()
    
    private static let hotKeyID: UInt32 = 1
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Register a global hotkey with the given key code and modifiers
    /// - Parameters:
    ///   - keyCode: The virtual key code (same as NSEvent.keyCode)
    ///   - modifiers: The modifier flags (NSEvent.ModifierFlags)
    ///   - handler: The closure to call when the hotkey is pressed
    func register(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, handler: @escaping Handler) {
        // Unregister any existing hotkey first
        unregister()
        
        self.keyDownHandler = handler
        
        // Convert NSEvent.ModifierFlags to Carbon modifiers
        let carbonModifiers = carbonModifiers(from: modifiers)
        
        // Install the event handler if not already installed
        if eventHandler == nil {
            installEventHandler()
        }
        
        // Register the hotkey
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.carbonEventSignature, id: GlobalHotKey.hotKeyID)
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            self.hotKeyRef = hotKeyRef
            print("GlobalHotKey: Successfully registered hotkey (keyCode: \(keyCode), modifiers: \(carbonModifiers))")
        } else {
            print("GlobalHotKey: Failed to register hotkey, error: \(status)")
        }
    }
    
    /// Unregister the current hotkey
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
            print("GlobalHotKey: Unregistered hotkey")
        }
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
            print("GlobalHotKey: Event handler installed successfully")
        } else {
            print("GlobalHotKey: Failed to install event handler, error: \(status)")
        }
    }
    
    private func handleEvent(_ event: EventRef) -> OSStatus {
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
            return status
        }
        
        // Verify this is our hotkey
        guard hotKeyID.signature == GlobalHotKey.carbonEventSignature,
              hotKeyID.id == GlobalHotKey.hotKeyID else {
            return OSStatus(eventNotHandledErr)
        }
        
        // Call the handler on the main thread
        if let handler = keyDownHandler {
            DispatchQueue.main.async {
                handler()
            }
            return noErr
        }
        
        return OSStatus(eventNotHandledErr)
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
        unregister()
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}