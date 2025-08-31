import Foundation
import Combine

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var userStats: UserStats?
    @Published var aggregatedStats: [String: Any] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var successMessage = ""
    @Published var showingPrivacySettings = false
    @Published var showingDataExport = false
    
    private let analyticsService: any UserAnalyticsServiceProtocol
    private let logger = Logger.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init(analyticsService: any UserAnalyticsServiceProtocol) {
        self.analyticsService = analyticsService
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor analytics service state
        analyticsService.currentUserProfilePublisher
            .assign(to: \.userProfile, on: self)
            .store(in: &cancellables)
        
        analyticsService.currentUserStatsPublisher
            .assign(to: \.userStats, on: self)
            .store(in: &cancellables)
        
        analyticsService.isAnalyticsEnabledPublisher
            .sink { [weak self] enabled in
                if !enabled {
                    self?.userProfile = nil
                    self?.userStats = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadUserData() async {
        guard analyticsService.isAnalyticsEnabled else {
            showError("Analytics is disabled")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let profile = analyticsService.fetchUserProfile()
            async let stats = analyticsService.fetchUserStats()
            
            let (fetchedProfile, fetchedStats) = try await (profile, stats)
            
            userProfile = fetchedProfile
            userStats = fetchedStats
            
            if fetchedProfile == nil {
                try await analyticsService.createUserProfile()
            }
            
            showSuccess("User data loaded successfully")
        } catch {
            showError("Failed to load user data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func updateUserPreferences(cuisines: [String]? = nil, dietary: [String]? = nil) async {
        guard let profile = userProfile else {
            showError("No user profile found")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedProfile = profile.updatePreferences(cuisines: cuisines, dietary: dietary)
            try await analyticsService.updateUserProfile(updatedProfile)
            showSuccess("Preferences updated successfully")
        } catch {
            showError("Failed to update preferences: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func toggleAnalytics() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await analyticsService.toggleAnalytics()
            showSuccess("Analytics \(analyticsService.isAnalyticsEnabled ? "enabled" : "disabled")")
        } catch {
            showError("Failed to toggle analytics: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func loadAggregatedStats() async {
        guard analyticsService.isAnalyticsEnabled else {
            showError("Analytics is disabled")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let stats = try await analyticsService.getAggregatedStats()
            aggregatedStats = stats
            showSuccess("Aggregated stats loaded successfully")
        } catch {
            showError("Failed to load aggregated stats: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func syncStatsToCloudKit() async {
        guard analyticsService.isAnalyticsEnabled else {
            showError("Analytics is disabled")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await analyticsService.syncStatsToCloudKit()
            showSuccess("Stats synced successfully")
        } catch {
            showError("Failed to sync stats: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func clearUserData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await analyticsService.clearUserData()
            showSuccess("User data cleared successfully")
        } catch {
            showError("Failed to clear user data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func exportUserData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await analyticsService.exportUserData()
            
            // Save to documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let exportPath = documentsPath.appendingPathComponent("cheffy_analytics_export.json")
            
            try data.write(to: exportPath)
            
            showSuccess("Data exported to: \(exportPath.lastPathComponent)")
        } catch {
            showError("Failed to export user data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
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
    
    var isAnalyticsEnabled: Bool {
        analyticsService.isAnalyticsEnabled
    }
    
    var syncStatus: AnalyticsSyncStatus {
        analyticsService.syncStatus
    }
    
    var hasUserData: Bool {
        userProfile != nil || userStats != nil
    }
    
    var userEngagementScore: Double {
        userStats?.engagementScore ?? 0.0
    }
    
    var formattedEngagementScore: String {
        String(format: "%.1f", userEngagementScore)
    }
    
    var totalRecipesViewed: Int {
        userStats?.recipesViewed ?? 0
    }
    
    var totalRecipesSaved: Int {
        userStats?.recipesSaved ?? 0
    }
    
    var totalSearches: Int {
        userStats?.searchesPerformed ?? 0
    }
    
    var formattedTimeSpent: String {
        userStats?.formattedTimeSpent ?? "0m"
    }
    
    var sessionCount: Int {
        userStats?.sessionCount ?? 0
    }
    
    var mostUsedFeature: (UserStats.Feature, Int)? {
        userStats?.mostUsedFeature
    }
    
    var hasPreferences: Bool {
        userProfile?.hasPreferences ?? false
    }
    
    var preferredCuisines: [String] {
        userProfile?.preferredCuisines ?? []
    }
    
    var dietaryPreferences: [String] {
        userProfile?.dietaryPreferences ?? []
    }
    
    // MARK: - Aggregated Stats Helpers
    
    var totalUsers: Int {
        aggregatedStats["totalUsers"] as? Int ?? 0
    }
    
    var totalRecipesViewedGlobally: Int {
        aggregatedStats["totalRecipesViewed"] as? Int ?? 0
    }
    
    var totalRecipesSavedGlobally: Int {
        aggregatedStats["totalRecipesSaved"] as? Int ?? 0
    }
    
    var totalSearchesGlobally: Int {
        aggregatedStats["totalSearches"] as? Int ?? 0
    }
    
    var averageTimeSpent: TimeInterval {
        aggregatedStats["averageTimeSpent"] as? TimeInterval ?? 0
    }
    
    var formattedAverageTimeSpent: String {
        let hours = Int(averageTimeSpent) / 3600
        let minutes = Int(averageTimeSpent) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var globalFeatureUsage: [String: Int] {
        aggregatedStats["featureUsage"] as? [String: Int] ?? [:]
    }
    
    var deviceTypeDistribution: [String: Int] {
        aggregatedStats["deviceTypes"] as? [String: Int] ?? [:]
    }
    
    var appVersionDistribution: [String: Int] {
        aggregatedStats["appVersions"] as? [String: Int] ?? [:]
    }
    
    var lastUpdated: String {
        aggregatedStats["lastUpdated"] as? String ?? "Never"
    }
}

// MARK: - Mock Implementation for Testing
class MockAnalyticsViewModel: AnalyticsViewModel {
    override init(analyticsService: any UserAnalyticsServiceProtocol) {
        super.init(analyticsService: analyticsService)
        
        // Add some mock data for testing
        userProfile = UserProfile(
            userID: "mock-user-id",
            preferredCuisines: ["Italian", "Mexican"],
            dietaryPreferences: ["Vegetarian"]
        )
        
        userStats = UserStats(
            hashedUserID: "mock-hashed-id",
            recipesViewed: 25,
            recipesSaved: 8,
            timeSpent: 7200, // 2 hours
            searchesPerformed: 12,
            featureUsage: [
                "recipe_view": 25,
                "recipe_save": 8,
                "search": 12,
                "image_generation": 3
            ]
        )
        
        aggregatedStats = [
            "totalUsers": 150,
            "totalRecipesViewed": 3750,
            "totalRecipesSaved": 1200,
            "totalSearches": 1800,
            "averageTimeSpent": 5400.0
        ]
    }
}
