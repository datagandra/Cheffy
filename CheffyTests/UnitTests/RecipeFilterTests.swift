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
    
    func testDietaryRestrictionFilters() async throws {
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
            dietaryRestrictions: filters.dietaryRestrictions,
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: 2
        )
        
        // Then
        guard let recipe = recipe else {
            XCTFail("Recipe should not be nil")
            return
        }
        XCTAssertTrue(recipe.dietaryNotes.contains(.vegetarian))
        XCTAssertTrue(recipe.dietaryNotes.contains(.glutenFree))
        XCTAssertEqual(recipe.dietaryNotes.count, 2)
    }
    
    func testCuisineFilter() async throws {
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
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
            XCTAssertEqual(recipe.cuisine, cuisine, "Recipe cuisine should match filter: \(cuisine.rawValue)")
        }
    }
    
    func testDifficultyFilter() async throws {
        // Given
        let testDifficulties: [Difficulty] = [.easy, .medium, .hard, .expert]
        
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
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
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
            case .expert:
                XCTAssertGreaterThanOrEqual(stepCount, 8, "Expert recipes should have 8 or more steps")
            }
        }
    }
    
    func testCookingTimeFilter() async throws {
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
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
            let totalTime = recipe.prepTime + recipe.cookTime
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe total time should be within \(maxTime) minutes")
            
            // Verify time distribution is reasonable
            XCTAssertGreaterThanOrEqual(recipe.prepTime, 5, "Prep time should be at least 5 minutes")
            XCTAssertGreaterThanOrEqual(recipe.cookTime, 10, "Cook time should be at least 10 minutes")
        }
    }
    
    func testServingsFilter() async throws {
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
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
            XCTAssertEqual(recipe.servings, servings, "Recipe servings should match filter: \(servings)")
        }
    }
    
    func testCombinedFilters() async throws {
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
            cuisine: filters.cuisine,
            difficulty: filters.difficulty,
            dietaryRestrictions: filters.dietaryRestrictions,
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings
        )
        
        // Then
        guard let recipe = recipe else {
            XCTFail("Recipe should not be nil")
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
    }
    
    // MARK: - Filter Edge Cases
    
    func testEmptyDietaryRestrictions() async throws {
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
            cuisine: filters.cuisine,
            difficulty: filters.difficulty,
            dietaryRestrictions: filters.dietaryRestrictions,
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: 2
        )
        
        // Then
        guard let recipe = recipe else {
            XCTFail("Recipe should not be nil")
            return
        }
        XCTAssertTrue(recipe.dietaryNotes.isEmpty, "Recipe should have no dietary restrictions when none specified")
    }
    
    func testExtremeCookingTime() async throws {
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
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
            let totalTime = recipe.prepTime + recipe.cookTime
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe should respect extreme time limit: \(maxTime)")
        }
    }
    
    func testLargeServings() async throws {
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
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
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
            cuisine: filters.cuisine,
            difficulty: filters.difficulty,
            dietaryRestrictions: filters.dietaryRestrictions,
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings
        )
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let generatedRecipe = self.recipeManager.generatedRecipe {
                // Verify the generated recipe matches our filters
                XCTAssertEqual(generatedRecipe.cuisine, filters.cuisine)
                XCTAssertEqual(generatedRecipe.difficulty, filters.difficulty)
                XCTAssertLessThanOrEqual(generatedRecipe.totalTime, filters.maxTime ?? Int.max)
                XCTAssertEqual(generatedRecipe.servings, filters.servings)
                
                // Check dietary restrictions
                for restriction in filters.dietaryRestrictions {
                    XCTAssertTrue(generatedRecipe.dietaryNotes.contains(restriction), "Recipe should contain \(restriction.rawValue)")
                }
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testFilterPerformance() async throws {
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
            cuisine: filters.cuisine,
            difficulty: filters.difficulty,
            dietaryRestrictions: filters.dietaryRestrictions,
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings
        )
        
        // Then
        XCTAssertNotNil(recipe)
        TestPerformanceMetrics.assertPerformance(operation: "Recipe generation with filters", maxDuration: 1.0)
    }
    
    func testMultipleFilterGenerations() async throws {
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
                cuisine: filters.cuisine,
                difficulty: filters.difficulty,
                dietaryRestrictions: filters.dietaryRestrictions,
                ingredients: nil,
                maxTime: filters.maxTime,
                servings: filters.servings
            )
            
            // Verify the recipe matches our filters
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
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
        }
        
        // Then
        TestPerformanceMetrics.assertPerformance(operation: "Multiple filter generations", maxDuration: 3.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testFilterValidationWithInvalidData() async throws {
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
            XCTAssertEqual(mockLLMService.error, "Mock LLM service failure")
        }
    }
    
    func testFilterTimeoutHandling() async throws {
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
        guard let recipe = recipe else {
            XCTFail("Recipe should not be nil")
            return
        }
        XCTAssertNotNil(recipe)
        XCTAssertGreaterThan(executionTime, 2.0, "Slow service should take at least 2 seconds")
    }
}
