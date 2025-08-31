import Foundation
import CloudKit
import Combine
import CryptoKit

protocol UserAnalyticsServiceProtocol: ObservableObject {
    var isAnalyticsEnabled: Bool { get }
    var currentUserProfile: UserProfile? { get }
    var currentUserStats: UserStats? { get }
    var syncStatus: AnalyticsSyncStatus { get }
    
    // Publishers for @Published properties
    var isAnalyticsEnabledPublisher: Published<Bool>.Publisher { get }
    var currentUserProfilePublisher: Published<UserProfile?>.Publisher { get }
    var currentUserStatsPublisher: Published<UserStats?>.Publisher { get }
    var syncStatusPublisher: Published<AnalyticsSyncStatus>.Publisher { get }
    
    // User Profile Management
    func createUserProfile() async throws
    func updateUserProfile(_ profile: UserProfile) async throws
    func fetchUserProfile() async throws -> UserProfile?
    func toggleAnalytics() async throws
    
    // Analytics Logging
    func logRecipeView(_ recipe: Recipe) async
    func logRecipeSave(_ recipe: Recipe) async
    func logSearch(query: String) async
    func logFeatureUse(_ feature: UserStats.Feature) async
    func logSessionStart() async
    func logSessionEnd() async
    
    // Stats Management
    func fetchUserStats() async throws -> UserStats?
    func syncStatsToCloudKit() async throws
    func getAggregatedStats() async throws -> [String: Any]
    
    // Privacy & Settings
    func clearUserData() async throws
    func exportUserData() async throws -> Data
}

enum AnalyticsSyncStatus {
    case notAvailable
    case checking
    case available
    case syncing
    case error(String)
}

enum AnalyticsError: LocalizedError {
    case analyticsDisabled
    case userNotAuthenticated
    case cloudKitNotAvailable
    case syncFailed(String)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .analyticsDisabled:
            return "Analytics is disabled for this user"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .cloudKitNotAvailable:
            return "CloudKit is not available"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

@MainActor
@preconcurrency
class UserAnalyticsService: @preconcurrency UserAnalyticsServiceProtocol {
    @Published var isAnalyticsEnabled = true
    @Published var currentUserProfile: UserProfile?
    @Published var currentUserStats: UserStats?
    @Published var syncStatus: AnalyticsSyncStatus = .notAvailable
    
    // MARK: - Publishers
    var isAnalyticsEnabledPublisher: Published<Bool>.Publisher { $isAnalyticsEnabled }
    var currentUserProfilePublisher: Published<UserProfile?>.Publisher { $currentUserProfile }
    var currentUserStatsPublisher: Published<UserStats?>.Publisher { $currentUserStats }
    var syncStatusPublisher: Published<AnalyticsSyncStatus>.Publisher { $syncStatus }
    
    private let cloudKitService: any CloudKitServiceProtocol
    private let logger = Logger.shared
    private let userDefaults = UserDefaults.standard
    
    private var sessionStartTime: Date?
    private var pendingStats: [String: Any] = [:]
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Keys
    private let analyticsEnabledKey = "UserAnalyticsEnabled"
    private let userProfileKey = "UserProfile"
    private let userStatsKey = "UserStats"
    private let lastSyncKey = "LastAnalyticsSync"
    
