import Foundation
import AppKit

class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let watchFolder = "watchFolder"
        static let shortcutModifiers = "shortcutModifiers"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let singleFileTemplate = "singleFileTemplate"
        static let multipleFilesTemplate = "multipleFilesTemplate"
    }
    
    // Default templates - {path} is the placeholder for file paths
    private static let defaultSingleTemplate = "Analyze this image: {path}"
    private static let defaultMultipleTemplate = "Analyze these images: {path}"
    
    var watchFolder: String {
        get { defaults.string(forKey: Keys.watchFolder) ?? "" }
        set { defaults.set(newValue, forKey: Keys.watchFolder) }
    }
    
    var shortcutModifiers: NSEvent.ModifierFlags {
        get {
            let rawValue = defaults.integer(forKey: Keys.shortcutModifiers)
            if rawValue == 0 {
                // Default: Control + Shift
                return [.control, .shift]
            }
            return NSEvent.ModifierFlags(rawValue: UInt(rawValue))
        }
        set {
            defaults.set(Int(newValue.rawValue), forKey: Keys.shortcutModifiers)
        }
    }
    
    var shortcutKeyCode: UInt16 {
        get {
            let value = defaults.integer(forKey: Keys.shortcutKeyCode)
            if value == 0 {
                // Default: W key
                return 13 // keyCode for 'W'
            }
            return UInt16(value)
        }
        set {
            defaults.set(Int(newValue), forKey: Keys.shortcutKeyCode)
        }
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
    
    // Helper to get human-readable shortcut string
    var shortcutDisplayString: String {
        var parts: [String] = []
        
        let mods = shortcutModifiers
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        
        parts.append(keyCodeToString(shortcutKeyCode))
        
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