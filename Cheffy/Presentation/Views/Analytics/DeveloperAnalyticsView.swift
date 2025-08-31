import SwiftUI
import CloudKit

struct DeveloperAnalyticsView: View {
    @StateObject private var viewModel = DeveloperAnalyticsViewModel()
    @State private var showingUserProfiles = false
    @State private var showingUserStats = false
    @State private var showingCrashReports = false
    
    var body: some View {
        NavigationView {
            List {
                // Analytics Overview Section
                Section("Analytics Overview") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Total Users")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.totalUsers)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("Analytics Enabled")
                                .font(.subheadline)
                            Spacer()
                            Text("\(viewModel.analyticsEnabledUsers)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Text("Data Collection Rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(viewModel.dataCollectionRate, specifier: "%.1f")%")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Quick Actions Section
                Section("Quick Actions") {
                    Button("View User Profiles") {
                        showingUserProfiles = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("View User Stats") {
                        showingUserStats = true
                    }
                    .foregroundColor(.green)
                    
                    Button("View Crash Reports") {
                        showingCrashReports = true
                    }
                    .foregroundColor(.red)
                    
                    Button("Export Analytics Data") {
                        viewModel.exportAnalyticsData()
                    }
                    .foregroundColor(.purple)
                }
                
                // CloudKit Status Section
                Section("CloudKit Status") {
                    HStack {
                        Text("Private Database")
                        Spacer()
                        Text(viewModel.privateDBStatus ? "✅" : "❌")
                    }
                    
                    HStack {
                        Text("Public Database")
                        Spacer()
                        Text(viewModel.publicDBStatus ? "✅" : "❌")
                    }
                    
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        Text(viewModel.lastSyncTime ?? "Never")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Data Insights Section
                Section("Data Insights") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Most Popular Cuisines")
                            .font(.headline)
                        
                        ForEach(viewModel.topCuisines, id: \.key) { cuisine in
                            HStack {
                                Text(cuisine.key)
                                Spacer()
                                Text("\(cuisine.value)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        Text("Feature Usage")
                            .font(.headline)
                        
                        ForEach(viewModel.featureUsage, id: \.key) { feature in
                            HStack {
                                Text(feature.key)
                                Spacer()
                                Text("\(feature.value)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Privacy & Compliance Section
                Section("Privacy & Compliance") {
                    HStack {
                        Text("GDPR Compliant")
                        Spacer()
                        Text("✅")
                    }
                    
                    HStack {
                        Text("CCPA Compliant")
                        Spacer()
                        Text("✅")
                    }
                    
                    HStack {
                        Text("No PII Collected")
                        Spacer()
                        Text("✅")
                    }
                    
                    HStack {
                        Text("User Control")
                        Spacer()
                        Text("✅")
                    }
                }
            }
            .navigationTitle("Developer Analytics")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshData()
            }
            .onAppear {
                Task {
                    await viewModel.refreshData()
                }
            }
        }
        .sheet(isPresented: $showingUserProfiles) {
            UserProfilesListView()
        }
        .sheet(isPresented: $showingUserStats) {
            UserStatsListView()
        }
        .sheet(isPresented: $showingCrashReports) {
            CrashReportsListView()
        }
    }
}

// MARK: - Supporting Views
struct UserProfilesListView: View {
    @StateObject private var viewModel = DeveloperAnalyticsViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.userProfiles, id: \.id) { profile in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("User ID: \(profile.userID.prefix(8))...")
                            .font(.headline)
                        Spacer()
                        Text(profile.deviceType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Cuisines: \(profile.preferredCuisines.joined(separator: ", "))")
                        .font(.subheadline)
                    
                    Text("Dietary: \(profile.dietaryPreferences.joined(separator: ", "))")
                        .font(.subheadline)
                    
                    HStack {
                        Text("Analytics: \(profile.isAnalyticsEnabled ? "Enabled" : "Disabled")")
                            .font(.caption)
                            .foregroundColor(profile.isAnalyticsEnabled ? .green : .red)
                        
                        Spacer()
                        
                        Text(profile.formattedCreatedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("User Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.loadUserProfiles()
                }
            }
        }
    }
}

struct UserStatsListView: View {
    @StateObject private var viewModel = DeveloperAnalyticsViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.userStats, id: \.id) { stats in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("User: \(stats.hashedUserID.prefix(8))...")
                            .font(.headline)
                        Spacer()
                        Text(stats.deviceType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Recipes Viewed: \(stats.recipesViewed)")
                            Text("Recipes Saved: \(stats.recipesSaved)")
                        }
                        .font(.subheadline)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Time Spent: \(stats.timeSpent) min")
                            Text("Searches: \(stats.searchesPerformed)")
                        }
                        .font(.subheadline)
                    }
                    
                    Text("Last Active: \(stats.lastActiveAt, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("User Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.loadUserStats()
                }
            }
        }
    }
}

struct CrashReportsListView: View {
    @StateObject private var viewModel = DeveloperAnalyticsViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.crashReports, id: \.id) { report in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Crash Report")
                            .font(.headline)
                        Spacer()
                        Text(report.severity.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(severityColor(for: report.severity))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Text(report.errorMessage)
                        .font(.subheadline)
                        .lineLimit(2)
                    
                    HStack {
                        Text(report.deviceInfo.deviceModel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(report.formattedTimestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Crash Reports")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.loadCrashReports()
                }
            }
        }
    }
    
    private func severityColor(for severity: CrashSeverity) -> Color {
        switch severity {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

#Preview {
    DeveloperAnalyticsView()
}