    init(cloudKitService: any CloudKitServiceProtocol) {
        self.cloudKitService = cloudKitService
        setupService()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupService() {
        // Load saved preferences
        isAnalyticsEnabled = userDefaults.bool(forKey: analyticsEnabledKey)
        
        // Load cached data
        loadCachedData()
        
        // Start session tracking
        Task {
            await logSessionStart()
        }
        
        // Setup periodic sync
        setupPeriodicSync()
    }
    
    private func setupBindings() {
        // Monitor CloudKit status
        cloudKitService.syncStatusPublisher
            .sink { [weak self] status in
                self?.handleCloudKitStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    private func setupPeriodicSync() {
        // Sync every 5 minutes when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.syncStatsToCloudKit()
            }
        }
    }
    
    // MARK: - User Profile Management
    
    func createUserProfile() async throws {
        guard isAnalyticsEnabled else {
            throw AnalyticsError.analyticsDisabled
        }
        
        guard let userID = cloudKitService.currentUserID else {
            throw AnalyticsError.userNotAuthenticated
        }
        
        let profile = UserProfile(userID: userID)
        
        do {
            try await cloudKitService.uploadUserProfile(profile)
            currentUserProfile = profile
            saveCachedData()
            logger.info("User profile created successfully")
        } catch {
            logger.error("Failed to create user profile: \(error)")
            throw AnalyticsError.syncFailed(error.localizedDescription)
        }
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        guard isAnalyticsEnabled else {
            throw AnalyticsError.analyticsDisabled
        }
        
        do {
            try await cloudKitService.uploadUserProfile(profile)
            currentUserProfile = profile
            saveCachedData()
            logger.info("User profile updated successfully")
        } catch {
            logger.error("Failed to update user profile: \(error)")
            throw AnalyticsError.syncFailed(error.localizedDescription)
        }
    }
    
    func fetchUserProfile() async throws -> UserProfile? {
        guard isAnalyticsEnabled else {
            throw AnalyticsError.analyticsDisabled
        }
        
        guard let userID = cloudKitService.currentUserID else {
            throw AnalyticsError.userNotAuthenticated
        }
        
        do {
            let profile = try await cloudKitService.fetchUserProfile(userID: userID)
            currentUserProfile = profile
            saveCachedData()
            return profile
        } catch {
            logger.error("Failed to fetch user profile: \(error)")
            throw AnalyticsError.syncFailed(error.localizedDescription)
        }
    }
    
    func toggleAnalytics() async throws {
        isAnalyticsEnabled.toggle()
        userDefaults.set(isAnalyticsEnabled, forKey: analyticsEnabledKey)
        
        if isAnalyticsEnabled {
            // Re-enable analytics
            try await createUserProfile()
        } else {
            // Disable analytics - clear local data
            currentUserProfile = nil
            currentUserStats = nil
            clearCachedData()
        }
        
        logger.info("Analytics toggled: \(isAnalyticsEnabled)")
    }
    
    // MARK: - Analytics Logging
    
    func logRecipeView(_ recipe: Recipe) async {
        guard isAnalyticsEnabled else { return }
        
        await logEvent("recipe_view", metadata: [
            "recipe_id": recipe.id.uuidString,
            "recipe_cuisine": recipe.cuisine.rawValue,
            "recipe_difficulty": recipe.difficulty.rawValue
        ])
        
        // Update local stats
        if var stats = currentUserStats {
            stats = stats.incrementRecipesViewed()
            stats = stats.incrementFeature(.recipeView)
            currentUserStats = stats
            saveCachedData()
        }
    }
    
    func logRecipeSave(_ recipe: Recipe) async {
        guard isAnalyticsEnabled else { return }
        
        await logEvent("recipe_save", metadata: [
            "recipe_id": recipe.id.uuidString,
            "recipe_cuisine": recipe.cuisine.rawValue
        ])
        
        // Update local stats
        if var stats = currentUserStats {
            stats = stats.incrementRecipesSaved()
            stats = stats.incrementFeature(.recipeSave)
            currentUserStats = stats
            saveCachedData()
        }
    }
    
    func logSearch(query: String) async {
        guard isAnalyticsEnabled else { return }
        
        await logEvent("search", metadata: [
            "query_length": query.count,
            "query_has_filters": "false" // Could be enhanced
        ])
        
        // Update local stats
        if var stats = currentUserStats {
            stats = stats.incrementSearches()
            stats = stats.incrementFeature(.search)
            currentUserStats = stats
            saveCachedData()
        }
    }
    
    func logFeatureUse(_ feature: UserStats.Feature) async {
        guard isAnalyticsEnabled else { return }
        
        await logEvent("feature_use", metadata: [
            "feature": feature.rawValue
        ])
        
        // Update local stats
        if var stats = currentUserStats {
            stats = stats.incrementFeature(feature)
            currentUserStats = stats
            saveCachedData()
        }
    }
    
    func logSessionStart() async {
        guard isAnalyticsEnabled else { return }
        
        sessionStartTime = Date()
        
        await logEvent("session_start", metadata: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        // Update local stats
        if var stats = currentUserStats {
            stats = stats.incrementSession()
            currentUserStats = stats
            saveCachedData()
        }
    }
    
    func logSessionEnd() async {
        guard isAnalyticsEnabled, let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        await logEvent("session_end", metadata: [
            "duration": sessionDuration,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        // Update local stats
        if var stats = currentUserStats {
            stats = stats.addTimeSpent(sessionDuration)
            currentUserStats = stats
            saveCachedData()
        }
        
        sessionStartTime = nil
        
        // Sync stats to CloudKit
        try? await syncStatsToCloudKit()
    }
    
    // MARK: - Private Logging
    
    private func logEvent(_ event: String, metadata: [String: Any]) async {
        let eventData: [String: Any] = [
            "event": event,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "user_id": cloudKitService.currentUserID ?? "unknown",
            "metadata": metadata
        ]
        
        // Store in pending stats for batch sync
        pendingStats[event] = eventData
        
        // Log locally
        logger.info("Analytics event: \(event) - \(metadata)")
        
        // Sync if we have enough events or after delay
        if pendingStats.count >= 10 {
            try? await syncStatsToCloudKit()
        }
    }
    
    // MARK: - Stats Management
    
    func fetchUserStats() async throws -> UserStats? {
        guard isAnalyticsEnabled else {
            throw AnalyticsError.analyticsDisabled
        }
        
        guard let userID = cloudKitService.currentUserID else {
            throw AnalyticsError.userNotAuthenticated
        }
        
        do {
            let stats = try await cloudKitService.fetchUserStats(userID: userID)
            currentUserStats = stats
            saveCachedData()
            return stats
        } catch {
            logger.error("Failed to fetch user stats: \(error)")
            throw AnalyticsError.syncFailed(error.localizedDescription)
        }
    }
    
    func syncStatsToCloudKit() async throws {
        guard isAnalyticsEnabled else {
            throw AnalyticsError.analyticsDisabled
        }
        
        guard let userID = cloudKitService.currentUserID else {
            throw AnalyticsError.userNotAuthenticated
        }
        
        syncStatus = .syncing
        
        do {
            // Create or update user stats
            let hashedUserID = hashUserID(userID)
            var stats = currentUserStats ?? UserStats(hashedUserID: hashedUserID)
            
            // Update with current data
            stats = stats.incrementFeature(.recipeView, by: stats.recipesViewed)
            stats = stats.incrementFeature(.recipeSave, by: stats.recipesSaved)
            stats = stats.incrementFeature(.search, by: stats.searchesPerformed)
            
            try await cloudKitService.uploadUserStats(stats)
            currentUserStats = stats
            saveCachedData()
            
            // Clear pending stats
            pendingStats.removeAll()
            
            // Update last sync time
            userDefaults.set(Date(), forKey: lastSyncKey)
            
            syncStatus = .available
            logger.info("Stats synced to CloudKit successfully")
        } catch {
            syncStatus = .error(error.localizedDescription)
            logger.error("Failed to sync stats: \(error)")
            throw AnalyticsError.syncFailed(error.localizedDescription)
        }
    }
    
    func getAggregatedStats() async throws -> [String: Any] {
        guard isAnalyticsEnabled else {
            throw AnalyticsError.analyticsDisabled
        }
        
        do {
            let stats = try await cloudKitService.getAggregatedStats()
            return stats
        } catch {
            logger.error("Failed to get aggregated stats: \(error)")
            throw AnalyticsError.syncFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Privacy & Settings
    
    func clearUserData() async throws {
        guard let userID = cloudKitService.currentUserID else {
            throw AnalyticsError.userNotAuthenticated
        }
        
        do {
            try await cloudKitService.deleteUserData(userID: userID)
            
            // Clear local data
            currentUserProfile = nil
            currentUserStats = nil
            clearCachedData()
            
            logger.info("User data cleared successfully")
        } catch {
            logger.error("Failed to clear user data: \(error)")
            throw AnalyticsError.syncFailed(error.localizedDescription)
        }
    }
    
    func exportUserData() async throws -> Data {
        let exportData: [String: Any] = [
            "profile": currentUserProfile?.dictionary ?? [:],
            "stats": currentUserStats?.dictionary ?? [:],
            "exported_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    // MARK: - Helper Methods
    
    private func hashUserID(_ userID: String) -> String {
        let hash = SHA256.hash(data: userID.data(using: .utf8) ?? Data())
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func handleCloudKitStatusChange(_ status: CloudKitSyncStatus) {
        switch status {
        case .available:
            syncStatus = .available
        case .syncing:
            syncStatus = .syncing
        case .error(let message):
            syncStatus = .error(message)
        default:
            syncStatus = .notAvailable
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveCachedData() {
        if let profile = currentUserProfile {
            userDefaults.set(try? JSONEncoder().encode(profile), forKey: userProfileKey)
        }
        if let stats = currentUserStats {
            userDefaults.set(try? JSONEncoder().encode(stats), forKey: userStatsKey)
        }
    }
    
    private func loadCachedData() {
        if let profileData = userDefaults.data(forKey: userProfileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            currentUserProfile = profile
        }
        if let statsData = userDefaults.data(forKey: userStatsKey),
           let stats = try? JSONDecoder().decode(UserStats.self, from: statsData) {
            currentUserStats = stats
        }
    }
    
    private func clearCachedData() {
        userDefaults.removeObject(forKey: userProfileKey)
        userDefaults.removeObject(forKey: userStatsKey)
        userDefaults.removeObject(forKey: lastSyncKey)
    }
}

// MARK: - Mock Implementation for Testing
class MockUserAnalyticsService: UserAnalyticsServiceProtocol {
    @Published var isAnalyticsEnabled = true
    @Published var currentUserProfile: UserProfile?
    @Published var currentUserStats: UserStats?
    @Published var syncStatus: AnalyticsSyncStatus = .available
    
    // MARK: - Publishers
    var isAnalyticsEnabledPublisher: Published<Bool>.Publisher { $isAnalyticsEnabled }
    var currentUserProfilePublisher: Published<UserProfile?>.Publisher { $currentUserProfile }
    var currentUserStatsPublisher: Published<UserStats?>.Publisher { $currentUserStats }
    var syncStatusPublisher: Published<AnalyticsSyncStatus>.Publisher { $syncStatus }
    
    func createUserProfile() async throws {
        let profile = UserProfile(userID: "mock-user-id")
        currentUserProfile = profile
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        currentUserProfile = profile
    }
    
    func fetchUserProfile() async throws -> UserProfile? {
        return currentUserProfile
    }
    
    func toggleAnalytics() async throws {
        isAnalyticsEnabled.toggle()
    }
    
    func logRecipeView(_ recipe: Recipe) async {}
    func logRecipeSave(_ recipe: Recipe) async {}
    func logSearch(query: String) async {}
    func logFeatureUse(_ feature: UserStats.Feature) async {}
    func logSessionStart() async {}
    func logSessionEnd() async {}
    
    func fetchUserStats() async throws -> UserStats? {
        return currentUserStats
    }
    
    func syncStatsToCloudKit() async throws {}
    func getAggregatedStats() async throws -> [String: Any] {
        return [:]
    }
    
    func clearUserData() async throws {}
    func exportUserData() async throws -> Data {
        return Data()
    }
}
