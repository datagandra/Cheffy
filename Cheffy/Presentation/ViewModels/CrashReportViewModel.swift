import Foundation
import Combine

@MainActor
class CrashReportViewModel: ObservableObject {
    @Published var crashReports: [CrashReport] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var successMessage = ""
    
    private let cloudKitService: any CloudKitServiceProtocol
    private let crashHandlerService: any CrashHandlerServiceProtocol
    private let logger = Logger.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init(cloudKitService: any CloudKitServiceProtocol, crashHandlerService: any CrashHandlerServiceProtocol) {
        self.cloudKitService = cloudKitService
        self.crashHandlerService = crashHandlerService
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor CloudKit sync status
        cloudKitService.syncStatusPublisher
            .sink { [weak self] status in
                self?.handleSyncStatusChange(status)
            }
            .store(in: &cancellables)
        
        // Note: pendingCrashReports is accessed directly when needed
        // since the protocol doesn't expose a publisher for it
    }
    
    // MARK: - Public Methods
    
    func loadCrashReports() async {
        guard cloudKitService.isCloudKitAvailable else {
            showError("CloudKit is not available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let reports = try await cloudKitService.fetchCrashReports()
            crashReports = reports
            showSuccess("Loaded \(reports.count) crash reports")
        } catch {
            showError("Failed to load crash reports: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func uploadPendingCrashReports() async {
        guard !crashHandlerService.pendingCrashReports.isEmpty else {
            showSuccess("No pending crash reports to upload")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            await crashHandlerService.uploadPendingCrashReports()
            showSuccess("Successfully uploaded pending crash reports")
        } catch {
            showError("Failed to upload crash reports: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func clearUploadedCrashReports() {
        Task {
            await crashHandlerService.clearUploadedCrashReports()
            showSuccess("Cleared uploaded crash reports")
        }
    }
    
    func testCrashReport() {
        let testError = NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "This is a test crash report for development purposes"])
        Task {
            await crashHandlerService.collectCrashReport(
                error: testError,
                stackTrace: "Test stack trace\nTest line 1\nTest line 2",
                severity: .low
            )
            showSuccess("Test crash report created")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateCrashReports(_ pendingReports: [CrashReport]) {
        // Combine uploaded reports with pending reports
        let uploadedReports = crashReports.filter { $0.isUploaded }
        let allReports = uploadedReports + pendingReports
        
        // Sort by timestamp (newest first)
        crashReports = allReports.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func handleSyncStatusChange(_ status: CloudKitSyncStatus) {
        switch status {
        case .syncing:
            isLoading = true
        case .available, .notAvailable, .checking, .error:
            isLoading = false
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        logger.error(message)
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
        logger.info(message)
    }
    
    // MARK: - Computed Properties
    
    var totalCrashReports: Int {
        crashReports.count
    }
    
    var pendingCrashReports: Int {
        crashReports.filter { !$0.isUploaded }.count
    }
    
    var uploadedCrashReports: Int {
        crashReports.filter { $0.isUploaded }.count
    }
    
    var crashReportsBySeverity: [CrashSeverity: Int] {
        Dictionary(grouping: crashReports, by: { $0.severity })
            .mapValues { $0.count }
    }
    
    var recentCrashReports: [CrashReport] {
        Array(crashReports.prefix(10))
    }
    
    var criticalCrashReports: [CrashReport] {
        crashReports.filter { $0.severity == .critical }
    }
    
    var highSeverityCrashReports: [CrashReport] {
        crashReports.filter { $0.severity == .high || $0.severity == .critical }
    }
}

// MARK: - Mock Implementation for Testing
class MockCrashReportViewModel: CrashReportViewModel {
    override init(cloudKitService: any CloudKitServiceProtocol, crashHandlerService: any CrashHandlerServiceProtocol) {
        super.init(cloudKitService: cloudKitService, crashHandlerService: crashHandlerService)
        
        // Add some mock data for testing
        crashReports = [
            CrashReport(
                appVersion: "1.0.0",
                deviceInfo: DeviceInfo(),
                errorMessage: "Test crash 1",
                stackTrace: "Stack trace 1",
                severity: .low
            ),
            CrashReport(
                appVersion: "1.0.0",
                deviceInfo: DeviceInfo(),
                errorMessage: "Test crash 2",
                stackTrace: "Stack trace 2",
                severity: .high
            )
        ]
    }
}
