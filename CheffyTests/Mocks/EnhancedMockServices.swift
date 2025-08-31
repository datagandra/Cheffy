import Foundation
import Combine
import CloudKit
@testable import Cheffy

// MARK: - Enhanced Mock LLM Service
class MockLLMService: LLMServiceProtocol {
    @Published var isGenerating = false
    @Published var lastGeneratedRecipe: Recipe?
    @Published var error: Error?
    
    private var shouldFail = false
    private var shouldBeSlow = false
    private var mockRecipes: [Recipe] = []
    private var callCount = 0
    
    // Configuration
    func configure(shouldFail: Bool = false, shouldBeSlow: Bool = false, mockRecipes: [Recipe] = []) {
        self.shouldFail = shouldFail
        self.shouldBeSlow = shouldBeSlow
        self.mockRecipes = mockRecipes
    }
    
    func resetCallCount() {
        callCount = 0
    }
    
    func getCallCount() -> Int {
        return callCount
    }
    
    // MARK: - LLM Service Protocol Implementation
    func generateRecipe(
        userPrompt: String?,
        recipeName: String?,
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        ingredients: [String]?,
        maxTime: Int?,
        servings: Int
    ) async throws -> Recipe {
        callCount += 1
        isGenerating = true
        
        // Simulate network delay
        let delay: UInt64 = shouldBeSlow ? 3_000_000_000 : 500_000_000 // 3s or 0.5s
        try await Task.sleep(nanoseconds: delay)
        
        if shouldFail {
            isGenerating = false
            let error = NSError(domain: "MockLLMError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock LLM service failure"])
            self.error = error
            throw error
        }
        
        // Generate recipe based on filters
        let recipe = generateFilteredRecipe(
            cuisine: cuisine,
            difficulty: difficulty,
            dietaryRestrictions: dietaryRestrictions,
            maxTime: maxTime,
            servings: servings
        )
        
        isGenerating = false
        lastGeneratedRecipe = recipe
        error = nil
        
        return recipe
    }
    
    private func generateFilteredRecipe(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int?,
        servings: Int
    ) -> Recipe {
        let recipeName = "Mock \(cuisine.rawValue.capitalized) Recipe"
        let prepTime = maxTime.map { min($0 / 3, 20) } ?? 15
        let cookTime = maxTime.map { min($0 * 2 / 3, 60) } ?? 30
        
        return Recipe(
            id: UUID(),
            name: recipeName,
            cuisine: cuisine,
            difficulty: difficulty,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime,
            ingredients: generateMockIngredients(for: cuisine),
            steps: generateMockSteps(for: difficulty),
            dietaryNotes: dietaryRestrictions,
            nutritionInfo: NutritionInfo(),
            tags: [cuisine.rawValue, difficulty.rawValue, "mock"]
        )
    }
    
    private func generateMockIngredients(for cuisine: Cuisine) -> [Ingredient] {
        let baseIngredients = [
            Ingredient(name: "Olive Oil", amount: 2, unit: "tbsp", notes: "Extra virgin"),
            Ingredient(name: "Salt", amount: 1, unit: "tsp", notes: "To taste"),
            Ingredient(name: "Black Pepper", amount: 0.5, unit: "tsp", notes: "Freshly ground")
        ]
        
        let cuisineSpecificIngredients: [Ingredient] = {
            switch cuisine {
            case .italian:
                return [Ingredient(name: "Basil", amount: 0.25, unit: "cup", notes: "Fresh leaves")]
            case .indian:
                return [Ingredient(name: "Garam Masala", amount: 1, unit: "tsp", notes: "Ground spice blend")]
            case .chinese:
                return [Ingredient(name: "Soy Sauce", amount: 2, unit: "tbsp", notes: "Low sodium")]
            case .mexican:
                return [Ingredient(name: "Cumin", amount: 1, unit: "tsp", notes: "Ground")]
            case .japanese:
                return [Ingredient(name: "Mirin", amount: 1, unit: "tbsp", notes: "Sweet rice wine")]
            default:
                return []
            }
        }()
        
        return baseIngredients + cuisineSpecificIngredients
    }
    
    private func generateMockSteps(for difficulty: Difficulty) -> [RecipeStep] {
        let stepCount: Int
        let stepComplexity: String
        
        switch difficulty {
        case .easy:
            stepCount = 3
            stepComplexity = "simple"
        case .medium:
            stepCount = 5
            stepComplexity = "moderate"
        case .hard:
            stepCount = 7
            stepComplexity = "complex"
        default:
            stepCount = 4
            stepComplexity = "standard"
        }
        
        var steps: [RecipeStep] = []
        for i in 1...stepCount {
            steps.append(RecipeStep(
                stepNumber: i,
                description: "Step \(i): Perform \(stepComplexity) cooking action",
                duration: 5 + (i * 2),
                temperature: i % 2 == 0 ? 350 : nil,
                tips: ["Tip for step \(i)"]
            ))
        }
        
        return steps
    }
}

