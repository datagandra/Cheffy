import Foundation
import Network
import os.log
import Combine

@MainActor
class NetworkMonitorService: ObservableObject {
    static let shared = NetworkMonitorService()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "NetworkMonitor")
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Network status
    @Published var isConnected: Bool = false
    @Published var connectionType: NWInterface.InterfaceType = .other
    @Published var isExpensive: Bool = false
    @Published var isConstrained: Bool = false
    
    // Network performance
    @Published var currentLatency: TimeInterval = 0
    @Published var averageLatency: TimeInterval = 0
    @Published var packetLoss: Double = 0
    @Published var bandwidth: UInt64 = 0
    
    // Network quality
    @Published var networkQuality: NetworkQuality = .unknown
    @Published var connectionStability: ConnectionStability = .unknown
    
    // Network history
    private var latencyHistory: [TimeInterval] = []
    private var connectionHistory: [ConnectionEvent] = []
    private let maxHistorySize = 100
    
    // Configuration
    private let latencyThreshold: TimeInterval = 2.0
    private let packetLossThreshold: Double = 5.0
    private let bandwidthThreshold: UInt64 = 1_000_000 // 1 Mbps
    
    private init() {
        setupNetworkMonitoring()
        startPeriodicNetworkTests()
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        
        networkMonitor.start(queue: queue)
        
        // Monitor network quality changes
        Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateNetworkQuality()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Network Path Updates
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        connectionType = path.availableInterfaces.first?.type ?? .other
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Record connection event
        let event = ConnectionEvent(
            timestamp: Date(),
            status: path.status,
            interfaceType: connectionType,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
        connectionHistory.append(event)
        
        // Keep only recent history
        if connectionHistory.count > maxHistorySize {
            connectionHistory.removeFirst()
        }
        
        // Handle connection state changes
        if wasConnected != isConnected {
            if isConnected {
                logger.info("Network connection established via \(connectionType)")
                Task {
                    await self.performNetworkQualityTest()
                }
            } else {
                logger.warning("Network connection lost")
                networkQuality = .disconnected
                connectionStability = .disconnected
            }
        }
        
        // Update connection stability
        updateConnectionStability()
    }
    
    // MARK: - Network Quality Testing
    
    private func startPeriodicNetworkTests() {
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.performNetworkQualityTest()
                }
            }
            .store(in: &cancellables)
    }
    
    private func performNetworkQualityTest() async {
        guard isConnected else { return }
        
        // Test latency to multiple endpoints
        let endpoints = [
            "8.8.8.8", // Google DNS
            "1.1.1.1", // Cloudflare DNS
            "208.67.222.222" // OpenDNS
        ]
        
        var totalLatency: TimeInterval = 0
        var successfulTests = 0
        
        for endpoint in endpoints {
            if let latency = await measureLatency(to: endpoint) {
                totalLatency += latency
                successfulTests += 1
            }
        }
        
        if successfulTests > 0 {
            let averageLatency = totalLatency / Double(successfulTests)
            await updateLatency(averageLatency)
        }
        
        // Test bandwidth (simplified)
        await measureBandwidth()
        
        // Update network quality
        await updateNetworkQuality()
    }
    
    private func measureLatency(to host: String) async -> TimeInterval? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let url = URL(string: "https://\(host)")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let latency = CFAbsoluteTimeGetCurrent() - startTime
                return latency
            }
        } catch {
            logger.debug("Latency test failed for \(host): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func measureBandwidth() async {
        // Simplified bandwidth measurement
        // In production, you might want to use more sophisticated methods
        let testDataSize: UInt64 = 100_000 // 100KB
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let url = URL(string: "https://httpbin.org/bytes/\(testDataSize)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            if duration > 0 {
                let bytesPerSecond = Double(data.count) / duration
                bandwidth = UInt64(bytesPerSecond)
            }
        } catch {
            logger.debug("Bandwidth test failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Network Quality Updates
    
    private func updateNetworkQuality() async {
        var quality: NetworkQuality = .unknown
        
        if !isConnected {
            quality = .disconnected
        } else if currentLatency > latencyThreshold * 2 {
            quality = .poor
        } else if currentLatency > latencyThreshold {
            quality = .fair
        } else if currentLatency > latencyThreshold / 2 {
            quality = .good
        } else {
            quality = .excellent
        }
        
        // Adjust quality based on other factors
        if packetLoss > packetLossThreshold {
            quality = quality == .excellent ? .good : quality
        }
        
        if bandwidth < bandwidthThreshold {
            quality = quality == .excellent ? .good : quality
        }
        
        if isExpensive || isConstrained {
            quality = quality == .excellent ? .good : quality
        }
        
        networkQuality = quality
        
        logger.info("Network quality updated: \(quality.rawValue) (latency: \(currentLatency)s, bandwidth: \(bandwidth / 1024 / 1024) Mbps)")
    }
    
    private func updateLatency(_ latency: TimeInterval) async {
        currentLatency = latency
        
        // Update history
        latencyHistory.append(latency)
        if latencyHistory.count > maxHistorySize {
            latencyHistory.removeFirst()
        }
        
        // Calculate average
        if !latencyHistory.isEmpty {
            averageLatency = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
        }
        
        // Calculate packet loss (simplified)
        let highLatencyCount = latencyHistory.filter { $0 > latencyThreshold }.count
        packetLoss = Double(highLatencyCount) / Double(latencyHistory.count) * 100
    }
    
    private func updateConnectionStability() {
        guard connectionHistory.count >= 3 else {
            connectionStability = .unknown
            return
        }
        
        let recentEvents = Array(connectionHistory.suffix(3))
        let disconnections = recentEvents.filter { $0.status != .satisfied }.count
        
        switch disconnections {
        case 0:
            connectionStability = .stable
        case 1:
            connectionStability = .moderate
        case 2...:
            connectionStability = .unstable
        default:
            connectionStability = .unknown
        }
    }
    
    // MARK: - Network Diagnostics
    
    func runNetworkDiagnostics() async -> NetworkDiagnosticsReport {
        let report = NetworkDiagnosticsReport(
            timestamp: Date(),
            isConnected: isConnected,
            connectionType: connectionType,
            networkQuality: networkQuality,
            connectionStability: connectionStability,
            currentLatency: currentLatency,
            averageLatency: averageLatency,
            packetLoss: packetLoss,
            bandwidth: bandwidth,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            recommendations: generateNetworkRecommendations(),
            connectionHistory: Array(connectionHistory.suffix(10))
        )
        
        logger.info("Network diagnostics completed: \(networkQuality.rawValue) quality, \(connectionStability.rawValue) stability")
        
        return report
    }
    
    private func generateNetworkRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if !isConnected {
            recommendations.append("Check your internet connection and try again")
            return recommendations
        }
        
        if currentLatency > latencyThreshold {
            recommendations.append("High latency detected. Consider switching to a different network")
        }
        
        if packetLoss > packetLossThreshold {
            recommendations.append("Packet loss detected. Network may be unstable")
        }
        
        if bandwidth < bandwidthThreshold {
            recommendations.append("Low bandwidth detected. Some features may be slow")
        }
        
        if isExpensive {
            recommendations.append("Using expensive network. Consider switching to Wi-Fi")
        }
        
        if isConstrained {
            recommendations.append("Network is constrained. Some features may be limited")
        }
        
        if connectionStability == .unstable {
            recommendations.append("Unstable connection. Consider restarting your router")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Network connection is optimal")
        }
        
        return recommendations
    }
    
    // MARK: - Network Event Tracking
    
    func trackNetworkEvent(_ event: NetworkEvent) {
        logger.info("Network event: \(event.type.rawValue) - \(event.description)")
        
        // In production, you might want to send this to an analytics service
        // analyticsService.trackNetworkEvent(event)
    }
    
    // MARK: - Network Optimization
    
    func optimizeNetworkSettings() {
        // Configure URLSession for optimal performance
        let configuration = URLSessionConfiguration.default
        
        // Enable HTTP/2 and HTTP/3
        configuration.httpShouldUsePipelining = true
        configuration.httpMaximumConnectionsPerHost = 4
        
        // Configure caching
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB
            diskCapacity: 100 * 1024 * 1024,  // 100MB
            diskPath: "CheffyNetworkCache"
        )
        
        // Configure timeouts
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        
        logger.info("Network settings optimized for performance")
    }
}

