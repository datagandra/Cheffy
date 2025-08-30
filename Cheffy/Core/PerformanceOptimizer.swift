import Foundation
import UIKit

// MARK: - Performance Optimizer
class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    private let logger = Logger.shared
    private let errorReporting = ErrorReporting.shared
    private var performanceMetrics: [String: PerformanceMetric] = [:]
    private var memoryWarnings = 0
    private var lastMemoryCheck = Date()
    
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var currentCPUUsage: Double = 0.0
    @Published var isPerformanceMode = false
    
    private init() {
        setupMemoryMonitoring()
        setupPerformanceMode()
    }
    
    // MARK: - Performance Monitoring
    
    func startTimer(for operation: String) {
        let metric = PerformanceMetric(operation: operation, startTime: Date())
        performanceMetrics[operation] = metric
        logger.debug("Started performance timer for: \(operation)")
    }
    
    func endTimer(for operation: String) {
        guard let metric = performanceMetrics[operation] else {
            logger.warning("No timer found for operation: \(operation)")
            return
        }
        
        let duration = Date().timeIntervalSince(metric.startTime)
        metric.duration = duration
        
        // Log performance data
        logger.info("Performance: \(operation) took \(String(format: "%.3f", duration))s")
        
        // Report slow operations
        if duration > 1.0 {
            errorReporting.reportPerformanceIssue(
                "Slow operation detected",
                metrics: [
                    "operation": operation,
                    "duration": duration,
                    "threshold": 1.0
                ]
            )
        }
        
        // Remove from active metrics
        performanceMetrics.removeValue(forKey: operation)
    }
    
    func trackMemoryUsage() {
        let memoryUsage = getCurrentMemoryUsage()
        currentMemoryUsage = memoryUsage
        
        // Check for memory pressure
        if memoryUsage > getMemoryThreshold() {
            errorReporting.reportPerformanceIssue(
                "High memory usage detected",
                metrics: [
                    "memory_usage": memoryUsage,
                    "threshold": getMemoryThreshold(),
                    "percentage": Double(memoryUsage) / Double(getMemoryThreshold()) * 100
                ]
            )
            
            // Trigger memory cleanup
            performMemoryCleanup()
        }
        
        logger.debug("Memory usage: \(memoryUsage) bytes")
    }
    
    func trackCPUUsage() {
        let cpuUsage = getCurrentCPUUsage()
        currentCPUUsage = cpuUsage
        
        // Check for high CPU usage
        if cpuUsage > 80.0 {
            errorReporting.reportPerformanceIssue(
                "High CPU usage detected",
                metrics: [
                    "cpu_usage": cpuUsage,
                    "threshold": 80.0
                ]
            )
        }
        
        logger.debug("CPU usage: \(String(format: "%.1f", cpuUsage))%")
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        memoryWarnings += 1
        errorReporting.reportMemoryWarning()
        
        logger.warning("Memory warning received (count: \(memoryWarnings))")
        
        // Perform aggressive cleanup
        performAggressiveMemoryCleanup()
    }
    
    private func performMemoryCleanup() {
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temporary files
        clearTemporaryFiles()
        
        // Force garbage collection
        autoreleasepool {
            // This will trigger garbage collection
        }
        
        logger.info("Memory cleanup performed")
    }
    
    private func performAggressiveMemoryCleanup() {
        // Clear all caches
        URLCache.shared.removeAllCachedResponses()
        
        // Clear temporary files
        clearTemporaryFiles()
        
        // Clear user defaults if needed
        if memoryWarnings > 2 {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        }
        
        logger.info("Aggressive memory cleanup performed")
    }
    
    private func clearTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            logger.info("Cleared temporary files")
        } catch {
            logger.error("Failed to clear temporary files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Mode
    
    private func setupPerformanceMode() {
        // Check device capabilities
        let processorCount = ProcessInfo.processInfo.processorCount
        let memorySize = ProcessInfo.processInfo.physicalMemory
        
        // Enable performance mode for older devices
        if processorCount < 4 || memorySize < 2_000_000_000 { // Less than 4 cores or 2GB RAM
            isPerformanceMode = true
            logger.info("Performance mode enabled for device with \(processorCount) cores and \(memorySize) bytes RAM")
        }
    }
    
    // MARK: - Image Optimization
    
    func optimizeImage(_ image: UIImage, maxSize: CGSize) -> UIImage {
        let originalSize = image.size
        
        // Check if resizing is needed
        guard originalSize.width > maxSize.width || originalSize.height > maxSize.height else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = originalSize.width / originalSize.height
        let newSize: CGSize
        
        if aspectRatio > 1 {
            // Landscape
            newSize = CGSize(width: maxSize.width, height: maxSize.width / aspectRatio)
        } else {
            // Portrait
            newSize = CGSize(width: maxSize.height * aspectRatio, height: maxSize.height)
        }
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    func compressImage(_ image: UIImage, quality: CGFloat = 0.8) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }
    
    // MARK: - Network Optimization
    
    func optimizeNetworkRequest(_ request: URLRequest) -> URLRequest {
        var optimizedRequest = request
        
        // Add performance headers
        optimizedRequest.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        optimizedRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // Set appropriate timeout
        if isPerformanceMode {
            optimizedRequest.timeoutInterval = 15.0 // Shorter timeout for performance mode
        } else {
            optimizedRequest.timeoutInterval = 30.0
        }
        
        return optimizedRequest
    }
    
    // MARK: - UI Performance
    
    func optimizeUIUpdates() {
        // Reduce animation duration in performance mode
        if isPerformanceMode {
            // Use modern animation API instead of deprecated setAnimationDuration
        }
    }
    
    func shouldUseLazyLoading() -> Bool {
        return isPerformanceMode || currentMemoryUsage > UInt64(Double(getMemoryThreshold()) * 0.7)
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentMemoryUsage() -> UInt64 {
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
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        // In a real app, you might use more sophisticated methods
        return Double.random(in: 0...100) // Placeholder
    }
    
    private func getMemoryThreshold() -> UInt64 {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        return totalMemory / 4 // 25% of total memory
    }
    
    // MARK: - Performance Reports
    
    func generatePerformanceReport() -> PerformanceReport {
        let activeMetrics = performanceMetrics.values.map { metric in
            [
                "operation": metric.operation,
                "duration": metric.duration ?? 0.0
            ]
        }
        
        return PerformanceReport(
            memoryUsage: currentMemoryUsage,
            cpuUsage: currentCPUUsage,
            memoryWarnings: memoryWarnings,
            isPerformanceMode: isPerformanceMode,
            activeOperations: activeMetrics
        )
    }
    
    func clearPerformanceData() {
        performanceMetrics.removeAll()
        memoryWarnings = 0
        logger.info("Performance data cleared")
    }
}

// MARK: - Supporting Types

class PerformanceMetric {
    let operation: String
    let startTime: Date
    var duration: TimeInterval?
    
    init(operation: String, startTime: Date) {
        self.operation = operation
        self.startTime = startTime
    }
}

struct PerformanceReport {
    let memoryUsage: UInt64
    let cpuUsage: Double
    let memoryWarnings: Int
    let isPerformanceMode: Bool
    let activeOperations: [[String: Any]]
}

 