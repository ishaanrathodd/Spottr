import Foundation
import AppKit

class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let watchFolder = "watchFolder"
        static let singleFileTemplate = "singleFileTemplate"
        static let multipleFilesTemplate = "multipleFilesTemplate"
        
        // Start shortcut modifier keys
        static let startModifierControl = "startShortcutModifierControl"
        static let startModifierOption = "startShortcutModifierOption"
        static let startModifierShift = "startShortcutModifierShift"
        static let startModifierCommand = "startShortcutModifierCommand"
        static let startKeyCode = "startShortcutKeyCode"
        
        // Stop shortcut modifier keys
        static let stopModifierControl = "stopShortcutModifierControl"
        static let stopModifierOption = "stopShortcutModifierOption"
        static let stopModifierShift = "stopShortcutModifierShift"
        static let stopModifierCommand = "stopShortcutModifierCommand"
        static let stopKeyCode = "stopShortcutKeyCode"
    }
    
    // Default templates - {path} is the placeholder for file paths
    private static let defaultSingleTemplate = "Analyze this image: {path}"
    private static let defaultMultipleTemplate = "Analyze these images: {path}"
    
    var watchFolder: String {
        get { defaults.string(forKey: Keys.watchFolder) ?? "" }
        set { defaults.set(newValue, forKey: Keys.watchFolder) }
    }
    
    // MARK: - Start Shortcut
    
    var startShortcutModifiers: NSEvent.ModifierFlags {
        get {
            let hasAnyModifier = defaults.object(forKey: Keys.startModifierControl) != nil ||
                                 defaults.object(forKey: Keys.startModifierOption) != nil ||
                                 defaults.object(forKey: Keys.startModifierShift) != nil ||
                                 defaults.object(forKey: Keys.startModifierCommand) != nil
            
            if !hasAnyModifier {
                return [.control, .shift]
            }
            
            var mods: NSEvent.ModifierFlags = []
            if defaults.bool(forKey: Keys.startModifierControl) { mods.insert(.control) }
            if defaults.bool(forKey: Keys.startModifierOption) { mods.insert(.option) }
            if defaults.bool(forKey: Keys.startModifierShift) { mods.insert(.shift) }
            if defaults.bool(forKey: Keys.startModifierCommand) { mods.insert(.command) }
            
            return mods
        }
        set {
            defaults.set(newValue.contains(.control), forKey: Keys.startModifierControl)
            defaults.set(newValue.contains(.option), forKey: Keys.startModifierOption)
            defaults.set(newValue.contains(.shift), forKey: Keys.startModifierShift)
            defaults.set(newValue.contains(.command), forKey: Keys.startModifierCommand)
        }
    }
    
    var startShortcutKeyCode: UInt16 {
        get {
            let hasKey = defaults.object(forKey: Keys.startKeyCode) != nil
            if !hasKey {
                return 13 // Default: W key
            }
            return UInt16(defaults.integer(forKey: Keys.startKeyCode))
        }
        set {
            defaults.set(Int(newValue), forKey: Keys.startKeyCode)
        }
    }
    
    // MARK: - Stop Shortcut
    
    var stopShortcutModifiers: NSEvent.ModifierFlags {
        get {
            let hasAnyModifier = defaults.object(forKey: Keys.stopModifierControl) != nil ||
                                 defaults.object(forKey: Keys.stopModifierOption) != nil ||
                                 defaults.object(forKey: Keys.stopModifierShift) != nil ||
                                 defaults.object(forKey: Keys.stopModifierCommand) != nil
            
            if !hasAnyModifier {
                return [.control, .shift]
            }
            
            var mods: NSEvent.ModifierFlags = []
            if defaults.bool(forKey: Keys.stopModifierControl) { mods.insert(.control) }
            if defaults.bool(forKey: Keys.stopModifierOption) { mods.insert(.option) }
            if defaults.bool(forKey: Keys.stopModifierShift) { mods.insert(.shift) }
            if defaults.bool(forKey: Keys.stopModifierCommand) { mods.insert(.command) }
            
            return mods
        }
        set {
            defaults.set(newValue.contains(.control), forKey: Keys.stopModifierControl)
            defaults.set(newValue.contains(.option), forKey: Keys.stopModifierOption)
            defaults.set(newValue.contains(.shift), forKey: Keys.stopModifierShift)
            defaults.set(newValue.contains(.command), forKey: Keys.stopModifierCommand)
        }
    }
    
    var stopShortcutKeyCode: UInt16 {
        get {
            let hasKey = defaults.object(forKey: Keys.stopKeyCode) != nil
            if !hasKey {
                return 13 // Default: W key
            }
            return UInt16(defaults.integer(forKey: Keys.stopKeyCode))
        }
        set {
            defaults.set(Int(newValue), forKey: Keys.stopKeyCode)
        }
    }
    
    // Check if both shortcuts are the same (toggle mode)
    var shortcutsAreSame: Bool {
        return startShortcutModifiers == stopShortcutModifiers && 
               startShortcutKeyCode == stopShortcutKeyCode
    }
    
    // Template for single file path
    var singleFileTemplate: String {
        get { defaults.string(forKey: Keys.singleFileTemplate) ?? SettingsManager.defaultSingleTemplate }
        set { defaults.set(newValue, forKey: Keys.singleFileTemplate) }
    }
    
    // Template for multiple file paths
    var multipleFilesTemplate: String {
        get { defaults.string(forKey: Keys.multipleFilesTemplate) ?? SettingsManager.defaultMultipleTemplate }
        set { defaults.set(newValue, forKey: Keys.multipleFilesTemplate) }
    }
    
    // Format the final clipboard content based on number of paths
    func formatClipboardContent(paths: [String]) -> String {
        guard !paths.isEmpty else { return "" }
        
        let pathsString = paths.joined(separator: ", ")
        let template = paths.count == 1 ? singleFileTemplate : multipleFilesTemplate
        
        // Replace {path} placeholder with actual paths
        return template.replacingOccurrences(of: "{path}", with: pathsString)
    }
    
    // Helper to get human-readable shortcut strings
    var startShortcutDisplayString: String {
        return formatShortcutDisplay(modifiers: startShortcutModifiers, keyCode: startShortcutKeyCode)
    }
    
    var stopShortcutDisplayString: String {
        return formatShortcutDisplay(modifiers: stopShortcutModifiers, keyCode: stopShortcutKeyCode)
    }
    
    // Combined display for menu bar (shows both if different)
    var shortcutDisplayString: String {
        if shortcutsAreSame {
            return startShortcutDisplayString
        } else {
            return "\(startShortcutDisplayString) / \(stopShortcutDisplayString)"
        }
    }
    
    private func formatShortcutDisplay(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var parts: [String] = []
        
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        
        parts.append(keyCodeToString(keyCode))
        
        return parts.joined()
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
    
    private init() {}
}