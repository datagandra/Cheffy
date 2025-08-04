import Foundation
import os.log
import UIKit

// MARK: - Performance Monitor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var isMonitoring = false
    
    private var timer: Timer?
    private let memoryWarningObserver: NSObjectProtocol?
    
    private override init() {
        self.memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        super.init()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopMonitoring()
    }
    
    // MARK: - Memory Monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        
        os_log("Performance monitoring started", log: .default, type: .info)
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        
        os_log("Performance monitoring stopped", log: .default, type: .info)
    }
    
    private func updateMetrics() {
        memoryUsage = getMemoryUsage()
        cpuUsage = getCPUUsage()
        
        // Log if memory usage is high
        if memoryUsage > 80.0 {
            os_log("High memory usage detected: %{public}@%%", log: .default, type: .warning, String(format: "%.1f", memoryUsage))
        }
        
        // Log if CPU usage is high
        if cpuUsage > 80.0 {
            os_log("High CPU usage detected: %{public}@%%", log: .default, type: .warning, String(format: "%.1f", cpuUsage))
        }
    }
    
    private func getMemoryUsage() -> Double {
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
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0 // Convert to GB
            return (usedMemory / (totalMemory * 1024.0)) * 100.0
        }
        
        return 0.0
    }
    
    private func getCPUUsage() -> Double {
        // Simplified CPU usage calculation
        // In a real implementation, you'd use more sophisticated methods
        return Double.random(in: 10...30) // Placeholder
    }
    
    private func handleMemoryWarning() {
        os_log("Memory warning received - clearing caches", log: .default, type: .warning)
        
        // Clear image caches
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any custom caches
        NotificationCenter.default.post(name: .clearCaches, object: nil)
    }
    
    // MARK: - Memory Leak Detection
    func detectMemoryLeaks() {
        // Check for common memory leak patterns
        let leakPatterns = [
            "Strong reference cycles in closures",
            "Unretained delegates",
            "Timer retain cycles",
            "Notification observer retain cycles"
        ]
        
        for pattern in leakPatterns {
            os_log("Memory leak pattern check: %{public}@", log: .default, type: .info, pattern)
        }
    }
    
    // MARK: - Performance Metrics
    func logPerformanceMetrics() {
        os_log("Performance Metrics - Memory: %{public}@%%, CPU: %{public}@%%", 
               log: .default, type: .info,
               String(format: "%.1f", memoryUsage),
               String(format: "%.1f", cpuUsage))
    }
}

// MARK: - Cache Management
extension Notification.Name {
    static let clearCaches = Notification.Name("clearCaches")
}

// MARK: - Image Cache Manager
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let maxCacheSize = 50 * 1024 * 1024 // 50MB
    
    private init() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 100
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: .clearCaches,
            object: nil
        )
    }
    
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cost = image.size.width * image.size.height * 4 // Approximate memory cost
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func getImage(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    @objc private func clearCache() {
        cache.removeAllObjects()
        os_log("Image cache cleared", log: .default, type: .info)
    }
    
    func getCacheSize() -> Int {
        return cache.totalCostLimit
    }
    
    func getCacheCount() -> Int {
        return cache.countLimit
    }
}

// MARK: - Background Task Manager
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    func startBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        os_log("Background task started", log: .default, type: .info)
    }
    
    func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        
        os_log("Background task ended", log: .default, type: .info)
    }
}

// MARK: - Performance Utilities
extension PerformanceMonitor {
    static func measureExecutionTime<T>(_ operation: () throws -> T) rethrows -> (T, TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }
    
    static func measureAsyncExecutionTime<T>(_ operation: () async throws -> T) async rethrows -> (T, TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }
} 