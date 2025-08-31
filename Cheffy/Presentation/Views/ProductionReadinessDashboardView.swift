import SwiftUI

struct ProductionReadinessDashboardView: View {
    @StateObject private var performanceMonitor = PerformanceMonitorService.shared
    @StateObject private var crashReporter = CrashReportingService.shared
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    @StateObject private var accessibilityService = AccessibilityService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Performance Metrics
                    PerformanceMetricsCard(performanceMonitor: performanceMonitor)
                    
                    // Network Status
                    NetworkStatusCard(networkMonitor: networkMonitor)
                    
                    // Crash Reports
                    CrashReportsCard(crashReporter: crashReporter)
                    
                    // Accessibility Status
                    AccessibilityStatusCard(accessibilityService: accessibilityService)
                    
                    // Production Checklist
                    ProductionChecklistCard()
                }
                .padding()
            }
            .navigationTitle("Production Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct PerformanceMetricsCard: View {
    let performanceMonitor: PerformanceMonitorService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                Text("Performance Metrics")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                MetricRow(label: "Launch Time", value: "\(String(format: "%.2f", performanceMonitor.appLaunchTime))s")
                MetricRow(label: "Memory Usage", value: "\(performanceMonitor.memoryUsage / 1024 / 1024) MB")
                MetricRow(label: "CPU Usage", value: "\(String(format: "%.1f", performanceMonitor.cpuUsage))%")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct NetworkStatusCard: View {
    let networkMonitor: NetworkMonitorService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.green)
                Text("Network Status")
                    .font(.headline)
                Spacer()
                StatusIndicator(isActive: networkMonitor.isConnected)
            }
            
            VStack(spacing: 8) {
                MetricRow(label: "Quality", value: networkMonitor.networkQuality.rawValue)
                MetricRow(label: "Latency", value: "\(String(format: "%.2f", networkMonitor.currentLatency))s")
                MetricRow(label: "Bandwidth", value: "\(networkMonitor.bandwidth / 1024 / 1024) Mbps")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CrashReportsCard: View {
    let crashReporter: CrashReportingService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("Crash Reports")
                    .font(.headline)
                Spacer()
                Text("\(crashReporter.crashReports.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if crashReporter.crashReports.isEmpty {
                Text("No crashes reported")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Text("Latest: \(crashReporter.crashReports.first?.type.rawValue ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AccessibilityStatusCard: View {
    let accessibilityService: AccessibilityService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "accessibility")
                    .foregroundColor(.purple)
                Text("Accessibility")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                StatusRow(label: "VoiceOver", isEnabled: accessibilityService.isVoiceOverEnabled)
                StatusRow(label: "Dynamic Type", isEnabled: accessibilityService.isDynamicTypeEnabled)
                StatusRow(label: "Reduce Motion", isEnabled: accessibilityService.isReduceMotionEnabled)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProductionChecklistCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.orange)
                Text("Production Checklist")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ChecklistItem(text: "App Store Compliance", isCompleted: true)
                ChecklistItem(text: "Performance Optimization", isCompleted: true)
                ChecklistItem(text: "Crash Handling", isCompleted: true)
                ChecklistItem(text: "Network Resilience", isCompleted: true)
                ChecklistItem(text: "Accessibility Support", isCompleted: true)
                ChecklistItem(text: "Testing Coverage", isCompleted: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct StatusIndicator: View {
    let isActive: Bool
    
    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.red)
            .frame(width: 12, height: 12)
    }
}

struct StatusRow: View {
    let label: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            StatusIndicator(isActive: isEnabled)
        }
    }
}

struct ChecklistItem: View {
    let text: String
    let isCompleted: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
            Text(text)
                .foregroundColor(isCompleted ? .primary : .secondary)
            Spacer()
        }
    }
}

#Preview {
    ProductionReadinessDashboardView()
}
