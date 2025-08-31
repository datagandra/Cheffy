import Foundation
import Combine
import CloudKit
@testable import Cheffy

// MARK: - Enhanced Mock LLM Service
class MockLLMService: OpenAIClientProtocol {
    @Published var isLoading = false
    @Published var error: String?
    
    private var shouldFail = false
    private var shouldBeSlow = false
    private var mockRecipes: [Recipe] = []
    private var callCount = 0
    private var apiKey: String?

    func configure(shouldFail: Bool = false, shouldBeSlow: Bool = false, mockRecipes: [Recipe] = []) {
        self.shouldFail = shouldFail
        self.shouldBeSlow = shouldBeSlow
        self.mockRecipes = mockRecipes
    }

    func resetCallCount() {
        callCount = 0
    }

    func getCallCount() -> Int {
        callCount
    }
    
    // MARK: - OpenAIClientProtocol Conformance
    
    func hasAPIKey() -> Bool {
        return apiKey != nil
    }
    
    func setAPIKey(_ key: String) {
        apiKey = key
    }
    
    func testAPIKey() async -> Bool {
        return apiKey != nil
    }

    func generateRecipe(userPrompt: String?, recipeName: String?, cuisine: Cuisine, difficulty: Difficulty, dietaryRestrictions: [DietaryNote], ingredients: [String]?, maxTime: Int?, servings: Int) async throws -> Recipe? {
        callCount += 1
        
        if shouldFail {
            throw MockError.simulatedFailure
        }
        
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        return generateFilteredRecipe(cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, maxTime: maxTime, servings: servings)
    }
    
    func generatePopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int? = nil,
        servings: Int = 2
    ) async throws -> [Recipe]? {
        callCount += 1
        
        if shouldFail {
            throw MockError.simulatedFailure
        }
        
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        let recipe = generateFilteredRecipe(cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, maxTime: maxTime, servings: servings)
        return [recipe]
    }
    
    func extractAllIngredientsAsText(from recipes: [Recipe]) -> String {
        return recipes.flatMap { $0.ingredients }.map { "\($0.amount) \($0.unit) \($0.name)" }.joined(separator: ", ")
    }
    
    func analyzeFilterCriteriaViolations(in recipes: [Recipe]) -> String {
        return "Mock analysis of filter criteria violations"
    }
    
    func parseRecipesFromJSONToText(_ jsonData: Data) -> String {
        return "Mock parsed recipes from JSON"
    }

    private func generateFilteredRecipe(cuisine: Cuisine, difficulty: Difficulty, dietaryRestrictions: [DietaryNote], maxTime: Int?, servings: Int) -> Recipe {
        let mockIngredients = generateMockIngredients(for: cuisine)
        let mockSteps = generateMockSteps(for: difficulty)
        
        return Recipe(
            title: "Mock \(cuisine.rawValue) Recipe",
            cuisine: cuisine,
            difficulty: difficulty,
            prepTime: 15,
            cookTime: maxTime ?? 30,
            servings: servings,
            ingredients: mockIngredients,
            steps: mockSteps
        )
    }

    private func generateMockIngredients(for cuisine: Cuisine) -> [Ingredient] {
        let baseIngredients = [
                            Ingredient(name: "Salt", amount: 1, unit: "teaspoon", notes: "To taste"),
                Ingredient(name: "Black Pepper", amount: 1, unit: "teaspoon", notes: "Freshly ground")
        ]
        
        let cuisineSpecificIngredients: [Ingredient] = {
            switch cuisine {
            case .italian:
                return [
                    Ingredient(name: "Olive Oil", amount: 2, unit: "tablespoon", notes: "Extra virgin"),
                    Ingredient(name: "Garlic", amount: 3, unit: "cloves", notes: "Minced")
                ]
            case .indian:
                return [
                                    Ingredient(name: "Cumin Seeds", amount: 1, unit: "teaspoon", notes: "Whole"),
                Ingredient(name: "Turmeric", amount: 1, unit: "teaspoon", notes: "Ground")
                ]
            case .chinese:
                return [
                    Ingredient(name: "Soy Sauce", amount: 2, unit: "tablespoon", notes: "Light"),
                    Ingredient(name: "Ginger", amount: 1, unit: "inch", notes: "Fresh, minced")
                ]
            default:
                return [
                                    Ingredient(name: "Onion", amount: 1, unit: "medium", notes: "Diced"),
                Ingredient(name: "Tomato", amount: 2, unit: "medium", notes: "Chopped")
                ]
            }
        }()
        
        return baseIngredients + cuisineSpecificIngredients
    }

    private func generateMockSteps(for difficulty: Difficulty) -> [CookingStep] {
        let baseSteps = [
            CookingStep(stepNumber: 1, description: "Prepare ingredients", duration: 10),
            CookingStep(stepNumber: 2, description: "Heat cooking vessel", duration: 5)
        ]
        
        let difficultySpecificSteps: [CookingStep] = {
            switch difficulty {
            case .easy:
                return [
                    CookingStep(stepNumber: 3, description: "Cook ingredients together", duration: 20),
                    CookingStep(stepNumber: 4, description: "Season and serve", duration: 5)
                ]
            case .medium:
                return [
                    CookingStep(stepNumber: 3, description: "Sauté aromatics", duration: 8),
                    CookingStep(stepNumber: 4, description: "Add main ingredients", duration: 15),
                    CookingStep(stepNumber: 5, description: "Simmer until done", duration: 25),
                    CookingStep(stepNumber: 6, description: "Garnish and serve", duration: 5)
                ]
            case .hard, .expert:
                return [
                    CookingStep(stepNumber: 3, description: "Prepare complex sauce", duration: 20),
                    CookingStep(stepNumber: 4, description: "Cook protein to perfection", duration: 15),
                    CookingStep(stepNumber: 5, description: "Assemble components", duration: 10),
                    CookingStep(stepNumber: 6, description: "Final plating", duration: 8)
                ]
            }
        }()
        
        return baseSteps + difficultySpecificSteps
    }
}

