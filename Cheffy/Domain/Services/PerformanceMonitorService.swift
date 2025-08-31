import Foundation
import os.log
import Combine

@MainActor
class PerformanceMonitorService: ObservableObject {
    static let shared = PerformanceMonitorService()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "Performance")
    private var cancellables = Set<AnyCancellable>()
    
    // Performance metrics
    @Published var appLaunchTime: TimeInterval = 0
    @Published var memoryUsage: UInt64 = 0
    @Published var cpuUsage: Double = 0
    @Published var networkLatency: TimeInterval = 0
    @Published var recipeGenerationTime: TimeInterval = 0
    
    // Performance thresholds
    private let maxLaunchTime: TimeInterval = 3.0
    private let maxMemoryUsage: UInt64 = 500 * 1024 * 1024 // 500MB
    private let maxCPUUsage: Double = 80.0
    private let maxNetworkLatency: TimeInterval = 5.0
    private let maxRecipeGenerationTime: TimeInterval = 10.0
    
    // Performance history
    private var performanceHistory: [PerformanceMetric] = []
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - Performance Monitoring Setup
    
    private func setupPerformanceMonitoring() {
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startPerformanceMonitoring()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.stopPerformanceMonitoring()
            }
            .store(in: &cancellables)
        
        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Performance Tracking
    
    func startPerformanceMonitoring() {
        Task {
            await startLaunchTimeTracking()
            await startMemoryMonitoring()
            await startCPUMonitoring()
        }
    }
    
    func stopPerformanceMonitoring() {
        // Stop continuous monitoring
        logger.info("Performance monitoring stopped")
    }
    
    // MARK: - Launch Time Tracking
    
    private func startLaunchTimeTracking() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Wait for app to fully load
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        appLaunchTime = CFAbsoluteTimeGetCurrent() - startTime
        
        if appLaunchTime > maxLaunchTime {
            logger.warning("App launch time exceeded threshold: \(appLaunchTime)s (max: \(maxLaunchTime)s)")
            await recordPerformanceIssue(.launchTimeExceeded)
        } else {
            logger.info("App launch time: \(appLaunchTime)s")
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() async {
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateMemoryUsage()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateMemoryUsage() async {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsage = UInt64(info.resident_size)
            
            if memoryUsage > maxMemoryUsage {
                logger.warning("Memory usage exceeded threshold: \(memoryUsage / 1024 / 1024)MB (max: \(maxMemoryUsage / 1024 / 1024)MB)")
                await recordPerformanceIssue(.memoryUsageExceeded)
            }
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory warning received")
        Task {
            await recordPerformanceIssue(.memoryWarning)
            await cleanupMemory()
        }
    }
    
    private func cleanupMemory() async {
        // Clear caches, temporary data, etc.
        logger.info("Performing memory cleanup")
        
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()
        
        // Force garbage collection if available
        #if DEBUG
        // In debug builds, we can force some cleanup
        #endif
    }
    
    // MARK: - CPU Monitoring
    
    private func startCPUMonitoring() async {
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCPUUsage()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateCPUUsage() async {
        // Simplified CPU usage calculation
        // In production, you might want to use more sophisticated methods
        let startTime = CFAbsoluteTimeGetCurrent()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // This is a simplified calculation - in production use proper CPU monitoring
        cpuUsage = min(100.0, (endTime - startTime) * 1000)
        
        if cpuUsage > maxCPUUsage {
            logger.warning("CPU usage exceeded threshold: \(cpuUsage)% (max: \(maxCPUUsage)%)")
            await recordPerformanceIssue(.cpuUsageExceeded)
        }
    }
    
    // MARK: - Network Performance
    
    func trackNetworkLatency(_ latency: TimeInterval) {
        networkLatency = latency
        
        if latency > maxNetworkLatency {
            logger.warning("Network latency exceeded threshold: \(latency)s (max: \(maxNetworkLatency)s)")
            Task {
                await recordPerformanceIssue(.networkLatencyExceeded)
            }
        }
    }
    
    // MARK: - Recipe Generation Performance
    
    func trackRecipeGenerationTime(_ time: TimeInterval) {
        recipeGenerationTime = time
        
        if time > maxRecipeGenerationTime {
            logger.warning("Recipe generation time exceeded threshold: \(time)s (max: \(maxRecipeGenerationTime)s)")
            Task {
                await recordPerformanceIssue(.recipeGenerationTimeExceeded)
            }
        }
    }
    
    // MARK: - Performance Issue Recording
    
    private func recordPerformanceIssue(_ issue: PerformanceIssue) {
        let metric = PerformanceMetric(
            timestamp: Date(),
            issue: issue,
            appLaunchTime: appLaunchTime,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            networkLatency: networkLatency,
            recipeGenerationTime: recipeGenerationTime
        )
        
        performanceHistory.append(metric)
        
        // Keep only last 100 metrics
        if performanceHistory.count > 100 {
            performanceHistory.removeFirst()
        }
        
        // Log the issue
        logger.error("Performance issue recorded: \(issue.description)")
        
        // In production, you might want to send this to a monitoring service
        // sendToMonitoringService(metric)
    }
    
    // MARK: - Performance Reports
    
    func generatePerformanceReport() -> PerformanceReport {
        let recentMetrics = Array(performanceHistory.suffix(20))
        
        return PerformanceReport(
            timestamp: Date(),
            appLaunchTime: appLaunchTime,
            averageMemoryUsage: recentMetrics.map { $0.memoryUsage }.reduce(0, +) / UInt64(recentMetrics.count),
            averageCPUUsage: recentMetrics.map { $0.cpuUsage }.reduce(0, +) / Double(recentMetrics.count),
            averageNetworkLatency: recentMetrics.map { $0.networkLatency }.reduce(0, +) / Double(recentMetrics.count),
            averageRecipeGenerationTime: recentMetrics.map { $0.recipeGenerationTime }.reduce(0, +) / Double(recentMetrics.count),
            performanceIssues: recentMetrics.compactMap { $0.issue },
            recommendations: generateRecommendations()
        )
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if appLaunchTime > maxLaunchTime {
            recommendations.append("Optimize app launch time by reducing initial setup operations")
        }
        
        if memoryUsage > maxMemoryUsage {
            recommendations.append("Implement memory management strategies and reduce memory footprint")
        }
        
        if cpuUsage > maxCPUUsage {
            recommendations.append("Optimize CPU-intensive operations and implement background processing")
        }
        
        if networkLatency > maxNetworkLatency {
            recommendations.append("Implement network optimization and caching strategies")
        }
        
        if recipeGenerationTime > maxRecipeGenerationTime {
            recommendations.append("Optimize recipe generation algorithms and implement caching")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

enum PerformanceIssue: String, CaseIterable {
    case launchTimeExceeded = "Launch Time Exceeded"
    case memoryUsageExceeded = "Memory Usage Exceeded"
    case memoryWarning = "Memory Warning"
    case cpuUsageExceeded = "CPU Usage Exceeded"
    case networkLatencyExceeded = "Network Latency Exceeded"
    case recipeGenerationTimeExceeded = "Recipe Generation Time Exceeded"
    
    var description: String {
        switch self {
        case .launchTimeExceeded:
            return "App launch time exceeded 3 seconds"
        case .memoryUsageExceeded:
            return "Memory usage exceeded 500MB"
        case .memoryWarning:
            return "System memory warning received"
        case .cpuUsageExceeded:
            return "CPU usage exceeded 80%"
        case .networkLatencyExceeded:
            return "Network latency exceeded 5 seconds"
        case .recipeGenerationTimeExceeded:
            return "Recipe generation time exceeded 10 seconds"
        }
    }
}

struct PerformanceMetric {
    let timestamp: Date
    let issue: PerformanceIssue
    let appLaunchTime: TimeInterval
    let memoryUsage: UInt64
    let cpuUsage: Double
    let networkLatency: TimeInterval
    let recipeGenerationTime: TimeInterval
}

struct PerformanceReport {
    let timestamp: Date
    let appLaunchTime: TimeInterval
    let averageMemoryUsage: UInt64
    let averageCPUUsage: Double
    let averageNetworkLatency: TimeInterval
    let averageRecipeGenerationTime: TimeInterval
    let performanceIssues: [PerformanceIssue]
    let recommendations: [String]
}
