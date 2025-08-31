import XCTest
import Combine
import CloudKit
@testable import Cheffy

final class LLMCloudKitIntegrationTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    var mockLLMService: MockLLMService!
    var mockCloudKitService: MockCloudKitService!
    var mockUserAnalyticsService: MockUserAnalyticsService!
    var recipeManager: RecipeManager!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockLLMService = MockLLMService()
        mockCloudKitService = MockCloudKitService()
        mockUserAnalyticsService = MockUserAnalyticsService()
        recipeManager = RecipeManager()
    }
    
    override func tearDown() {
        cancellables = nil
        mockLLMService = nil
        mockCloudKitService = nil
        mockUserAnalyticsService = nil
        recipeManager = nil
        super.tearDown()
    }
    
    // MARK: - LLM + CloudKit Integration Tests
    
    func testRecipeGenerationAndCloudKitSync() async throws {
        // Given
        let filters = RecipeFilters(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [.vegetarian],
            maxTime: 30,
            servings: 2
        )
        
        // When - Generate recipe via LLM
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: "Quick vegetarian pasta",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then - Verify recipe matches filters
        guard let recipe = recipe else {
            XCTFail("Recipe is nil")
            return
        }
        XCTAssertEqual(recipe.cuisine, filters.cuisine)
        XCTAssertEqual(recipe.difficulty, filters.difficulty)
        XCTAssertLessThanOrEqual(recipe.totalTime, filters.maxTime ?? Int.max)
        XCTAssertEqual(recipe.servings, filters.servings)
        
        // Check dietary restrictions
        for restriction in filters.dietaryRestrictions {
            XCTAssertTrue(recipe.dietaryNotes.contains(restriction), "Recipe should contain \(restriction.rawValue)")
        }
        
        // When - Convert to UserRecipe and upload to CloudKit
        let userRecipe = UserRecipe(
            id: UUID().uuidString,
            title: recipe.title,
            ingredients: recipe.ingredients.map { "\($0.amount) \($0.unit) \($0.name)" },
            instructions: recipe.steps.map { $0.description },
            createdAt: Date(),
            authorID: "test-user-123",
            cuisine: recipe.cuisine.rawValue,
            difficulty: recipe.difficulty.rawValue,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            servings: recipe.servings,
            dietaryNotes: recipe.dietaryNotes.map { $0.rawValue },
            imageData: nil,
            syncStatus: .pending
        )
        
        try await mockCloudKitService.uploadUserRecipe(userRecipe)
        
        // Then - Verify CloudKit sync
        let uploadedRecipes = try await mockCloudKitService.fetchUserRecipes()
        XCTAssertTrue(uploadedRecipes.contains { $0.id == userRecipe.id })
        XCTAssertEqual(mockCloudKitService.syncStatus, .available)
    }
    
    func testUserAnalyticsIntegration() async throws {
        // Given
        let recipe = TestData.sampleRecipes[0]
        
        // When - Log various user actions
        try await mockUserAnalyticsService.logRecipeView(recipe)
        try await mockUserAnalyticsService.logRecipeSave(recipe)
        try await mockUserAnalyticsService.logSearch(query: "pasta")
        try await mockUserAnalyticsService.logFeatureUse(.recipeGeneration)
        
        // Then - Verify analytics events are tracked
        let analyticsEvents = mockUserAnalyticsService.getAnalyticsEvents()
        XCTAssertEqual(analyticsEvents["recipe_view"], 1)
        XCTAssertEqual(analyticsEvents["recipe_save"], 1)
        XCTAssertEqual(analyticsEvents["search"], 1)
        XCTAssertEqual(analyticsEvents["feature_recipeGeneration"], 1)
        
        // When - Sync to CloudKit
        try await mockUserAnalyticsService.syncStatsToCloudKit()
        
        // Then - Verify sync status
        XCTAssertEqual(mockUserAnalyticsService.syncStatus, .available)
    }
    
    func testEndToEndRecipeWorkflow() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Complete recipe workflow")
        let filters = RecipeFilters(
            cuisine: .indian,
            difficulty: .medium,
            dietaryRestrictions: [.vegetarian, .glutenFree],
            maxTime: 45,
            servings: 4
        )
        
        // When - Complete workflow
        await recipeManager.generateRecipe(
            userPrompt: "Traditional Indian vegetarian curry",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Wait for recipe generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let generatedRecipe = self.recipeManager.generatedRecipe {
                // Verify recipe generation
                XCTAssertEqual(generatedRecipe.cuisine, filters.cuisine)
                XCTAssertEqual(generatedRecipe.difficulty, filters.difficulty)
                XCTAssertLessThanOrEqual(generatedRecipe.totalTime, filters.maxTime ?? Int.max)
                XCTAssertEqual(generatedRecipe.servings, filters.servings)
                
                // Check dietary restrictions
                for restriction in filters.dietaryRestrictions {
                    XCTAssertTrue(generatedRecipe.dietaryNotes.contains(restriction), "Recipe should contain \(restriction.rawValue)")
                }
                
                // Simulate user interactions
                Task {
                    do {
                        // Log analytics
                        try await self.mockUserAnalyticsService.logRecipeView(generatedRecipe)
                        try await self.mockUserAnalyticsService.logRecipeSave(generatedRecipe)
                        
                        // Upload to CloudKit
                        let userRecipe = UserRecipe(
                            id: UUID().uuidString,
                            title: generatedRecipe.title,
                            ingredients: generatedRecipe.ingredients.map { "\($0.amount) \($0.unit) \($0.name)" },
                            instructions: generatedRecipe.steps.map { $0.description },
                            createdAt: Date(),
                            authorID: "test-user-123",
                            cuisine: generatedRecipe.cuisine.rawValue,
                            difficulty: generatedRecipe.difficulty.rawValue,
                            prepTime: generatedRecipe.prepTime,
                            cookTime: generatedRecipe.cookTime,
                            servings: generatedRecipe.servings,
                            dietaryNotes: generatedRecipe.dietaryNotes.map { $0.rawValue },
                            imageData: nil,
                            syncStatus: .pending
                        )
                        
                        try await self.mockCloudKitService.uploadUserRecipe(userRecipe)
                        
                        // Verify complete workflow
                        let uploadedRecipes = try await self.mockCloudKitService.fetchUserRecipes()
                        XCTAssertTrue(uploadedRecipes.contains { $0.id == userRecipe.id })
                        
                        let analyticsEvents = self.mockUserAnalyticsService.getAnalyticsEvents()
                        XCTAssertEqual(analyticsEvents["recipe_view"], 1)
                        XCTAssertEqual(analyticsEvents["recipe_save"], 1)
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Workflow failed: \(error)")
                    }
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testLLMFailureWithCloudKitFallback() async throws {
        // Given
        mockLLMService.configure(shouldFail: true)
        let filters = RecipeFilters(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [.vegetarian]
        )
        
        // When - Try to generate recipe (should fail)
        do {
            let _ = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: filters.cuisine ?? .italian,
                difficulty: filters.difficulty ?? .medium,
                dietaryRestrictions: filters.dietaryRestrictions ?? [],
                ingredients: nil,
                maxTime: filters.maxTime,
                servings: filters.servings ?? 2
            )
            XCTFail("Should have thrown an error")
        } catch {
            // Then - Verify error is handled
            XCTAssertNotNil(error)
            XCTAssertEqual(mockLLMService.error?.localizedDescription, "Mock LLM service failure")
            
            // Verify CloudKit service remains available
            XCTAssertEqual(mockCloudKitService.syncStatus, .available)
            
            // Verify analytics service can still log errors
            try await mockUserAnalyticsService.logFeatureUse(.recipeGeneration)
            let analyticsEvents = mockUserAnalyticsService.getAnalyticsEvents()
            XCTAssertEqual(analyticsEvents["feature_recipeGeneration"], 1)
        }
    }
    
    func testCloudKitSyncFailureWithLocalFallback() async throws {
        // Given
        mockCloudKitService.configure(shouldFail: true)
        let recipe = TestData.sampleRecipes[0]
        
        // When - Try to upload recipe (should fail)
        let userRecipe = UserRecipe(
            id: UUID().uuidString,
            title: recipe.title,
            ingredients: recipe.ingredients.map { "\($0.amount) \($0.unit) \($0.name)" },
            instructions: recipe.steps.map { $0.description },
            createdAt: Date(),
            authorID: "test-user-123",
            cuisine: recipe.cuisine.rawValue,
            difficulty: recipe.difficulty.rawValue,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            servings: recipe.servings,
            dietaryNotes: recipe.dietaryNotes.map { $0.rawValue },
            imageData: nil,
            syncStatus: .pending
        )
        
        do {
            try await mockCloudKitService.uploadUserRecipe(userRecipe)
            XCTFail("Should have thrown an error")
        } catch {
            // Then - Verify error is handled
            XCTAssertNotNil(error)
            
            // Verify local analytics still work
            try await mockUserAnalyticsService.logRecipeView(recipe)
            let analyticsEvents = mockUserAnalyticsService.getAnalyticsEvents()
            XCTAssertEqual(analyticsEvents["recipe_view"], 1)
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testConcurrentRecipeGeneration() async throws {
        // Given
        let filterCombinations = [
            RecipeFilters(cuisine: .italian, difficulty: .easy, dietaryRestrictions: [.vegetarian]),
            RecipeFilters(cuisine: .indian, difficulty: .medium, dietaryRestrictions: [.vegan]),
            RecipeFilters(cuisine: .chinese, difficulty: .hard, dietaryRestrictions: [.glutenFree])
        ]
        
        // When - Generate recipes concurrently
        TestPerformanceMetrics.startMeasuring()
        
        let recipes = try await withThrowingTaskGroup(of: Recipe.self) { group in
            for filters in filterCombinations {
                group.addTask {
                    let recipe = try await self.mockLLMService.generateRecipe(
                        userPrompt: nil,
                        recipeName: nil,
                        cuisine: filters.cuisine ?? .italian,
                        difficulty: filters.difficulty ?? .medium,
                        dietaryRestrictions: filters.dietaryRestrictions ?? [],
                        ingredients: nil,
                        maxTime: filters.maxTime,
                        servings: filters.servings ?? 2
                    )
                    guard let recipe = recipe else {
                        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recipe generation failed"])
                    }
                    return recipe
                }
            }
            
            var results: [Recipe] = []
            for try await recipe in group {
                results.append(recipe)
            }
            return results
        }
        
        // Then - Verify all recipes were generated
        XCTAssertEqual(recipes.count, 3)
        
        // Verify performance
        TestPerformanceMetrics.assertPerformance(operation: "Concurrent recipe generation", maxTime: 4.0)
        
        // Verify analytics for all recipes
        for recipe in recipes {
            try await mockUserAnalyticsService.logRecipeView(recipe)
        }
        
        let analyticsEvents = mockUserAnalyticsService.getAnalyticsEvents()
        XCTAssertEqual(analyticsEvents["recipe_view"], 3)
    }
    
    func testBulkCloudKitOperations() async throws {
        // Given
        let recipes = TestData.sampleRecipes
        let userRecipes = recipes.map { recipe in
            UserRecipe(
                id: UUID().uuidString,
                title: recipe.title,
                ingredients: recipe.ingredients.map { "\($0.amount) \($0.unit) \($0.name)" },
                instructions: recipe.steps.map { $0.description },
                createdAt: Date(),
                authorID: "test-user-123",
                cuisine: recipe.cuisine.rawValue,
                difficulty: recipe.difficulty.rawValue,
                prepTime: recipe.prepTime,
                cookTime: recipe.cookTime,
                servings: recipe.servings,
                dietaryNotes: recipe.dietaryNotes.map { $0.rawValue },
                imageData: nil,
                syncStatus: .pending
            )
        }
        
        // When - Upload all recipes concurrently
        TestPerformanceMetrics.startMeasuring()
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for userRecipe in userRecipes {
                group.addTask {
                    try await self.mockCloudKitService.uploadUserRecipe(userRecipe)
                }
            }
            
            try await group.waitForAll()
        }
        
        // Then - Verify all recipes were uploaded
        let uploadedRecipes = try await mockCloudKitService.fetchUserRecipes()
        XCTAssertEqual(uploadedRecipes.count, recipes.count)
        
        // Verify performance
        TestPerformanceMetrics.assertPerformance(operation: "Bulk CloudKit upload", maxTime: 5.0)
    }
    
    // MARK: - Data Consistency Tests
    
    func testRecipeDataConsistencyAcrossServices() async throws {
        // Given
        let filters = RecipeFilters(
            cuisine: .japanese,
            difficulty: .medium,
            dietaryRestrictions: [.vegetarian]
        )
        
        // When - Generate recipe
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: nil,
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        guard let recipe = recipe else {
            XCTFail("Recipe is nil")
            return
        }
        
        // Convert to UserRecipe
        let userRecipe = UserRecipe(
            id: UUID().uuidString,
            title: recipe.title,
            ingredients: recipe.ingredients.map { "\($0.amount) \($0.unit) \($0.name)" },
            instructions: recipe.steps.map { $0.description },
            createdAt: Date(),
            authorID: "test-user-123",
            cuisine: recipe.cuisine.rawValue,
            difficulty: recipe.difficulty.rawValue,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            servings: recipe.servings,
            dietaryNotes: recipe.dietaryNotes.map { $0.rawValue },
            imageData: nil,
            syncStatus: .pending
        )
        
        // Upload to CloudKit
        try await mockCloudKitService.uploadUserRecipe(userRecipe)
        
        // Fetch back from CloudKit
        let uploadedRecipes = try await mockCloudKitService.fetchUserRecipes()
        let fetchedRecipe = uploadedRecipes.first { $0.id == userRecipe.id }
        
        // Then - Verify data consistency
        XCTAssertNotNil(fetchedRecipe)
        XCTAssertEqual(fetchedRecipe?.title, recipe.title)
        XCTAssertEqual(fetchedRecipe?.cuisine, recipe.cuisine.rawValue)
        XCTAssertEqual(fetchedRecipe?.difficulty, recipe.difficulty.rawValue)
        XCTAssertEqual(fetchedRecipe?.prepTime, recipe.prepTime)
        XCTAssertEqual(fetchedRecipe?.cookTime, recipe.cookTime)
        XCTAssertEqual(fetchedRecipe?.servings, recipe.servings)
        XCTAssertEqual(fetchedRecipe?.dietaryNotes, recipe.dietaryNotes.map { $0.rawValue })
    }
    
    func testAnalyticsDataConsistency() async throws {
        // Given
        let recipe = TestData.sampleRecipes[0]
        
        // When - Log multiple events
        try await mockUserAnalyticsService.logRecipeView(recipe)
        try await mockUserAnalyticsService.logRecipeSave(recipe)
        try await mockUserAnalyticsService.logSearch(query: "pasta")
        
        // Sync to CloudKit
        try await mockUserAnalyticsService.syncStatsToCloudKit()
        
        // Get aggregated stats
        let aggregatedStats = try await mockUserAnalyticsService.getAggregatedStats()
        
        // Then - Verify data consistency
        XCTAssertEqual(aggregatedStats["totalEvents"] as? Int, 3)
        
        let eventBreakdown = aggregatedStats["eventBreakdown"] as? [String: Int]
        XCTAssertEqual(eventBreakdown?["recipe_view"], 1)
        XCTAssertEqual(eventBreakdown?["recipe_save"], 1)
        XCTAssertEqual(eventBreakdown?["search"], 1)
    }
    
    // MARK: - Offline Mode Tests
    
    func testOfflineModeWithLocalCaching() async throws {
        // Given
        let recipe = TestData.sampleRecipes[0]
        
        // When - Log analytics while offline (CloudKit unavailable)
        mockCloudKitService.configure(shouldFail: true)
        
        try await mockUserAnalyticsService.logRecipeView(recipe)
        try await mockUserAnalyticsService.logRecipeSave(recipe)
        
        // Then - Verify local analytics still work
        let analyticsEvents = mockUserAnalyticsService.getAnalyticsEvents()
        XCTAssertEqual(analyticsEvents["recipe_view"], 1)
        XCTAssertEqual(analyticsEvents["recipe_save"], 1)
        
        // When - CloudKit becomes available again
        mockCloudKitService.configure(shouldFail: false)
        
        // Sync to CloudKit
        try await mockUserAnalyticsService.syncStatsToCloudKit()
        
        // Then - Verify sync completed
        XCTAssertEqual(mockUserAnalyticsService.syncStatus, .available)
    }
    
    // MARK: - Stress Tests
    
    func testHighLoadRecipeGeneration() async throws {
        // Given
        let numberOfRecipes = 10
        let filters = RecipeFilters(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [.vegetarian]
        )
        
        // When - Generate many recipes rapidly
        TestPerformanceMetrics.startMeasuring()
        
        let recipes = try await withThrowingTaskGroup(of: Recipe.self) { group in
            for _ in 0..<numberOfRecipes {
                group.addTask {
                    let recipe = try await self.mockLLMService.generateRecipe(
                        userPrompt: nil,
                        recipeName: nil,
                        cuisine: filters.cuisine ?? .italian,
                        difficulty: filters.difficulty ?? .medium,
                        dietaryRestrictions: filters.dietaryRestrictions ?? [],
                        ingredients: nil,
                        maxTime: filters.maxTime,
                        servings: filters.servings ?? 2
                    )
                    guard let recipe = recipe else {
                        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recipe generation failed"])
                    }
                    return recipe
                }
            }
            
            var results: [Recipe] = []
            for try await recipe in group {
                results.append(recipe)
            }
            return results
        }
        
        // Then - Verify all recipes generated
        XCTAssertEqual(recipes.count, numberOfRecipes)
        
        // Verify performance under load
        TestPerformanceMetrics.assertPerformance(operation: "High load recipe generation", maxTime: 8.0)
        
        // Verify analytics tracking under load
        for recipe in recipes {
            try await mockUserAnalyticsService.logRecipeView(recipe)
        }
        
        let analyticsEvents = mockUserAnalyticsService.getAnalyticsEvents()
        XCTAssertEqual(analyticsEvents["recipe_view"], numberOfRecipes)
    }
}