// MARK: - Enhanced Mock CloudKit Service
class MockCloudKitService: CloudKitServiceProtocol {
    @Published var isCloudKitAvailable = true
    @Published var currentUserID: String? = "mock-user-123"
    @Published var syncStatus: CloudKitSyncStatus = .available

    private var shouldFail = false
    private var shouldBeSlow = false
    var mockUserRecipes: [UserRecipe] = []
    var mockUserStats: [UserStats] = []
    var mockUserProfiles: [UserProfile] = []
    var mockCrashReports: [CrashReport] = []

    func configure(shouldFail: Bool = false, shouldBeSlow: Bool = false) {
        self.shouldFail = shouldFail
        self.shouldBeSlow = shouldBeSlow
    }

    func setMockData(userRecipes: [UserRecipe] = [], userStats: [UserStats] = [], userProfiles: [UserProfile] = [], crashReports: [CrashReport] = []) {
        self.mockUserRecipes = userRecipes
        self.mockUserStats = userStats
        self.mockUserProfiles = userProfiles
        self.mockCrashReports = crashReports
    }

    var syncStatusPublisher: Published<CloudKitSyncStatus>.Publisher { $syncStatus }

    func uploadUserRecipe(_ recipe: UserRecipe) async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        mockUserRecipes.append(recipe)
    }

    func fetchUserRecipes() async throws -> [UserRecipe] {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return mockUserRecipes
    }

    func uploadCrashReport(_ crashReport: CrashReport) async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        mockCrashReports.append(crashReport)
    }

    func fetchCrashReports() async throws -> [CrashReport] {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return mockCrashReports
    }

    func uploadUserProfile(_ profile: UserProfile) async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        mockUserProfiles.append(profile)
    }

    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return mockUserProfiles.first { $0.userID == userID }
    }

    func uploadUserStats(_ stats: UserStats) async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        mockUserStats.append(stats)
    }

    func fetchUserStats(userID: String) async throws -> UserStats? {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return mockUserStats.first { $0.hashedUserID == userID }
    }

    func fetchAllUserStats() async throws -> [UserStats] {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return mockUserStats
    }

    func fetchUserProfiles() async throws -> [UserProfile] {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return mockUserProfiles
    }

    func fetchPublicRecipes() async throws -> [UserRecipe] {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return mockUserRecipes
    }

    func deleteUserRecipe(_ recipe: UserRecipe) async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        mockUserRecipes.removeAll { $0.id == recipe.id }
    }

    func getAggregatedStats() async throws -> [String: Any] {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return [
            "totalUsers": mockUserProfiles.count,
            "totalRecipes": mockUserRecipes.count,
            "totalStats": mockUserStats.count
        ]
    }

    func deleteUserData(userID: String) async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        mockUserProfiles.removeAll { $0.userID == userID }
        mockUserStats.removeAll { $0.hashedUserID == userID }
    }

    func checkCloudKitStatus() async {
        if shouldBeSlow {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        syncStatus = shouldFail ? .error("Mock error") : .available
    }

    func requestPermission() async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
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

    // MARK: - Protocol Required Methods
    
    func createUserProfile() async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        // Create a mock profile
        currentUserProfile = UserProfile(
            userID: UUID().uuidString,
            deviceType: "iPhone",
            preferredCuisines: ["italian"],
            dietaryPreferences: ["vegetarian"],
            appVersion: "1.0.0",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            isAnalyticsEnabled: true
        )
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        currentUserProfile = profile
    }
    
    func fetchUserProfile() async throws -> UserProfile? {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return currentUserProfile
    }
    
    func toggleAnalytics() async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        isAnalyticsEnabled.toggle()
    }
    
    func getAggregatedStats() async throws -> [String: Any] {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return [
            "total_views": analyticsEvents["recipe_view"] ?? 0,
            "total_saves": analyticsEvents["recipe_save"] ?? 0,
            "total_searches": analyticsEvents["search"] ?? 0
        ]
    }

    func logRecipeView(_ recipe: Recipe) async {
        analyticsEvents["recipe_view", default: 0] += 1
    }

    func logRecipeSave(_ recipe: Recipe) async {
        analyticsEvents["recipe_save", default: 0] += 1
    }

    func logSearch(query: String) async {
        analyticsEvents["search", default: 0] += 1
    }

    func logFeatureUse(_ feature: UserStats.Feature) async {
        analyticsEvents["feature_\(feature.rawValue)", default: 0] += 1
    }

    func logSessionStart() async {
        analyticsEvents["session_start", default: 0] += 1
    }

    func logSessionEnd() async {
        analyticsEvents["session_end", default: 0] += 1
    }

    func setupService() async {
        if shouldBeSlow {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    func fetchUserStats() async throws -> UserStats? {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return currentUserStats
    }

    func clearUserData() async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        currentUserStats = nil
        currentUserProfile = nil
    }

    func exportUserData() async throws -> Data {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        return Data()
    }

    func syncStatsToCloudKit() async throws {
        if shouldFail {
            throw MockError.simulatedFailure
        }
        if shouldBeSlow {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}

// MARK: - Mock Error Types
enum MockError: Error, LocalizedError {
    case simulatedFailure
    case networkError
    case timeoutError

    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            return "Simulated failure for testing"
        case .networkError:
            return "Network error for testing"
        case .timeoutError:
            return "Timeout error for testing"
        }
    }
}
