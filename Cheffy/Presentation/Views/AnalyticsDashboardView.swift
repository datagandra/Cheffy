import SwiftUI

struct AnalyticsDashboardView: View {
    @StateObject private var viewModel: AnalyticsViewModel
    @State private var showingPreferencesSheet = false
    @State private var showingPrivacySettings = false
    @State private var showingDataExport = false
    
    init(analyticsService: any UserAnalyticsServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: AnalyticsViewModel(analyticsService: analyticsService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Analytics Toggle
                    analyticsToggleSection
                    
                    if viewModel.isAnalyticsEnabled {
                        // User Stats Overview
                        userStatsOverviewSection
                        
                        // User Preferences
                        if viewModel.hasPreferences {
                            userPreferencesSection
                        }
                        
                        // Feature Usage
                        featureUsageSection
                        
                        // Global Stats
                        globalStatsSection
                        
                        // Actions
                        actionsSection
                    } else {
                        // Analytics Disabled State
                        analyticsDisabledSection
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await viewModel.loadUserData()
                            await viewModel.loadAggregatedStats()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.loadUserData()
                await viewModel.loadAggregatedStats()
            }
            .refreshable {
                await viewModel.loadUserData()
                await viewModel.loadAggregatedStats()
            }
            .sheet(isPresented: $showingPreferencesSheet) {
                Text("User Preferences")
                    .font(.title)
                    .padding()
            }
            .sheet(isPresented: $showingPrivacySettings) {
                Text("Privacy Settings")
                    .font(.title)
                    .padding()
            }
            .sheet(isPresented: $showingDataExport) {
                Text("Data Export")
                    .font(.title)
                    .padding()
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
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
        }
    }
    
    // MARK: - Analytics Toggle Section
    
    private var analyticsToggleSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage Analytics")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Help improve Cheffy by sharing anonymous usage data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(viewModel.isAnalyticsEnabled))
                    .onChange(of: viewModel.isAnalyticsEnabled) { _ in
                        Task {
                            await viewModel.toggleAnalytics()
                        }
                    }
            }
            
            if viewModel.isAnalyticsEnabled {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Analytics enabled - Data is being collected anonymously")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - User Stats Overview Section
    
    private var userStatsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Your Usage", icon: "chart.bar.fill", color: .blue, isExpanded: .constant(true))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    title: "Recipes Viewed",
                    value: "\(viewModel.totalRecipesViewed)",
                    icon: "eye.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Recipes Saved",
                    value: "\(viewModel.totalRecipesSaved)",
                    icon: "bookmark.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Searches",
                    value: "\(viewModel.totalSearches)",
                    icon: "magnifyingglass",
                    color: .orange
                )
                
                StatCard(
                    title: "Time Spent",
                    value: viewModel.formattedTimeSpent,
                    icon: "clock.fill",
                    color: .purple
                )
            }
            
            // Engagement Score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Engagement Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.formattedEngagementScore)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                CircularProgressView(
                    progress: min(viewModel.userEngagementScore / 100.0, 1.0),
                    color: .blue
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - User Preferences Section
    
    private var userPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Your Preferences", icon: "person.circle.fill", color: .green, isExpanded: .constant(true))
            
            VStack(spacing: 12) {
                if !viewModel.preferredCuisines.isEmpty {
                    PreferenceRow(
                        title: "Preferred Cuisines",
                        items: viewModel.preferredCuisines,
                        icon: "globe"
                    )
                }
                
                if !viewModel.dietaryPreferences.isEmpty {
                    PreferenceRow(
                        title: "Dietary Preferences",
                        items: viewModel.dietaryPreferences,
                        icon: "leaf"
                    )
                }
            }
            
            Button("Edit Preferences") {
                showingPreferencesSheet = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Feature Usage Section
    
    private var featureUsageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Feature Usage", icon: "star.fill", color: .orange, isExpanded: .constant(true))
            
            if let mostUsedFeature = viewModel.mostUsedFeature {
                HStack {
                    Image(systemName: mostUsedFeature.0.icon)
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Most Used Feature")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(mostUsedFeature.0.displayName) (\(mostUsedFeature.1) times)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Feature usage breakdown
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(Array((viewModel.userStats?.featureUsage ?? [:]).prefix(6)), id: \.key) { feature, count in
                    if let featureEnum = UserStats.Feature(rawValue: feature) {
                        FeatureUsageCard(
                            feature: featureEnum,
                            count: count
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Global Stats Section
    
    private var globalStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Community Stats", icon: "globe", color: .purple, isExpanded: .constant(true))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    title: "Total Users",
                    value: "\(viewModel.totalUsers)",
                    icon: "person.3.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Avg. Time Spent",
                    value: viewModel.formattedAverageTimeSpent,
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Total Views",
                    value: "\(viewModel.totalRecipesViewedGlobally)",
                    icon: "eye.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Saves",
                    value: "\(viewModel.totalRecipesSavedGlobally)",
                    icon: "bookmark.fill",
                    color: .purple
                )
            }
            
            Text("Last updated: \(viewModel.lastUpdated)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button("Sync Stats") {
                Task {
                    await viewModel.syncStatsToCloudKit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            HStack(spacing: 12) {
                Button("Privacy Settings") {
                    showingPrivacySettings = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
                
                Button("Export Data") {
                    showingDataExport = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Analytics Disabled Section
    
    private var analyticsDisabledSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Analytics Disabled")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Enable analytics to see your usage statistics and help improve Cheffy.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Enable Analytics") {
                Task {
                    await viewModel.toggleAnalytics()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views



struct PreferenceRow: View {
    let title: String
    let items: [String]
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(items.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FeatureUsageCard: View {
    let feature: UserStats.Feature
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: feature.icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(count) times")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
        }
        .frame(width: 40, height: 40)
    }
}



// MARK: - Preview

#Preview {
    AnalyticsDashboardView(analyticsService: MockUserAnalyticsService())
}
