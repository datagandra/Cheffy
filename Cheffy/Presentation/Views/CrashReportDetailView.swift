import SwiftUI

struct CrashReportDetailView: View {
    let crashReport: CrashReport
    @Environment(\.dismiss) private var dismiss
    @State private var errorDetailsExpanded = false
    @State private var deviceInfoExpanded = false
    @State private var stackTraceExpanded = false
    @State private var timingExpanded = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    crashReportHeader
                    
                    // Error Details
                    errorDetailsSection
                    
                    // Device Information
                    deviceInfoSection
                    
                    // Stack Trace
                    stackTraceSection
                    
                    // Timestamp
                    timestampSection
                }
                .padding()
            }
            .navigationTitle("Crash Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var crashReportHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: crashReport.severity.icon)
                    .font(.system(size: 32))
                    .foregroundColor(Color(crashReport.severity.color))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(crashReport.severity.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(crashReport.severity.color))
                    
                    Text("Crash Report")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if crashReport.isUploaded {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Uploaded")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text("Pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Divider()
        }
    }
    
    // MARK: - Error Details
    
    private var errorDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Error Details", icon: "exclamationmark.triangle.fill", color: .red, isExpanded: $errorDetailsExpanded)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(title: "Error Message", value: crashReport.errorMessage)
                
                DetailRow(title: "App Version", value: crashReport.appVersion)
                
                DetailRow(title: "Build Number", value: crashReport.deviceInfo.buildNumber)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Device Information
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Device Information", icon: "iphone", color: .blue, isExpanded: $deviceInfoExpanded)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(title: "Device Model", value: crashReport.deviceInfo.deviceModel)
                
                DetailRow(title: "System Version", value: crashReport.deviceInfo.systemVersion)
                
                DetailRow(title: "Free Disk Space", value: formatBytes(crashReport.deviceInfo.freeDiskSpace))
                
                DetailRow(title: "Total Disk Space", value: formatBytes(crashReport.deviceInfo.totalDiskSpace))
                
                DetailRow(title: "Memory Usage", value: formatBytes(crashReport.deviceInfo.memoryUsage))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Stack Trace
    
    private var stackTraceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Stack Trace", icon: "list.bullet", color: .orange, isExpanded: $stackTraceExpanded)
            
            ScrollView {
                Text(crashReport.stackTrace)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .frame(maxHeight: 200)
        }
    }
    
    // MARK: - Timestamp
    
    private var timestampSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Timing Information", icon: "clock", color: .green, isExpanded: $timingExpanded)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(title: "Crash Time", value: formatDate(crashReport.timestamp))
                
                DetailRow(title: "Time Ago", value: formatRelativeTime(crashReport.timestamp))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views



struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    CrashReportDetailView(
        crashReport: CrashReport(
            appVersion: "1.0.0",
            deviceInfo: DeviceInfo(),
            errorMessage: "Test crash report for preview purposes",
            stackTrace: "Thread 0 Crashed:\n0   libsystem_kernel.dylib        0x0000000181234567 __pthread_kill + 8\n1   libsystem_pthread.dylib       0x0000000181234568 pthread_kill + 272\n2   libsystem_c.dylib            0x0000000181234569 abort + 120",
            severity: .high
        )
    )
}
