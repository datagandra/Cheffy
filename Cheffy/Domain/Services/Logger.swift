import Foundation
import os.log

class Logger {
    static let shared = Logger()
    
    private let subsystem = "com.cheffy.app"
    private let category = "Cheffy"
    
    private let log: OSLog
    
    private init() {
        self.log = OSLog(subsystem: subsystem, category: category)
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log("%{public}@", log: log, type: .debug, logMessage)
        #endif
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log("%{public}@", log: log, type: .info, logMessage)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log("%{public}@", log: log, type: .error, logMessage)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(function): \(message)"
        os_log("%{public}@", log: log, type: .fault, logMessage)
    }
    
    // MARK: - Convenience Methods
    
    func api(_ message: String) {
        debug("🔑 \(message)")
    }
    
    func network(_ message: String) {
        debug("🌐 \(message)")
    }
    
    func cache(_ message: String) {
        debug("📱 \(message)")
    }
    
    func recipe(_ message: String) {
        debug("🍽️ \(message)")
    }
    
    func user(_ message: String) {
        debug("👤 \(message)")
    }
    
    func security(_ message: String) {
        info("🔒 \(message)")
    }
}

// MARK: - Global Logger Access
let logger = Logger.shared 