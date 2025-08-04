import Foundation
import os.log

// MARK: - Error Reporting System
class ErrorReporting {
    static let shared = ErrorReporting()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "ErrorReporting")
    private var crashHandler: CrashHandler?
    private var analyticsService: AnalyticsServiceProtocol?
    
    private init() {
        setupCrashHandling()
        setupUnhandledExceptionHandling()
    }
    
    // MARK: - Configuration
    
    func configure(with analyticsService: AnalyticsServiceProtocol) {
        self.analyticsService = analyticsService
    }
    
    // MARK: - Crash Handling
    
    private func setupCrashHandling() {
        #if DEBUG
        // In debug mode, we can use more detailed crash reporting
        logger.info("Setting up debug crash handling")
        #else
        // In release mode, use production crash reporting
        setupProductionCrashHandling()
        #endif
    }
    
    private func setupProductionCrashHandling() {
        // Set up signal handlers for common crashes
        signal(SIGABRT) { signal in
            ErrorReporting.shared.handleSignal(signal, name: "SIGABRT")
        }
        
        signal(SIGSEGV) { signal in
            ErrorReporting.shared.handleSignal(signal, name: "SIGSEGV")
        }
        
        signal(SIGBUS) { signal in
            ErrorReporting.shared.handleSignal(signal, name: "SIGBUS")
        }
        
        signal(SIGILL) { signal in
            ErrorReporting.shared.handleSignal(signal, name: "SIGILL")
        }
        
        signal(SIGFPE) { signal in
            ErrorReporting.shared.handleSignal(signal, name: "SIGFPE")
        }
    }
    
    private func setupUnhandledExceptionHandling() {
        NSSetUncaughtExceptionHandler { exception in
            ErrorReporting.shared.handleUncaughtException(exception)
        }
    }
    
    // MARK: - Signal Handling
    
    private func handleSignal(_ signal: Int32, name: String) {
        let context = [
            "signal": signal,
            "signal_name": name,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        ]
        
        logger.error("App crashed with signal: \(name) (\(signal))")
        analyticsService?.trackError(
            NSError(domain: "SignalCrash", code: Int(signal), userInfo: [NSLocalizedDescriptionKey: name]),
            context: "Signal Crash"
        )
        
        // Save crash report
        saveCrashReport(context: context, type: "signal")
        
        // Give time for crash report to be saved
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    // MARK: - Exception Handling
    
    private func handleUncaughtException(_ exception: NSException) {
        let context = [
            "exception_name": exception.name.rawValue,
            "exception_reason": exception.reason ?? "Unknown",
            "call_stack": exception.callStackSymbols,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        ]
        
        logger.error("Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "Unknown")")
        analyticsService?.trackError(
            NSError(domain: "UncaughtException", code: 1, userInfo: [NSLocalizedDescriptionKey: exception.reason ?? "Unknown"]),
            context: "Uncaught Exception"
        )
        
        // Save crash report
        saveCrashReport(context: context, type: "exception")
    }
    
    // MARK: - Error Reporting
    
    func reportError(_ error: Error, context: String, severity: ErrorSeverity = .medium) {
        let errorInfo = [
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "error_description": error.localizedDescription,
            "context": context,
            "severity": severity.rawValue,
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
        
        logger.error("Error reported: \(error.localizedDescription) in context: \(context)")
        analyticsService?.trackError(error, context: context)
        
        // Save error report
        saveErrorReport(errorInfo)
        
        // For critical errors, show user notification
        if severity == .critical {
            showUserNotification(for: error, context: context)
        }
    }
    
    func reportWarning(_ message: String, context: String) {
        let warningInfo = [
            "message": message,
            "context": context,
            "timestamp": Date().timeIntervalSince1970,
            "type": "warning"
        ]
        
        logger.warning("Warning: \(message) in context: \(context)")
        saveErrorReport(warningInfo)
    }
    
    // MARK: - Performance Monitoring
    
    func reportPerformanceIssue(_ issue: String, metrics: [String: Any]) {
        let performanceInfo = [
            "issue": issue,
            "metrics": metrics,
            "timestamp": Date().timeIntervalSince1970,
            "type": "performance"
        ]
        
        logger.warning("Performance issue: \(issue)")
        analyticsService?.trackEvent("performance_issue", parameters: performanceInfo)
        saveErrorReport(performanceInfo)
    }
    
    // MARK: - Memory Issues
    
    func reportMemoryWarning() {
        let memoryInfo = [
            "type": "memory_warning",
            "timestamp": Date().timeIntervalSince1970,
            "available_memory": ProcessInfo.processInfo.physicalMemory
        ]
        
        logger.warning("Memory warning received")
        analyticsService?.trackEvent("memory_warning", parameters: memoryInfo)
        saveErrorReport(memoryInfo)
    }
    
    // MARK: - Network Issues
    
    func reportNetworkError(_ error: Error, endpoint: String) {
        let networkInfo = [
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "endpoint": endpoint,
            "timestamp": Date().timeIntervalSince1970,
            "type": "network_error"
        ]
        
        logger.error("Network error: \(error.localizedDescription) for endpoint: \(endpoint)")
        analyticsService?.trackError(error, context: "Network Error")
        saveErrorReport(networkInfo)
    }
    
    // MARK: - File Operations
    
    private func saveCrashReport(context: [String: Any], type: String) {
        let report = [
            "type": type,
            "context": context,
            "device_info": getDeviceInfo(),
            "app_info": getAppInfo()
        ]
        
        saveReport(report, filename: "crash_report_\(Date().timeIntervalSince1970).json")
    }
    
    private func saveErrorReport(_ errorInfo: [String: Any]) {
        let report = [
            "error_info": errorInfo,
            "device_info": getDeviceInfo(),
            "app_info": getAppInfo()
        ]
        
        saveReport(report, filename: "error_report_\(Date().timeIntervalSince1970).json")
    }
    
    private func saveReport(_ report: [String: Any], filename: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let reportsDirectory = documentsPath.appendingPathComponent("ErrorReports")
        
        do {
            try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
            
            let reportURL = reportsDirectory.appendingPathComponent(filename)
            let data = try JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
            try data.write(to: reportURL)
            
            logger.info("Report saved: \(filename)")
        } catch {
            logger.error("Failed to save report: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Device Information
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "device_model": UIDevice.current.model,
            "system_version": UIDevice.current.systemVersion,
            "system_name": UIDevice.current.systemName,
            "device_name": UIDevice.current.name,
            "memory": ProcessInfo.processInfo.physicalMemory,
            "cpu_count": ProcessInfo.processInfo.processorCount,
            "free_disk_space": getFreeDiskSpace()
        ]
    }
    
    private func getAppInfo() -> [String: Any] {
        return [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            "bundle_identifier": Bundle.main.bundleIdentifier ?? "Unknown"
        ]
    }
    
    private func getFreeDiskSpace() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    // MARK: - User Notifications
    
    private func showUserNotification(for error: Error, context: String) {
        DispatchQueue.main.async {
            // Show a user-friendly error message
            // This could be integrated with your UI system
            logger.info("Showing user notification for critical error")
        }
    }
    
    // MARK: - Report Management
    
    func getStoredReports() -> [URL] {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let reportsDirectory = documentsPath.appendingPathComponent("ErrorReports")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: reportsDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" }
        } catch {
            logger.error("Failed to get stored reports: \(error.localizedDescription)")
            return []
        }
    }
    
    func clearStoredReports() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let reportsDirectory = documentsPath.appendingPathComponent("ErrorReports")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: reportsDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                try FileManager.default.removeItem(at: file)
            }
            logger.info("Cleared all stored reports")
        } catch {
            logger.error("Failed to clear stored reports: \(error.localizedDescription)")
        }
    }
}

// MARK: - Crash Handler Protocol
protocol CrashHandler {
    func handleCrash(_ crashInfo: [String: Any])
}

// MARK: - Error Severity Extension
extension ErrorSeverity {
    var rawValue: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .critical: return "critical"
        }
    }
} 