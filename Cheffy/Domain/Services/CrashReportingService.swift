import Foundation
import os.log
import Combine

@MainActor
class CrashReportingService: ObservableObject {
    static let shared = CrashReportingService()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "CrashReporting")
    private var cancellables = Set<AnyCancellable>()
    
    // Crash reports storage
    @Published var crashReports: [CrashReport] = []
    @Published var isEnabled: Bool = true
    
    // Configuration
    private let maxCrashReports = 100
    private let crashReportDirectory = "CrashReports"
    
    private init() {
        setupCrashReporting()
        loadCrashReports()
    }
    
    // MARK: - Setup
    
    private func setupCrashReporting() {
        // Set up uncaught exception handler
        NSSetUncaughtExceptionHandler { exception in
            CrashReportingService.shared.handleUncaughtException(exception)
        }
        
        // Set up signal handlers for common crashes
        signal(SIGABRT) { _ in
            CrashReportingService.shared.handleSignal("SIGABRT")
        }
        
        signal(SIGSEGV) { _ in
            CrashReportingService.shared.handleSignal("SIGSEGV")
        }
        
        signal(SIGBUS) { _ in
            CrashReportingService.shared.handleSignal("SIGBUS")
        }
        
        signal(SIGILL) { _ in
            CrashReportingService.shared.handleSignal("SIGILL")
        }
        
        // Monitor app lifecycle for crash detection
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkForPreviousCrash()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Crash Handling
    
    private func handleUncaughtException(_ exception: NSException) {
        let crashReport = CrashReport(
            timestamp: Date(),
            type: .uncaughtException,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown reason",
            callStack: exception.callStackSymbols,
            additionalInfo: [
                "exceptionName": exception.name.rawValue,
                "exceptionReason": exception.reason ?? "Unknown",
                "userInfo": exception.userInfo?.description ?? "None"
            ]
        )
        
        Task { @MainActor in
            await recordCrash(crashReport)
        }
        
        logger.error("Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "Unknown reason")")
    }
    
    private func handleSignal(_ signal: String) {
        let crashReport = CrashReport(
            timestamp: Date(),
            type: .signal,
            name: signal,
            reason: "Signal received: \(signal)",
            callStack: Thread.callStackSymbols,
            additionalInfo: [
                "signal": signal,
                "threadCount": "\(Thread.activeCount)"
            ]
        )
        
        Task { @MainActor in
            await recordCrash(crashReport)
        }
        
        logger.error("Signal received: \(signal)")
    }
    
    // MARK: - Crash Recording
    
    func recordCrash(_ crashReport: CrashReport) async {
        guard isEnabled else { return }
        
        // Add to memory
        crashReports.append(crashReport)
        
        // Keep only the latest reports
        if crashReports.count > maxCrashReports {
            crashReports.removeFirst()
        }
        
        // Save to disk
        await saveCrashReport(crashReport)
        
        // Log the crash
        logger.error("Crash recorded: \(crashReport.type.rawValue) - \(crashReport.name)")
        
        // In production, you might want to send this to a crash reporting service
        // await sendToCrashReportingService(crashReport)
    }
    
    func recordError(_ error: Error, context: String = "", additionalInfo: [String: String] = [:]) async {
        guard isEnabled else { return }
        
        let crashReport = CrashReport(
            timestamp: Date(),
            type: .error,
            name: error.localizedDescription,
            reason: context.isEmpty ? "Error occurred" : context,
            callStack: Thread.callStackSymbols,
            additionalInfo: additionalInfo.merging([
                "errorDomain": (error as NSError).domain,
                "errorCode": "\((error as NSError).code)",
                "errorDescription": error.localizedDescription
            ]) { _, new in new }
        )
        
        await recordCrash(crashReport)
    }
    
    func recordWarning(_ warning: String, context: String = "", additionalInfo: [String: String] = [:]) async {
        guard isEnabled else { return }
        
        let crashReport = CrashReport(
            timestamp: Date(),
            type: .warning,
            name: warning,
            reason: context.isEmpty ? "Warning occurred" : context,
            callStack: Thread.callStackSymbols,
            additionalInfo: additionalInfo
        )
        
        await recordCrash(crashReport)
    }
    
    // MARK: - Crash Detection
    
    private func checkForPreviousCrash() {
        // Check if the app crashed on previous launch
        let lastLaunchKey = "LastLaunchTimestamp"
        let currentTime = Date()
        
        if let lastLaunch = UserDefaults.standard.object(forKey: lastLaunchKey) as? Date {
            let timeSinceLastLaunch = currentTime.timeIntervalSince(lastLaunch)
            
            // If more than 5 minutes have passed, it might indicate a crash
            if timeSinceLastLaunch > 300 {
                logger.warning("Possible crash detected - time since last launch: \(timeSinceLastLaunch)s")
                
                let crashReport = CrashReport(
                    timestamp: Date(),
                    type: .possibleCrash,
                    name: "Possible Crash",
                    reason: "App may have crashed on previous launch",
                    callStack: [],
                    additionalInfo: [
                        "timeSinceLastLaunch": "\(timeSinceLastLaunch)s",
                        "lastLaunch": lastLaunch.description
                    ]
                )
                
                Task { @MainActor in
                    await recordCrash(crashReport)
                }
            }
        }
        
        // Update last launch timestamp
        UserDefaults.standard.set(currentTime, forKey: lastLaunchKey)
    }
    
    // MARK: - Storage
    
    private func saveCrashReport(_ crashReport: CrashReport) async {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let crashReportsPath = documentsPath.appendingPathComponent(crashReportDirectory)
            
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: crashReportsPath, withIntermediateDirectories: true)
            
            // Create filename with timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: crashReport.timestamp)
            let filename = "crash_\(crashReport.type.rawValue)_\(timestamp).json"
            let fileURL = crashReportsPath.appendingPathComponent(filename)
            
            // Encode and save
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(crashReport)
            try data.write(to: fileURL)
            
            logger.info("Crash report saved to: \(fileURL.path)")
        } catch {
            logger.error("Failed to save crash report: \(error.localizedDescription)")
        }
    }
    
    private func loadCrashReports() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let crashReportsPath = documentsPath.appendingPathComponent(crashReportDirectory)
            
            guard FileManager.default.fileExists(atPath: crashReportsPath.path) else { return }
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: crashReportsPath, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            for fileURL in jsonFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let crashReport = try decoder.decode(CrashReport.self, from: data)
                    crashReports.append(crashReport)
                } catch {
                    logger.error("Failed to load crash report from \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            // Sort by timestamp (newest first)
            crashReports.sort { $0.timestamp > $1.timestamp }
            
            logger.info("Loaded \(crashReports.count) crash reports from disk")
        } catch {
            logger.error("Failed to load crash reports: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Crash Report Management
    
    func clearCrashReports() async {
        crashReports.removeAll()
        
        // Clear from disk
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let crashReportsPath = documentsPath.appendingPathComponent(crashReportDirectory)
            
            if FileManager.default.fileExists(atPath: crashReportsPath.path) {
                try FileManager.default.removeItem(at: crashReportsPath)
                logger.info("Crash reports directory cleared")
            }
        } catch {
            logger.error("Failed to clear crash reports: \(error.localizedDescription)")
        }
    }
    
    func exportCrashReports() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(crashReports)
            return String(data: data, encoding: .utf8) ?? "Failed to encode crash reports"
        } catch {
            return "Failed to export crash reports: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Crash Analysis
    
    func getCrashSummary() -> CrashSummary {
        let totalCrashes = crashReports.count
        let crashesByType = Dictionary(grouping: crashReports, by: { $0.type })
            .mapValues { $0.count }
        
        let recentCrashes = crashReports.filter { 
            $0.timestamp.timeIntervalSinceNow > -86400 // Last 24 hours
        }
        
        let mostCommonCrashes = crashesByType.sorted { $0.value > $1.value }
        
        return CrashSummary(
            totalCrashes: totalCrashes,
            crashesByType: crashesByType,
            recentCrashes: recentCrashes.count,
            mostCommonCrashes: mostCommonCrashes.prefix(5).map { ($0.key, $0.value) },
            lastCrash: crashReports.first?.timestamp
        )
    }
    
    func getCrashTrends() -> [CrashTrend] {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        let recentCrashes = crashReports.filter { $0.timestamp >= thirtyDaysAgo }
        
        var dailyCrashes: [Date: Int] = [:]
        
        for crash in recentCrashes {
            let day = calendar.startOfDay(for: crash.timestamp)
            dailyCrashes[day, default: 0] += 1
        }
        
        return dailyCrashes.map { date, count in
            CrashTrend(date: date, crashCount: count)
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Supporting Types

enum CrashType: String, CaseIterable, Codable {
    case uncaughtException = "Uncaught Exception"
    case signal = "Signal"
    case error = "Error"
    case warning = "Warning"
    case possibleCrash = "Possible Crash"
}

struct CrashReport: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: CrashType
    let name: String
    let reason: String
    let callStack: [String]
    let additionalInfo: [String: String]
}

struct CrashSummary {
    let totalCrashes: Int
    let crashesByType: [CrashType: Int]
    let recentCrashes: Int
    let mostCommonCrashes: [(CrashType, Int)]
    let lastCrash: Date?
}

struct CrashTrend {
    let date: Date
    let crashCount: Int
}
