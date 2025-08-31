import SwiftUI

struct CrashReportDashboardView: View {
    @StateObject private var viewModel: CrashReportViewModel
    @State private var showingCrashDetails = false
    @State private var selectedCrashReport: CrashReport?
    
    init(cloudKitService: any CloudKitServiceProtocol, crashHandlerService: any CrashHandlerServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: CrashReportViewModel(
            cloudKitService: cloudKitService,
            crashHandlerService: crashHandlerService
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
                crashReportStatsHeader
                
                // Crash reports list
                crashReportsList
            }
            .navigationTitle("Crash Reports")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await viewModel.loadCrashReports()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Test") {
                        viewModel.testCrashReport()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await viewModel.loadCrashReports()
            }
            .task {
                await viewModel.loadCrashReports()
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.successMessage)
            }
            .sheet(isPresented: $showingCrashDetails) {
                if let crashReport = selectedCrashReport {
                    CrashReportDetailView(crashReport: crashReport)
                }
            }
        }
    }
    
    // MARK: - Header Stats
    
    private var crashReportStatsHeader: some View {
        VStack(spacing: 16) {
            HStack {
                CrashStatCard(
                    title: "Total",
                    value: "\(viewModel.totalCrashReports)",
                    icon: "exclamationmark.triangle.fill",
                    color: .blue
                )
                
                CrashStatCard(
                    title: "Pending",
                    value: "\(viewModel.pendingCrashReports)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                CrashStatCard(
                    title: "Uploaded",
                    value: "\(viewModel.uploadedCrashReports)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            
            // Severity breakdown
            if !viewModel.crashReportsBySeverity.isEmpty {
                severityBreakdownView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
    
    private var severityBreakdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Severity Breakdown")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(CrashSeverity.allCases, id: \.self) { severity in
                    let count = viewModel.crashReportsBySeverity[severity] ?? 0
                    if count > 0 {
                        SeverityBadge(severity: severity, count: count)
                    }
                }
            }
        }
    }
    
    // MARK: - Crash Reports List
    
    private var crashReportsList: some View {
        List {
            if viewModel.isLoading {
                LoadingRow()
            } else if viewModel.crashReports.isEmpty {
                EmptyStateRow()
            } else {
                ForEach(viewModel.crashReports) { crashReport in
                    CrashReportRow(crashReport: crashReport)
                        .onTapGesture {
                            selectedCrashReport = crashReport
                            showingCrashDetails = true
                        }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Supporting Views

struct CrashStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SeverityBadge: View {
    let severity: CrashSeverity
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: severity.icon)
                .foregroundColor(Color(severity.color))
            
            Text(severity.rawValue)
                .font(.caption)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CrashReportRow: View {
    let crashReport: CrashReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: crashReport.severity.icon)
                    .foregroundColor(Color(crashReport.severity.color))
                
                Text(crashReport.errorMessage)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(crashReport.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if crashReport.isUploaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            HStack {
                Text(crashReport.appVersion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(crashReport.deviceInfo.deviceModel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(crashReport.deviceInfo.systemVersion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}



// MARK: - Preview

#Preview {
    CrashReportDashboardView(
        cloudKitService: MockCloudKitService(),
        crashHandlerService: MockCrashHandlerService()
    )
}

// MARK: - Mock Services for Preview

class MockCrashHandlerService: CrashHandlerServiceProtocol {
    @Published var pendingCrashReports: [CrashReport] = []
    @Published var isCollecting = false
    
    func startCrashCollection() {}
    func stopCrashCollection() {}
    func collectCrashReport(error: Error, stackTrace: String, severity: CrashSeverity) {}
    func uploadPendingCrashReports() async {}
    func clearUploadedCrashReports() {}
}