// MARK: - Enhanced Mock CloudKit Service
class MockCloudKitService: CloudKitServiceProtocol {
    @Published var isCloudKitAvailable = true
    @Published var currentUserID: String? = "mock-user-123"
    @Published var syncStatus: CloudKitSyncStatus = .available
    
    private var shouldFail = false
    private var shouldBeSlow = false
    private var mockUserRecipes: [UserRecipe] = []
    private var mockUserStats: [UserStats] = []
    private var mockUserProfiles: [UserProfile] = []
    private var mockCrashReports: [CrashReport] = []
    
    // Configuration
    func configure(shouldFail: Bool = false, shouldBeSlow: Bool = false) {
        self.shouldFail = shouldFail
        self.shouldBeSlow = shouldBeSlow
    }
    
    func setMockData(
        userRecipes: [UserRecipe] = [],
        userStats: [UserStats] = [],
        userProfiles: [UserProfile] = [],
        crashReports: [CrashReport] = []
    ) {
        self.mockUserRecipes = userRecipes
        self.mockUserStats = userStats
        self.mockUserProfiles = userProfiles
        self.mockCrashReports = crashReports
    }
    
    // MARK: - CloudKit Service Protocol Implementation
    var syncStatusPublisher: Published<CloudKitSyncStatus>.Publisher { $syncStatus }
    
    func uploadUserRecipe(_ recipe: UserRecipe) async throws {
        if shouldFail {
            throw CloudKitError.uploadFailed
        }
        
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay
        }
        
        mockUserRecipes.append(recipe)
        syncStatus = .syncing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s sync
        syncStatus = .available
    }
    
    func fetchUserRecipes() async throws -> [UserRecipe] {
        if shouldFail {
            throw CloudKitError.fetchFailed
        }
        
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay
        }
        
        return mockUserRecipes
    }
    
    func uploadUserProfile(_ profile: UserProfile) async throws {
        if shouldFail {
            throw CloudKitError.uploadFailed
        }
        
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
        }
        
        mockUserProfiles.append(profile)
    }
    
    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        if shouldFail {
            throw CloudKitError.fetchFailed
        }
        
        return mockUserProfiles.first { $0.id == userID }
    }
    
    func uploadUserStats(_ stats: UserStats) async throws {
        if shouldFail {
            throw CloudKitError.uploadFailed
        }
        
        mockUserStats.append(stats)
    }
    
    func fetchUserStats(userID: String) async throws -> UserStats? {
        if shouldFail {
            throw CloudKitError.fetchFailed
        }
        
        return mockUserStats.first { $0.id == userID }
    }
    
    func fetchAllUserStats() async throws -> [UserStats] {
        if shouldFail {
            throw CloudKitError.fetchFailed
        }
        
        return mockUserStats
    }
    
    func fetchUserProfiles() async throws -> [UserProfile] {
        if shouldFail {
            throw CloudKitError.fetchFailed
        }
        
        return mockUserProfiles
    }
    
    func getAggregatedStats() async throws -> [String: Any] {
        if shouldFail {
            throw CloudKitError.fetchFailed
        }
        
        return [
            "totalUsers": mockUserProfiles.count,
            "totalRecipes": mockUserRecipes.count,
            "totalStats": mockUserStats.count
        ]
    }
    
    func deleteUserData(userID: String) async throws {
        if shouldFail {
            throw CloudKitError.deleteFailed
        }
        
        mockUserRecipes.removeAll { $0.authorID == userID }
        mockUserStats.removeAll { $0.id == userID }
        mockUserProfiles.removeAll { $0.id == userID }
    }
    
    func uploadCrashReport(_ crashReport: CrashReport) async throws {
        if shouldFail {
            throw CloudKitError.uploadFailed
        }
        
        mockCrashReports.append(crashReport)
    }
    
    func fetchCrashReports() async throws -> [CrashReport] {
        if shouldFail {
            throw CloudKitError.fetchFailed
        }
        
        return mockCrashReports
    }
}

// MARK: - Enhanced Mock User Analytics Service
class MockUserAnalyticsService: UserAnalyticsServiceProtocol {
    @Published var isAnalyticsEnabled = true
    @Published var currentUserProfile: UserProfile?
    @Published var currentUserStats: UserStats?
    @Published var syncStatus: AnalyticsSyncStatus = .available
    
