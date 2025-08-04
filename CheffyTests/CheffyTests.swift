import XCTest
import Combine
@testable import Cheffy

final class CheffyTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - RecipeManager Tests
    
    func testRecipeManagerInitialization() {
        // Given
        let recipeManager = RecipeManager()
        
        // Then
        XCTAssertNotNil(recipeManager)
        XCTAssertFalse(recipeManager.isLoading)
        XCTAssertNil(recipeManager.error)
        XCTAssertEqual(recipeManager.generationCount, 0)
    }
    
    func testRecipeManagerGenerateRecipe() async {
        // Given
        let recipeManager = RecipeManager()
        let expectation = XCTestExpectation(description: "Recipe generation")
        
        // When
        await recipeManager.generateRecipe(
            userPrompt: "Test recipe",
            recipeName: nil,
            cuisine: .italian,
            difficulty: .medium,
            dietaryRestrictions: [],
            ingredients: nil,
            maxTime: nil,
            servings: 2
        )
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertNotNil(recipeManager.generatedRecipe)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testRecipeManagerToggleFavorite() {
        // Given
        let recipeManager = RecipeManager()
        let testRecipe = Recipe(
            id: UUID(),
            name: "Test Recipe",
            cuisine: .italian,
            difficulty: .medium,
            servings: 2,
            prepTime: 15,
            cookTime: 30,
            ingredients: [],
            steps: [],
            dietaryNotes: [],
            nutritionInfo: NutritionInfo(),
            tags: []
        )
        
        // When
        recipeManager.toggleFavorite(testRecipe)
        
        // Then
        XCTAssertTrue(recipeManager.favorites.contains(testRecipe))
        
        // When toggling again
        recipeManager.toggleFavorite(testRecipe)
        
        // Then
        XCTAssertFalse(recipeManager.favorites.contains(testRecipe))
    }
    
    // MARK: - SubscriptionManager Tests
    
    func testSubscriptionManagerInitialization() {
        // Given
        let subscriptionManager = SubscriptionManager()
        
        // Then
        XCTAssertNotNil(subscriptionManager)
        XCTAssertFalse(subscriptionManager.isSubscribed)
        XCTAssertEqual(subscriptionManager.subscriptionTier, .free)
        XCTAssertEqual(subscriptionManager.daysUntilExpiry, 0)
        XCTAssertFalse(subscriptionManager.canGenerateUnlimitedRecipes)
    }
    
    func testSubscriptionManagerPurchaseSubscription() async {
        // Given
        let subscriptionManager = SubscriptionManager()
        let expectation = XCTestExpectation(description: "Subscription purchase")
        
        // When
        let result = await subscriptionManager.purchaseSubscription(tier: .premium)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(subscriptionManager.isSubscribed)
        XCTAssertEqual(subscriptionManager.subscriptionTier, .premium)
        XCTAssertTrue(subscriptionManager.canGenerateUnlimitedRecipes)
        XCTAssertGreaterThan(subscriptionManager.daysUntilExpiry, 0)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testSubscriptionManagerCancelSubscription() {
        // Given
        let subscriptionManager = SubscriptionManager()
        subscriptionManager.isSubscribed = true
        subscriptionManager.subscriptionTier = .premium
        subscriptionManager.canGenerateUnlimitedRecipes = true
        subscriptionManager.daysUntilExpiry = 30
        
        // When
        subscriptionManager.cancelSubscription()
        
        // Then
        XCTAssertFalse(subscriptionManager.isSubscribed)
        XCTAssertEqual(subscriptionManager.subscriptionTier, .free)
        XCTAssertFalse(subscriptionManager.canGenerateUnlimitedRecipes)
        XCTAssertEqual(subscriptionManager.daysUntilExpiry, 0)
    }
    
    // MARK: - UserManager Tests
    
    func testUserManagerInitialization() {
        // Given
        let userManager = UserManager()
        
        // Then
        XCTAssertNotNil(userManager)
        XCTAssertFalse(userManager.hasCompletedOnboarding)
        XCTAssertFalse(userManager.isOnboarding)
    }
    
    func testUserManagerCreateUserProfile() {
        // Given
        let userManager = UserManager()
        let testProfile = UserProfile(
            name: "Test User",
            email: "test@example.com",
            cookingExperience: .intermediate,
            dietaryPreferences: [.vegetarian],
            favoriteCuisines: [.italian],
            cookingGoals: [.healthyEating],
            householdSize: 2
        )
        
        // When
        userManager.createUserProfile(testProfile)
        
        // Then
        XCTAssertEqual(userManager.currentUser?.name, "Test User")
        XCTAssertEqual(userManager.currentUser?.email, "test@example.com")
        XCTAssertEqual(userManager.currentUser?.cookingExperience, .intermediate)
    }
    
    func testUserManagerOnboardingFlow() {
        // Given
        let userManager = UserManager()
        
        // When starting onboarding
        userManager.startOnboarding()
        
        // Then
        XCTAssertTrue(userManager.isOnboarding)
        XCTAssertFalse(userManager.hasCompletedOnboarding)
        
        // When completing onboarding
        userManager.completeOnboarding()
        
        // Then
        XCTAssertFalse(userManager.isOnboarding)
        XCTAssertTrue(userManager.hasCompletedOnboarding)
    }
    
    // MARK: - RecipeCacheManager Tests
    
    func testRecipeCacheManagerInitialization() {
        // Given
        let cacheManager = RecipeCacheManager.shared
        
        // Then
        XCTAssertNotNil(cacheManager)
        XCTAssertTrue(cacheManager.cachedRecipes.isEmpty)
        XCTAssertTrue(cacheManager.recentlyViewedRecipes.isEmpty)
    }
    
    func testRecipeCacheManagerCacheRecipe() {
        // Given
        let cacheManager = RecipeCacheManager.shared
        let testRecipe = Recipe(
            id: UUID(),
            name: "Cached Recipe",
            cuisine: .french,
            difficulty: .easy,
            servings: 4,
            prepTime: 10,
            cookTime: 20,
            ingredients: [],
            steps: [],
            dietaryNotes: [],
            nutritionInfo: NutritionInfo(),
            tags: []
        )
        
        // When
        cacheManager.cacheRecipe(testRecipe)
        
        // Then
        XCTAssertTrue(cacheManager.cachedRecipes.contains(testRecipe))
        XCTAssertEqual(cacheManager.cachedRecipes.count, 1)
    }
    
    func testRecipeCacheManagerRemoveFromCache() {
        // Given
        let cacheManager = RecipeCacheManager.shared
        let testRecipe = Recipe(
            id: UUID(),
            name: "Test Recipe",
            cuisine: .italian,
            difficulty: .medium,
            servings: 2,
            prepTime: 15,
            cookTime: 30,
            ingredients: [],
            steps: [],
            dietaryNotes: [],
            nutritionInfo: NutritionInfo(),
            tags: []
        )
        
        cacheManager.cacheRecipe(testRecipe)
        XCTAssertTrue(cacheManager.cachedRecipes.contains(testRecipe))
        
        // When
        cacheManager.removeFromCache(testRecipe)
        
        // Then
        XCTAssertFalse(cacheManager.cachedRecipes.contains(testRecipe))
    }
    
    // MARK: - OpenAIClient Tests
    
    func testOpenAIClientInitialization() {
        // Given
        let apiClient = OpenAIClient()
        
        // Then
        XCTAssertNotNil(apiClient)
        XCTAssertFalse(apiClient.hasAPIKey())
        XCTAssertFalse(apiClient.isLoading)
        XCTAssertNil(apiClient.error)
    }
    
    func testOpenAIClientSetAPIKey() {
        // Given
        let apiClient = OpenAIClient()
        let testAPIKey = "test_api_key_123"
        
        // When
        apiClient.setAPIKey(testAPIKey)
        
        // Then
        XCTAssertTrue(apiClient.hasAPIKey())
    }
    
    // MARK: - VoiceManager Tests
    
    func testVoiceManagerInitialization() {
        // Given
        let voiceManager = VoiceManager()
        
        // Then
        XCTAssertNotNil(voiceManager)
        XCTAssertFalse(voiceManager.isListening)
        XCTAssertFalse(voiceManager.isSpeaking)
        XCTAssertTrue(voiceManager.transcribedText.isEmpty)
        XCTAssertNil(voiceManager.error)
    }
    
    func testVoiceManagerSpeak() {
        // Given
        let voiceManager = VoiceManager()
        let testText = "Hello, this is a test"
        
        // When
        voiceManager.speak(testText)
        
        // Then
        // Note: In a real test, we'd mock the speech synthesizer
        // For now, we just verify the method doesn't crash
        XCTAssertNotNil(voiceManager)
    }
    
    // MARK: - Async/Combine Tests
    
    func testAsyncRecipeGeneration() async {
        // Given
        let recipeManager = RecipeManager()
        let expectation = XCTestExpectation(description: "Async recipe generation")
        
        // When
        Task {
            await recipeManager.generateRecipe(
                userPrompt: "Quick pasta",
                recipeName: nil,
                cuisine: .italian,
                difficulty: .easy,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: 30,
                servings: 2
            )
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertNotNil(recipeManager.generatedRecipe)
    }
    
    func testCombinePublishers() {
        // Given
        let recipeManager = RecipeManager()
        let expectation = XCTestExpectation(description: "Combine publisher test")
        
        // When
        recipeManager.$isLoading
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger loading state
        Task {
            await recipeManager.generateRecipe(
                userPrompt: "Test",
                recipeName: nil,
                cuisine: .italian,
                difficulty: .medium,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: nil,
                servings: 2
            )
        }
        
        // Then
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Given
        let recipeManager = RecipeManager()
        
        // When - Simulate error state
        recipeManager.error = "Network error occurred"
        
        // Then
        XCTAssertNotNil(recipeManager.error)
        XCTAssertEqual(recipeManager.error, "Network error occurred")
        
        // When - Clear error
        recipeManager.error = nil
        
        // Then
        XCTAssertNil(recipeManager.error)
    }
    
    // MARK: - Performance Tests
    
    func testRecipeGenerationPerformance() {
        // Given
        let recipeManager = RecipeManager()
        
        // When & Then
        measure {
            Task {
                await recipeManager.generateRecipe(
                    userPrompt: "Performance test recipe",
                    recipeName: nil,
                    cuisine: .italian,
                    difficulty: .medium,
                    dietaryRestrictions: [],
                    ingredients: nil,
                    maxTime: nil,
                    servings: 2
                )
            }
        }
    }
    

} 