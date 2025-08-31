import Foundation
import UIKit

protocol CrashHandlerServiceProtocol: ObservableObject {
    var pendingCrashReports: [CrashReport] { get }
    var isCollecting: Bool { get }
    
    func startCrashCollection()
    func stopCrashCollection()
    func collectCrashReport(error: Error, stackTrace: String, severity: CrashSeverity) async
    func uploadPendingCrashReports() async
    func clearUploadedCrashReports() async
}

@MainActor
@preconcurrency
class CrashHandlerService: @preconcurrency CrashHandlerServiceProtocol {
    @Published var pendingCrashReports: [CrashReport] = []
    @Published var isCollecting = false
    
    private let cloudKitService: any CloudKitServiceProtocol
    private let logger = Logger.shared
    private let userDefaults = UserDefaults.standard
    
    private let pendingCrashReportsKey = "PendingCrashReports"
    private let maxStoredCrashReports = 50
    
    init(cloudKitService: any CloudKitServiceProtocol) {
        self.cloudKitService = cloudKitService
        loadPendingCrashReports()
        setupCrashHandling()
    }
    
    // MARK: - Crash Collection Management
    
    func startCrashCollection() {
        guard !isCollecting else { return }
        
        isCollecting = true
        setupUncaughtExceptionHandler()
        setupSignalHandler()
        
        logger.info("Crash collection started")
    }
    
    func stopCrashCollection() {
        guard isCollecting else { return }
        
        isCollecting = false
        removeUncaughtExceptionHandler()
        removeSignalHandler()
        
        logger.info("Crash collection stopped")
    }
    
    // MARK: - Crash Report Collection
    
    func collectCrashReport(error: Error, stackTrace: String, severity: CrashSeverity) async {
        let crashReport = CrashReport(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            deviceInfo: DeviceInfo(),
            errorMessage: error.localizedDescription,
            stackTrace: stackTrace,
            severity: severity
        )
        
        pendingCrashReports.append(crashReport)
        
        // Limit stored crash reports
        if pendingCrashReports.count > maxStoredCrashReports {
            pendingCrashReports.removeFirst(pendingCrashReports.count - maxStoredCrashReports)
        }
        
        savePendingCrashReports()
        
        logger.info("Crash report collected: \(error.localizedDescription)")
        
        // Try to upload immediately if CloudKit is available
        if cloudKitService.isCloudKitAvailable {
            Task {
                await uploadPendingCrashReports()
            }
        }
    }
    
    // MARK: - Crash Report Upload
    
    func uploadPendingCrashReports() async {
        guard !pendingCrashReports.isEmpty else { return }
        
        let reportsToUpload = pendingCrashReports.filter { !$0.isUploaded }
        
        for report in reportsToUpload {
            do {
                try await cloudKitService.uploadCrashReport(report)
                
                // Mark as uploaded
                if let index = pendingCrashReports.firstIndex(where: { $0.id == report.id }) {
                    pendingCrashReports[index] = CrashReport(
                        id: report.id,
                        timestamp: report.timestamp,
                        appVersion: report.appVersion,
                        deviceInfo: report.deviceInfo,
                        errorMessage: report.errorMessage,
                        stackTrace: report.stackTrace,
                        severity: report.severity,
                        isUploaded: true
                    )
                }
                
                logger.info("Successfully uploaded crash report: \(report.id)")
            } catch {
                logger.error("Failed to upload crash report: \(error)")
            }
        }
        
        savePendingCrashReports()
    }
    
    func clearUploadedCrashReports() async {
        pendingCrashReports.removeAll { $0.isUploaded }
        savePendingCrashReports()
        logger.info("Cleared uploaded crash reports")
    }
    
    // MARK: - Private Methods
    
    private func setupCrashHandling() {
        // Set up notification observers for app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    private func setupUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let stackTrace = exception.callStackSymbols.joined(separator: "\n")
            let error = NSError(domain: exception.name.rawValue, code: 0, userInfo: exception.userInfo as? [String: Any])
            
            // Create crash report on main thread
            DispatchQueue.main.async {
                if let crashHandler = UIApplication.shared.delegate as? CrashHandlerService {
                    Task {
                        await crashHandler.collectCrashReport(
                            error: error,
                            stackTrace: stackTrace,
                            severity: .critical
                        )
                    }
                }
            }
        }
    }
    
    private func removeUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler(nil)
    }
    
    private func setupSignalHandler() {
        // Handle fatal signals
        signal(SIGABRT) { _ in
            DispatchQueue.main.async {
                if let crashHandler = UIApplication.shared.delegate as? CrashHandlerService {
                    Task {
                        await crashHandler.collectCrashReport(
                            error: NSError(domain: "Signal", code: Int(SIGABRT), userInfo: nil),
                            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
                            severity: .critical
                        )
                    }
                }
            }
        }
        
        signal(SIGSEGV) { _ in
            DispatchQueue.main.async {
                if let crashHandler = UIApplication.shared.delegate as? CrashHandlerService {
                    Task {
                        await crashHandler.collectCrashReport(
                            error: NSError(domain: "Signal", code: Int(SIGSEGV), userInfo: nil),
                            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
                            severity: .critical
                        )
                    }
                }
            }
        }
    }
    
    private func removeSignalHandler() {
        signal(SIGABRT, SIG_DFL)
        signal(SIGSEGV, SIG_DFL)
    }
    
    // MARK: - App Lifecycle Handlers
    
    @objc private func appWillTerminate() {
        // Try to upload any pending crash reports before app terminates
        Task {
            await uploadPendingCrashReports()
        }
    }
    
    @objc private func appDidBecomeActive() {
        // Check for pending crash reports and try to upload them
        if !pendingCrashReports.isEmpty {
            Task {
                await uploadPendingCrashReports()
            }
        }
    }
    
    @objc private func appDidEnterBackground() {
        // Try to upload pending crash reports when app goes to background
        Task {
            await uploadPendingCrashReports()
        }
    }
    
    // MARK: - Persistence
    
    private func savePendingCrashReports() {
        let data = try? JSONEncoder().encode(pendingCrashReports)
        userDefaults.set(data, forKey: pendingCrashReportsKey)
    }
    
    private func loadPendingCrashReports() {
        guard let data = userDefaults.data(forKey: pendingCrashReportsKey),
              let reports = try? JSONDecoder().decode([CrashReport].self, from: data) else {
            return
        }
        
        pendingCrashReports = reports
    }
}

// MARK: - Convenience Extensions

extension CrashHandlerService {
    func collectCrashReport(message: String, stackTrace: String, severity: CrashSeverity = .medium) async {
        let error = NSError(domain: "CustomError", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
        await collectCrashReport(error: error, stackTrace: stackTrace, severity: severity)
    }
    
    func collectCrashReport(title: String, message: String, severity: CrashSeverity = .medium) async {
        let fullMessage = "\(title): \(message)"
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        await collectCrashReport(message: fullMessage, stackTrace: stackTrace, severity: severity)
    }
}