    // Publishers
    var isAnalyticsEnabledPublisher: Published<Bool>.Publisher { $isAnalyticsEnabled }
    var currentUserProfilePublisher: Published<UserProfile?>.Publisher { $currentUserProfile }
    var currentUserStatsPublisher: Published<UserStats?>.Publisher { $currentUserStats }
    var syncStatusPublisher: Published<AnalyticsSyncStatus>.Publisher { $syncStatus }
    
    private var shouldFail = false
    private var shouldBeSlow = false
    private var analyticsEvents: [String: Int] = [:]
    
    // Configuration
    func configure(shouldFail: Bool = false, shouldBeSlow: Bool = false) {
        self.shouldFail = shouldFail
        self.shouldBeSlow = shouldBeSlow
    }
    
    func getAnalyticsEvents() -> [String: Int] {
        return analyticsEvents
    }
    
    func resetAnalytics() {
        analyticsEvents.removeAll()
    }
    
    // MARK: - User Analytics Service Protocol Implementation
    func createUserProfile() async throws {
        if shouldFail {
            throw AnalyticsError.profileCreationFailed
        }
        
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
        }
        
        let profile = UserProfile(
            id: UUID().uuidString,
            deviceType: "iPhone",
            preferredCuisines: ["italian", "indian"],
            dietaryPreferences: ["vegetarian"],
            appVersion: "1.0.0",
            isAnalyticsEnabled: true,
            createdAt: Date()
        )
        
        currentUserProfile = profile
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        if shouldFail {
            throw AnalyticsError.profileUpdateFailed
        }
        
        currentUserProfile = profile
    }
    
    func fetchUserProfile() async throws -> UserProfile? {
        if shouldFail {
            throw AnalyticsError.profileFetchFailed
        }
        
        return currentUserProfile
    }
    
    func toggleAnalytics() async throws {
        if shouldFail {
            throw AnalyticsError.analyticsToggleFailed
        }
        
        isAnalyticsEnabled.toggle()
        
        if let profile = currentUserProfile {
            currentUserProfile = profile.toggleAnalytics()
        }
    }
    
    func logRecipeView(_ recipe: Recipe) async throws {
        if shouldFail {
            throw AnalyticsError.loggingFailed
        }
        
        analyticsEvents["recipe_view", default: 0] += 1
        
        if let stats = currentUserStats {
            currentUserStats = stats.incrementRecipeViews()
        }
    }
    
    func logRecipeSave(_ recipe: Recipe) async throws {
        if shouldFail {
            throw AnalyticsError.loggingFailed
        }
        
        analyticsEvents["recipe_save", default: 0] += 1
        
        if let stats = currentUserStats {
            currentUserStats = stats.incrementRecipeSaves()
        }
    }
    
    func logSearch(query: String) async throws {
        if shouldFail {
            throw AnalyticsError.loggingFailed
        }
        
        analyticsEvents["search", default: 0] += 1
        
        if let stats = currentUserStats {
            currentUserStats = stats.incrementSearches()
        }
    }
    
    func logFeatureUse(_ feature: UserStats.Feature) async throws {
        if shouldFail {
            throw AnalyticsError.loggingFailed
        }
        
        analyticsEvents["feature_\(feature.rawValue)", default: 0] += 1
        
        if let stats = currentUserStats {
            currentUserStats = stats.incrementFeatureUsage(feature)
        }
    }
    
    func logSessionStart() async throws {
        if shouldFail {
            throw AnalyticsError.loggingFailed
        }
        
        analyticsEvents["session_start", default: 0] += 1
    }
    
    func logSessionEnd(duration: TimeInterval) async throws {
        if shouldFail {
            throw AnalyticsError.loggingFailed
        }
        
        analyticsEvents["session_end", default: 0] += 1
        
        if let stats = currentUserStats {
            currentUserStats = stats.addSessionTime(duration)
        }
    }
    
    func syncStatsToCloudKit() async throws {
        if shouldFail {
            throw AnalyticsError.syncFailed
        }
        
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay
        }
        
        syncStatus = .syncing
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s sync
        syncStatus = .available
    }
    
    func getAggregatedStats() async throws -> [String: Any] {
        if shouldFail {
            throw AnalyticsError.aggregationFailed
        }
        
        return [
            "totalEvents": analyticsEvents.values.reduce(0, +),
            "eventBreakdown": analyticsEvents,
            "userProfile": currentUserProfile != nil,
            "userStats": currentUserStats != nil
        ]
    }
}

// MARK: - Mock Error Types
enum MockError: Error, LocalizedError {
    case networkFailure
    case timeout
    case invalidResponse
    case mockConfigurationError
    
    var errorDescription: String? {
        switch self {
        case .networkFailure:
            return "Mock network failure"
        case .timeout:
            return "Mock timeout"
        case .invalidResponse:
            return "Mock invalid response"
        case .mockConfigurationError:
            return "Mock configuration error"
        }
    }
}
