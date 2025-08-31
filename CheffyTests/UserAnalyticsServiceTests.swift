import XCTest
@testable import Cheffy

@MainActor
final class UserAnalyticsServiceTests: XCTestCase {
    
    var analyticsService: UserAnalyticsService!
    var mockCloudKitService: MockCloudKitService!
    
    override func setUpWithError() throws {
        mockCloudKitService = MockCloudKitService()
        analyticsService = UserAnalyticsService(cloudKitService: mockCloudKitService)
    }
    
    override func tearDownWithError() throws {
        analyticsService = nil
        mockCloudKitService = nil
    }
    
    // MARK: - Test Data
    
    private func createMockRecipe() -> Recipe {
        return Recipe(
            id: UUID(),
            title: "Test Recipe",
            name: "Test Recipe",
            cuisine: .italian,
            difficulty: .medium,
            prepTime: 15,
            cookTime: 30,
            servings: 4,
            ingredients: [
                Ingredient(name: "Ingredient 1", amount: 100, unit: "g"),
                Ingredient(name: "Ingredient 2", amount: 200, unit: "ml")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Step 1"),
                CookingStep(stepNumber: 2, description: "Step 2")
            ],
            winePairings: ["Wine 1"],
            dietaryNotes: [.vegetarian],
            chefNotes: "Test recipe"
        )
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(analyticsService)
        XCTAssertTrue(analyticsService.isAnalyticsEnabled)
        XCTAssertNil(analyticsService.currentUserProfile)
        XCTAssertNil(analyticsService.currentUserStats)
        XCTAssertEqual(analyticsService.syncStatus, .notAvailable)
    }
    
    // MARK: - User Profile Management Tests
    
    func testCreateUserProfile() async throws {
        // Mock CloudKit service to return a user ID
        mockCloudKitService.currentUserID = "test-user-id"
        
        try await analyticsService.createUserProfile()
        
        XCTAssertNotNil(analyticsService.currentUserProfile)
        XCTAssertEqual(analyticsService.currentUserProfile?.userID, "test-user-id")
        XCTAssertEqual(analyticsService.currentUserProfile?.deviceType, UIDevice.current.model)
    }
    
    func testCreateUserProfileWhenDisabled() async {
        analyticsService.isAnalyticsEnabled = false
        
        do {
            try await analyticsService.createUserProfile()
            XCTFail("Should throw analytics disabled error")
        } catch let error as AnalyticsError {
            XCTAssertEqual(error, .analyticsDisabled)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testUpdateUserProfile() async throws {
        // Create initial profile
        mockCloudKitService.currentUserID = "test-user-id"
        try await analyticsService.createUserProfile()
        
        guard let profile = analyticsService.currentUserProfile else {
            XCTFail("Profile should exist")
            return
        }
        
        // Update profile
        let updatedProfile = profile.updatePreferences(cuisines: ["Italian", "Mexican"])
        try await analyticsService.updateUserProfile(updatedProfile)
        
        XCTAssertEqual(analyticsService.currentUserProfile?.preferredCuisines, ["Italian", "Mexican"])
    }
    
    func testFetchUserProfile() async throws {
        mockCloudKitService.currentUserID = "test-user-id"
        
        // Mock CloudKit service to return a profile
        let mockProfile = UserProfile(userID: "test-user-id")
        mockCloudKitService.mockUserProfiles = [mockProfile]
        
        let profile = try await analyticsService.fetchUserProfile()
        
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.userID, "test-user-id")
    }
    
    func testToggleAnalytics() async throws {
        let initialState = analyticsService.isAnalyticsEnabled
        
        try await analyticsService.toggleAnalytics()
        
        XCTAssertEqual(analyticsService.isAnalyticsEnabled, !initialState)
        
        // Toggle back
        try await analyticsService.toggleAnalytics()
        
        XCTAssertEqual(analyticsService.isAnalyticsEnabled, initialState)
    }
    
    // MARK: - Analytics Logging Tests
    
    func testLogRecipeView() async {
        let recipe = createMockRecipe()
        
        await analyticsService.logRecipeView(recipe)
        
        // Verify that stats were updated
        XCTAssertEqual(analyticsService.currentUserStats?.recipesViewed, 1)
        XCTAssertEqual(analyticsService.currentUserStats?.featureUsage["recipe_view"], 1)
    }
    
    func testLogRecipeSave() async {
        let recipe = createMockRecipe()
        
        await analyticsService.logRecipeSave(recipe)
        
        // Verify that stats were updated
        XCTAssertEqual(analyticsService.currentUserStats?.recipesSaved, 1)
        XCTAssertEqual(analyticsService.currentUserStats?.featureUsage["recipe_save"], 1)
    }
    
    func testLogSearch() async {
        let searchQuery = "pasta"
        
        await analyticsService.logSearch(query: searchQuery)
        
        // Verify that stats were updated
        XCTAssertEqual(analyticsService.currentUserStats?.searchesPerformed, 1)
        XCTAssertEqual(analyticsService.currentUserStats?.featureUsage["search"], 1)
    }
    
    func testLogFeatureUse() async {
        let feature = UserStats.Feature.imageGeneration
        
        await analyticsService.logFeatureUse(feature)
        
        // Verify that stats were updated
        XCTAssertEqual(analyticsService.currentUserStats?.featureUsage["image_generation"], 1)
    }
    
    func testLogSessionStart() async {
        await analyticsService.logSessionStart()
        
        // Verify that session count was incremented
        XCTAssertEqual(analyticsService.currentUserStats?.sessionCount, 1)
        XCTAssertEqual(analyticsService.currentUserStats?.featureUsage["session_start"], 1)
    }
    
    func testLogSessionEnd() async {
        // Start session first
        await analyticsService.logSessionStart()
        
        // Wait a bit to simulate time passing
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        await analyticsService.logSessionEnd()
        
        // Verify that time was added
        XCTAssertGreaterThan(analyticsService.currentUserStats?.timeSpent ?? 0, 0)
        XCTAssertEqual(analyticsService.currentUserStats?.featureUsage["session_end"], 1)
    }
    
    // MARK: - Stats Management Tests
    
    func testFetchUserStats() async throws {
        mockCloudKitService.currentUserID = "test-user-id"
        
        // Mock CloudKit service to return stats
        let mockStats = UserStats(hashedUserID: "test-hashed-id")
        mockCloudKitService.mockUserStats = [mockStats]
        
        let stats = try await analyticsService.fetchUserStats()
        
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.hashedUserID, "test-hashed-id")
    }
    
