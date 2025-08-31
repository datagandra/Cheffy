import XCTest
import Combine
@testable import Cheffy

final class RecipeFilterTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    var mockLLMService: MockLLMService!
    var recipeManager: RecipeManager!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockLLMService = MockLLMService()
        recipeManager = RecipeManager()
    }
    
    override func tearDown() {
        cancellables = nil
        mockLLMService = nil
        recipeManager = nil
        super.tearDown()
    }
    
    // MARK: - Filter Validation Tests
    
    func testDietaryRestrictionFilters() async {
        // Given
        let filters = RecipeFilters(
            dietaryRestrictions: [.vegetarian, .glutenFree],
            maxTime: 30
        )
        
        // When
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: nil,
            recipeName: nil,
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: 2
        )
        
        // Then
        XCTAssertTrue(recipe.dietaryNotes.contains(.vegetarian))
        XCTAssertTrue(recipe.dietaryNotes.contains(.glutenFree))
        XCTAssertEqual(recipe.dietaryNotes.count, 2)
    }
    
    func testCuisineFilter() async {
        // Given
        let testCuisines: [Cuisine] = [.italian, .indian, .chinese, .mexican, .japanese]
        
        for cuisine in testCuisines {
            // When
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: cuisine,
                difficulty: .medium,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: nil,
                servings: 2
            )
            
            // Then
            XCTAssertEqual(recipe.cuisine, cuisine, "Recipe cuisine should match filter: \(cuisine.rawValue)")
        }
    }
    
    func testDifficultyFilter() async {
        // Given
        let testDifficulties: [Difficulty] = [.easy, .medium, .hard]
        
        for difficulty in testDifficulties {
            // When
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: .italian,
                difficulty: difficulty,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: nil,
                servings: 2
            )
            
            // Then
            XCTAssertEqual(recipe.difficulty, difficulty, "Recipe difficulty should match filter: \(difficulty.rawValue)")
            
            // Verify step complexity matches difficulty
            let stepCount = recipe.steps.count
            switch difficulty {
            case .easy:
                XCTAssertLessThanOrEqual(stepCount, 4, "Easy recipes should have 4 or fewer steps")
            case .medium:
                XCTAssertGreaterThanOrEqual(stepCount, 4, "Medium recipes should have 4 or more steps")
                XCTAssertLessThanOrEqual(stepCount, 6, "Medium recipes should have 6 or fewer steps")
            case .hard:
                XCTAssertGreaterThanOrEqual(stepCount, 6, "Hard recipes should have 6 or more steps")
            }
        }
    }
    
    func testCookingTimeFilter() async {
        // Given
        let testTimes = [15, 30, 45, 60]
        
        for maxTime in testTimes {
            // When
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: .italian,
                difficulty: .medium,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: maxTime,
                servings: 2
            )
            
            // Then
            let totalTime = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0)
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe total time should be within \(maxTime) minutes")
            
            // Verify time distribution is reasonable
            XCTAssertGreaterThanOrEqual(recipe.prepTime ?? 0, 5, "Prep time should be at least 5 minutes")
            XCTAssertGreaterThanOrEqual(recipe.cookTime ?? 0, 10, "Cook time should be at least 10 minutes")
        }
    }
    
    func testServingsFilter() async {
        // Given
        let testServings = [1, 2, 4, 6, 8]
        
        for servings in testServings {
            // When
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: .italian,
                difficulty: .medium,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: nil,
                servings: servings
            )
            
            // Then
            XCTAssertEqual(recipe.servings, servings, "Recipe servings should match filter: \(servings)")
        }
    }
    
    func testCombinedFilters() async {
        // Given
        let filters = RecipeFilters(
            cuisine: .indian,
            difficulty: .easy,
            dietaryRestrictions: [.vegetarian, .vegan],
            maxTime: 30,
            servings: 4
        )
        
        // When
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
        
        // Then
        assertRecipeMatchesFilters(recipe, filters: filters)
    }
    
    // MARK: - Filter Edge Cases
    
    func testEmptyDietaryRestrictions() async {
        // Given
        let filters = RecipeFilters(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            maxTime: 30
        )
        
        // When
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: nil,
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: 2
        )
        
        // Then
        XCTAssertTrue(recipe.dietaryNotes.isEmpty, "Recipe should have no dietary restrictions when none specified")
    }
    
    func testExtremeCookingTime() async {
        // Given
        let extremeTimes = [5, 120, 180] // Very short and very long
        
        for maxTime in extremeTimes {
            // When
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: .italian,
                difficulty: .medium,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: maxTime,
                servings: 2
            )
            
            // Then
            let totalTime = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0)
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe should respect extreme time limit: \(maxTime)")
        }
    }
    
    func testLargeServings() async {
        // Given
        let largeServings = [10, 20, 50]
        
        for servings in largeServings {
            // When
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: .italian,
                difficulty: .medium,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: nil,
                servings: servings
            )
            
            // Then
            XCTAssertEqual(recipe.servings, servings, "Recipe should handle large servings: \(servings)")
        }
    }
    
    // MARK: - Filter Integration Tests
    
    func testFilterIntegrationWithRecipeManager() async {
        // Given
        let expectation = XCTestExpectation(description: "Recipe generation with filters")
        let filters = RecipeFilters(
            cuisine: .japanese,
            difficulty: .hard,
            dietaryRestrictions: [.vegetarian],
            maxTime: 60,
            servings: 6
        )
        
        // When
        await recipeManager.generateRecipe(
            userPrompt: "Traditional Japanese vegetarian dish",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let generatedRecipe = self.recipeManager.generatedRecipe {
                self.assertRecipeMatchesFilters(generatedRecipe, filters: filters)
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testFilterPersistence() {
        // Given
        let filters = RecipeFilters(
            cuisine: .mexican,
            difficulty: .medium,
            dietaryRestrictions: [.glutenFree, .dairyFree],
            maxTime: 45,
            servings: 4
        )
        
        // When
        recipeManager.currentFilters = filters
        
        // Then
        XCTAssertEqual(recipeManager.currentFilters?.cuisine, filters.cuisine)
        XCTAssertEqual(recipeManager.currentFilters?.difficulty, filters.difficulty)
        XCTAssertEqual(recipeManager.currentFilters?.dietaryRestrictions, filters.dietaryRestrictions)
        XCTAssertEqual(recipeManager.currentFilters?.maxTime, filters.maxTime)
        XCTAssertEqual(recipeManager.currentFilters?.servings, filters.servings)
    }
    
    // MARK: - Performance Tests
    
    func testFilterPerformance() async {
        // Given
        let filters = RecipeFilters(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [.vegetarian],
            maxTime: 30,
            servings: 2
        )
        
        // When
        TestPerformanceMetrics.startMeasuring()
        
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
        
        // Then
        XCTAssertNotNil(recipe)
        TestPerformanceMetrics.assertPerformance(operation: "Recipe generation with filters", maxTime: 1.0)
    }
    
    func testMultipleFilterGenerations() async {
        // Given
        let filterCombinations = [
            RecipeFilters(cuisine: .italian, difficulty: .easy, dietaryRestrictions: [.vegetarian]),
            RecipeFilters(cuisine: .indian, difficulty: .medium, dietaryRestrictions: [.vegan]),
            RecipeFilters(cuisine: .chinese, difficulty: .hard, dietaryRestrictions: [.glutenFree])
        ]
        
        // When
        TestPerformanceMetrics.startMeasuring()
        
        for filters in filterCombinations {
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
            
            assertRecipeMatchesFilters(recipe, filters: filters)
        }
        
        // Then
        TestPerformanceMetrics.assertPerformance(operation: "Multiple filter generations", maxTime: 3.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testFilterValidationWithInvalidData() async {
        // Given
        mockLLMService.configure(shouldFail: true)
        
        // When & Then
        do {
            let _ = try await mockLLMService.generateRecipe(
                userPrompt: nil,
                recipeName: nil,
                cuisine: .italian,
                difficulty: .easy,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: nil,
                servings: 2
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error)
            XCTAssertEqual(mockLLMService.error?.localizedDescription, "Mock LLM service failure")
        }
    }
    
    func testFilterTimeoutHandling() async {
        // Given
        mockLLMService.configure(shouldBeSlow: true)
        
        // When
        let startTime = Date()
        
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: nil,
            recipeName: nil,
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            ingredients: nil,
            maxTime: nil,
            servings: 2
        )
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertNotNil(recipe)
        XCTAssertGreaterThan(executionTime, 2.0, "Slow service should take at least 2 seconds")
    }
}
