import Foundation

class FileMonitor {
    private let path: String
    private var stream: FSEventStreamRef?
    private let callback: (String) -> Void
    private var existingFiles: Set<String> = []
    
    init(path: String, callback: @escaping (String) -> Void) {
        self.path = path
        self.callback = callback
    }
    
    func start() {
        // Get existing files first
        existingFiles = getFilesInDirectory(path)
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let pathsToWatch = [path] as CFArray
        
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        
        stream = FSEventStreamCreate(
            nil,
            { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                guard let clientCallBackInfo = clientCallBackInfo else { return }
                let monitor = Unmanaged<FileMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
                
                guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                
                for i in 0..<numEvents {
                    let path = paths[i]
                    let flags = eventFlags[i]
                    
                    // Check if this is a file creation event
                    let isCreated = (flags & UInt32(kFSEventStreamEventFlagItemCreated)) != 0
                    let isFile = (flags & UInt32(kFSEventStreamEventFlagItemIsFile)) != 0
                    let isRenamed = (flags & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0
                    
                    if (isCreated || isRenamed) && isFile {
                        // Check if file exists (renamed events fire for both old and new names)
                        if FileManager.default.fileExists(atPath: path) {
                            // Check if it's a new file
                            if !monitor.existingFiles.contains(path) {
                                monitor.existingFiles.insert(path)
                                monitor.callback(path)
                            }
                        }
                    }
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // Latency in seconds
            flags
        )
        
        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }
    
    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
    
    private func getFilesInDirectory(_ path: String) -> Set<String> {
        var files = Set<String>()
        let fileManager = FileManager.default
        
        if let enumerator = fileManager.enumerator(atPath: path) {
            while let element = enumerator.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(element)
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) && !isDir.boolValue {
                    files.insert(fullPath)
                }
            }
        }
        
        return files
    }
    
    deinit {
        stop()
    }
}