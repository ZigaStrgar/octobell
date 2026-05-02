import Foundation

public struct AppLogger {
    /// Logs a message if developer mode debug logging is enabled or if running in a DEBUG build context.
    public static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let isDebugLogsEnabled = UserDefaults.standard.bool(forKey: "Core_DebugLogsEnabled")
        
        #if DEBUG
        let shouldLog = true
        #else
        let shouldLog = isDebugLogsEnabled
        #endif
        
        if shouldLog {
            let filename = (file as NSString).lastPathComponent
            print("[\(filename):\(line) \(function)] \(message)")
        }
    }
}
