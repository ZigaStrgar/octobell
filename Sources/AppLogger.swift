import Foundation
import os

public struct AppLogger {
    private static let logger = Logger(subsystem: "com.zigastrgar.octobell", category: "app")

    /// Logs a message if developer mode debug logging is enabled or if running in a DEBUG build context.
    /// Visible in Console.app — filter by subsystem "com.zigastrgar.octobell".
    public static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let isDebugLogsEnabled = UserDefaults.standard.bool(forKey: "Core_DebugLogsEnabled")
        
        #if DEBUG
        let shouldLog = true
        #else
        let shouldLog = isDebugLogsEnabled
        #endif
        
        if shouldLog {
            let filename = (file as NSString).lastPathComponent
            let formatted = "[\(filename):\(line) \(function)] \(message)"
            
            #if DEBUG
            print(formatted)
            #endif
            
            logger.debug("\(formatted, privacy: .public)")
        }
    }
}
