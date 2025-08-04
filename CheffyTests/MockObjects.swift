import Foundation
import Combine
@testable import Cheffy

// MARK: - Mock API Client
class MockOpenAIClient: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    private var shouldFail = false
    private var mockRecipe: Recipe?
    
    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func setMockRecipe(_ recipe: Recipe) {
        self.mockRecipe = recipe
    }
    
    func hasAPIKey() -> Bool {
        return true
    }
    
    func setAPIKey(_ key: String) {
        // Mock implementation
    }
    
    func testAPIKey() async -> Bool {
        return true
    }
    
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
        isLoading = true
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        if shouldFail {
            isLoading = false
            error = "Mock network error"
            throw NSError(domain: "MockError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock network error"])
        }
        
        isLoading = false
        error = nil
        
        return mockRecipe ?? Recipe(
            id: UUID(),
            name: "Mock Recipe",
            cuisine: cuisine,
            difficulty: difficulty,
            servings: servings,
            prepTime: 15,
            cookTime: 30,
            ingredients: [
                Ingredient(name: "Test Ingredient", amount: 1.0, unit: "cup", notes: "Test notes")
            ],
            steps: [
                RecipeStep(stepNumber: 1, description: "Test step", duration: 5, temperature: nil, tips: ["Test tip"])
            ],
            dietaryNotes: dietaryRestrictions,
            nutritionInfo: NutritionInfo(),
            tags: ["mock", "test"]
        )
    }
}

// MARK: - Mock Cache Manager
class MockRecipeCacheManager: ObservableObject {
    @Published var cachedRecipes: [Recipe] = []
    @Published var recentlyViewedRecipes: [Recipe] = []
    
    private var shouldFail = false
    
    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func cacheRecipe(_ recipe: Recipe) {
        if !shouldFail {
            cachedRecipes.append(recipe)
        }
    }
    
    func cacheRecipes(_ recipes: [Recipe]) {
        if !shouldFail {
            cachedRecipes.append(contentsOf: recipes)
        }
    }
    
    func getCachedRecipe(id: UUID) -> Recipe? {
        return cachedRecipes.first { $0.id == id }
    }
    
    func getCachedRecipes(cuisine: Cuisine) -> [Recipe] {
        return cachedRecipes.filter { $0.cuisine == cuisine }
    }
    
    func getCachedRecipes(difficulty: Difficulty) -> [Recipe] {
        return cachedRecipes.filter { $0.difficulty == difficulty }
    }
    
    func searchCachedRecipes(query: String) -> [Recipe] {
        return cachedRecipes.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    func removeFromCache(_ recipe: Recipe) {
        cachedRecipes.removeAll { $0.id == recipe.id }
    }
    
    func clearCache() {
        cachedRecipes.removeAll()
    }
    
    func addToRecentlyViewed(_ recipe: Recipe) {
        if !shouldFail {
            recentlyViewedRecipes.insert(recipe, at: 0)
            if recentlyViewedRecipes.count > 10 {
                recentlyViewedRecipes = Array(recentlyViewedRecipes.prefix(10))
            }
        }
    }
}

// MARK: - Mock Voice Manager
class MockVoiceManager: ObservableObject {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var error: String?
    
    private var shouldFail = false
    
    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func startListening() {
        if !shouldFail {
            isListening = true
            error = nil
        } else {
            error = "Mock permission denied"
        }
    }
    
    func stopListening() {
        isListening = false
    }
    
    func speak(_ text: String) {
        if !shouldFail {
            isSpeaking = true
            // Simulate speech duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isSpeaking = false
            }
        } else {
            error = "Mock speech synthesis failed"
        }
    }
    
    func requestPermissions() {
        // Mock implementation
    }
}

// MARK: - Mock User Manager
class MockUserManager: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var hasCompletedOnboarding = false
    @Published var isOnboarding = false
    
    private var shouldFail = false
    
    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func createUserProfile(_ profile: UserProfile) {
        if !shouldFail {
            currentUser = profile
        }
    }
    
    func updateUserProfile(_ profile: UserProfile) {
        if !shouldFail {
            currentUser = profile
        }
    }
    
    func deleteUserProfile() {
        if !shouldFail {
            currentUser = nil
        }
    }
    
    func startOnboarding() {
        if !shouldFail {
            isOnboarding = true
        }
    }
    
    func completeOnboarding() {
        if !shouldFail {
            isOnboarding = false
            hasCompletedOnboarding = true
        }
    }
    
    func resetOnboarding() {
        if !shouldFail {
            isOnboarding = false
            hasCompletedOnboarding = false
        }
    }
    
    func updateLastActive() {
        if !shouldFail {
            currentUser?.lastActive = Date()
        }
    }
}

// MARK: - Test Utilities
extension XCTestCase {
    func createMockRecipe() -> Recipe {
        return Recipe(
            id: UUID(),
            name: "Test Recipe",
            cuisine: .italian,
            difficulty: .medium,
            servings: 2,
            prepTime: 15,
            cookTime: 30,
            ingredients: [
                Ingredient(name: "Pasta", amount: 200.0, unit: "g", notes: "Any type"),
                Ingredient(name: "Olive Oil", amount: 2.0, unit: "tbsp", notes: "Extra virgin")
            ],
            steps: [
                RecipeStep(stepNumber: 1, description: "Boil pasta", duration: 10, temperature: nil, tips: ["Add salt to water"]),
                RecipeStep(stepNumber: 2, description: "Drain and serve", duration: 2, temperature: nil, tips: ["Reserve some pasta water"])
            ],
            dietaryNotes: [.vegetarian],
            nutritionInfo: NutritionInfo(),
            tags: ["pasta", "quick", "vegetarian"]
        )
    }
    
    func createMockUserProfile() -> UserProfile {
        return UserProfile(
            name: "Test User",
            email: "test@example.com",
            cookingExperience: .intermediate,
            dietaryPreferences: [.vegetarian],
            favoriteCuisines: [.italian, .french],
            cookingGoals: [.healthyEating, .quickMeals],
            householdSize: 2
        )
    }
    
    func waitForAsyncOperation(timeout: TimeInterval = 5.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
} 