    func testSyncStatsToCloudKit() async throws {
        mockCloudKitService.currentUserID = "test-user-id"
        
        // Create some stats first
        await analyticsService.logRecipeView(createMockRecipe())
        await analyticsService.logRecipeSave(createMockRecipe())
        
        try await analyticsService.syncStatsToCloudKit()
        
        // Verify sync status
        XCTAssertEqual(analyticsService.syncStatus, .available)
    }
    
    func testGetAggregatedStats() async throws {
        let stats = try await analyticsService.getAggregatedStats()
        
        XCTAssertNotNil(stats)
        XCTAssertTrue(stats.keys.contains("totalUsers"))
        XCTAssertTrue(stats.keys.contains("lastUpdated"))
    }
    
    // MARK: - Privacy & Settings Tests
    
    func testClearUserData() async throws {
        mockCloudKitService.currentUserID = "test-user-id"
        
        // Create some data first
        try await analyticsService.createUserProfile()
        await analyticsService.logRecipeView(createMockRecipe())
        
        try await analyticsService.clearUserData()
        
        // Verify data was cleared
        XCTAssertNil(analyticsService.currentUserProfile)
        XCTAssertNil(analyticsService.currentUserStats)
    }
    
    func testExportUserData() async throws {
        mockCloudKitService.currentUserID = "test-user-id"
        
        // Create some data first
        try await analyticsService.createUserProfile()
        await analyticsService.logRecipeView(createMockRecipe())
        
        let exportData = try await analyticsService.exportUserData()
        
        XCTAssertNotNil(exportData)
        XCTAssertGreaterThan(exportData.count, 0)
        
        // Verify JSON is valid
        let json = try JSONSerialization.jsonObject(with: exportData)
        XCTAssertNotNil(json)
    }
    
    // MARK: - Analytics Disabled Tests
    
    func testLoggingWhenAnalyticsDisabled() async {
        analyticsService.isAnalyticsEnabled = false
        
        let recipe = createMockRecipe()
        
        await analyticsService.logRecipeView(recipe)
        await analyticsService.logRecipeSave(recipe)
        await analyticsService.logSearch(query: "test")
        
        // Verify no stats were updated
        XCTAssertNil(analyticsService.currentUserStats)
    }
    
    func testOperationsWhenAnalyticsDisabled() async {
        analyticsService.isAnalyticsEnabled = false
        
        do {
            try await analyticsService.createUserProfile()
            XCTFail("Should throw analytics disabled error")
        } catch let error as AnalyticsError {
            XCTAssertEqual(error, .analyticsDisabled)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Mock CloudKit Service Extensions

extension MockCloudKitService {
    var mockUserProfiles: [UserProfile] {
        get { return [] }
        set { }
    }
    
    var mockUserStats: [UserStats] {
        get { return [] }
        set { }
    }
    
    func uploadUserProfile(_ profile: UserProfile) async throws {
        // Mock implementation
    }
    
    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        return mockUserProfiles.first
    }
    
    func uploadUserStats(_ stats: UserStats) async throws {
        // Mock implementation
    }
    
    func fetchUserStats(userID: String) async throws -> UserStats? {
        return mockUserStats.first
    }
    
    func getAggregatedStats() async throws -> [String: Any] {
        return [
            "totalUsers": 100,
            "totalRecipesViewed": 1000,
            "totalRecipesSaved": 500,
            "totalSearches": 750,
            "averageTimeSpent": 3600.0,
            "lastUpdated": "2024-01-01T00:00:00Z"
        ]
    }
    
    func deleteUserData(userID: String) async throws {
        // Mock implementation
    }
}