// MARK: - Supporting Types

enum NetworkQuality: String, CaseIterable {
    case unknown = "Unknown"
    case disconnected = "Disconnected"
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"
}

enum ConnectionStability: String, CaseIterable {
    case unknown = "Unknown"
    case stable = "Stable"
    case moderate = "Moderate"
    case unstable = "Unstable"
    case disconnected = "Disconnected"
}

struct ConnectionEvent {
    let timestamp: Date
    let status: NWPath.Status
    let interfaceType: NWInterface.InterfaceType
    let isExpensive: Bool
    let isConstrained: Bool
}

struct NetworkDiagnosticsReport {
    let timestamp: Date
    let isConnected: Bool
    let connectionType: NWInterface.InterfaceType
    let networkQuality: NetworkQuality
    let connectionStability: ConnectionStability
    let currentLatency: TimeInterval
    let averageLatency: TimeInterval
    let packetLoss: Double
    let bandwidth: UInt64
    let isExpensive: Bool
    let isConstrained: Bool
    let recommendations: [String]
    let connectionHistory: [ConnectionEvent]
}

enum NetworkEventType: String, CaseIterable {
    case connectionEstablished = "Connection Established"
    case connectionLost = "Connection Lost"
    case highLatency = "High Latency"
    case packetLoss = "Packet Loss"
    case lowBandwidth = "Low Bandwidth"
    case expensiveNetwork = "Expensive Network"
    case constrainedNetwork = "Constrained Network"
}

struct NetworkEvent {
    let timestamp: Date
    let type: NetworkEventType
    let description: String
    let metadata: [String: Any]
}
