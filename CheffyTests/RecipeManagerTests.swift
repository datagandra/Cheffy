import XCTest
@testable import Cheffy

final class RecipeManagerTests: XCTestCase {
    var recipeManager: RecipeManager!
    var mockOpenAIClient: MockOpenAIClient!
    
    override func setUp() {
        super.setUp()
        mockOpenAIClient = MockOpenAIClient()
        recipeManager = RecipeManager()
        // Inject mock client
        recipeManager.openAIClient = mockOpenAIClient
    }
    
    override func tearDown() {
        recipeManager = nil
        mockOpenAIClient = nil
        super.tearDown()
    }
    
    // MARK: - Recipe Generation Tests
    
    func testGenerateRecipeSuccess() async {
        // Given
        let expectedRecipe = Recipe(
            name: "Test Recipe",
            ingredients: [Ingredient(name: "Test Ingredient", amount: 1, unit: "cup")],
            instructions: ["Step 1", "Step 2"],
            cuisine: .italian,
            difficulty: .easy,
            servings: 2,
            prepTime: 30,
            cookTime: 45
        )
        mockOpenAIClient.mockRecipe = expectedRecipe
        
        // When
        await recipeManager.generateRecipe(
            userPrompt: "Test prompt",
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            servings: 2
        )
        
        // Then
        XCTAssertNotNil(recipeManager.generatedRecipe)
        XCTAssertEqual(recipeManager.generatedRecipe?.name, expectedRecipe.name)
        XCTAssertFalse(recipeManager.isLoading)
        XCTAssertNil(recipeManager.error)
    }
    
    func testGenerateRecipeFailure() async {
        // Given
        let expectedError = "API Error"
        mockOpenAIClient.mockError = expectedError
        
        // When
        await recipeManager.generateRecipe(
            userPrompt: "Test prompt",
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            servings: 2
        )
        
        // Then
        XCTAssertNil(recipeManager.generatedRecipe)
        XCTAssertEqual(recipeManager.error, expectedError)
        XCTAssertFalse(recipeManager.isLoading)
    }
    
    func testGeneratePopularRecipesSuccess() async {
        // Given
        let expectedRecipes = [
            Recipe(name: "Recipe 1", ingredients: [], instructions: [], cuisine: .italian, difficulty: .easy, servings: 2, prepTime: 30, cookTime: 45),
            Recipe(name: "Recipe 2", ingredients: [], instructions: [], cuisine: .italian, difficulty: .medium, servings: 4, prepTime: 45, cookTime: 60)
        ]
        mockOpenAIClient.mockPopularRecipes = expectedRecipes
        
        // When
        await recipeManager.generatePopularRecipes(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            servings: 2
        )
        
        // Then
        XCTAssertEqual(recipeManager.popularRecipes.count, expectedRecipes.count)
        XCTAssertFalse(recipeManager.isLoading)
        XCTAssertNil(recipeManager.error)
    }
    
    // MARK: - Caching Tests
    
    func testCacheRecipe() {
        // Given
        let recipe = Recipe(
            name: "Cached Recipe",
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            instructions: ["Step 1"],
            cuisine: .italian,
            difficulty: .easy,
            servings: 2,
            prepTime: 30,
            cookTime: 45
        )
        
        // When
        recipeManager.cacheRecipe(recipe)
        
        // Then
        XCTAssertTrue(recipeManager.hasCachedRecipes())
        XCTAssertGreaterThan(recipeManager.getCachedRecipesCount(), 0)
    }
    
    func testLoadCachedRecipes() {
        // Given
        let recipe = Recipe(
            name: "Test Recipe",
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            instructions: ["Step 1"],
            cuisine: .italian,
            difficulty: .easy,
            servings: 2,
            prepTime: 30,
            cookTime: 45
        )
        recipeManager.cacheRecipe(recipe)
        
        // When
        recipeManager.loadCachedData()
        
        // Then
        XCTAssertFalse(recipeManager.cachedRecipes.isEmpty)
    }
    
    // MARK: - Favorites Tests
    
    func testAddToFavorites() {
        // Given
        let recipe = Recipe(
            name: "Favorite Recipe",
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            instructions: ["Step 1"],
            cuisine: .italian,
            difficulty: .easy,
            servings: 2,
            prepTime: 30,
            cookTime: 45
        )
        
        // When
        recipeManager.addToFavorites(recipe)
        
        // Then
        XCTAssertTrue(recipeManager.favorites.contains { $0.name == recipe.name })
    }
    
    func testRemoveFromFavorites() {
        // Given
        let recipe = Recipe(
            name: "Favorite Recipe",
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            instructions: ["Step 1"],
            cuisine: .italian,
            difficulty: .easy,
            servings: 2,
            prepTime: 30,
            cookTime: 45
        )
        recipeManager.addToFavorites(recipe)
        
        // When
        recipeManager.removeFromFavorites(recipe)
        
        // Then
        XCTAssertFalse(recipeManager.favorites.contains { $0.name == recipe.name })
    }
    
    // MARK: - Dietary Restrictions Tests
    
    func testFilterRecipesByDietaryRestrictions() {
        // Given
        let vegetarianRecipe = Recipe(
            name: "Vegetarian Pasta",
            ingredients: [Ingredient(name: "Pasta", amount: 1, unit: "cup")],
            instructions: ["Step 1"],
            cuisine: .italian,
            difficulty: .easy,
            servings: 2,
            prepTime: 30,
            cookTime: 45
        )
        
        let meatRecipe = Recipe(
            name: "Beef Steak",
            ingredients: [Ingredient(name: "Beef", amount: 1, unit: "pound")],
            instructions: ["Step 1"],
            cuisine: .american,
            difficulty: .medium,
            servings: 2,
            prepTime: 30,
            cookTime: 45
        )
        
        recipeManager.cacheRecipe(vegetarianRecipe)
        recipeManager.cacheRecipe(meatRecipe)
        
        // When
        let filteredRecipes = recipeManager.filterRecipesByDietaryRestrictions(
            [vegetarianRecipe, meatRecipe],
            restrictions: [.vegetarian]
        )
        
        // Then
        XCTAssertEqual(filteredRecipes.count, 1)
        XCTAssertEqual(filteredRecipes.first?.name, "Vegetarian Pasta")
    }
    
    // MARK: - Performance Tests
    
    func testRecipeGenerationPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Recipe generation")
            
            Task {
                await recipeManager.generateRecipe(
                    userPrompt: "Test performance",
                    cuisine: .italian,
                    difficulty: .easy,
                    dietaryRestrictions: [],
                    servings: 2
                )
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
}

// MARK: - Mock OpenAIClient
class MockOpenAIClient: OpenAIClient {
    var mockRecipe: Recipe?
    var mockPopularRecipes: [Recipe] = []
    var mockError: String?
    
    override func generateRecipe(
        userPrompt: String?,
        recipeName: String?,
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        ingredients: [String]?,
        maxTime: Int?,
        servings: Int
    ) async throws -> Recipe {
        if let error = mockError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        guard let recipe = mockRecipe else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock recipe provided"])
        }
        
        return recipe
    }
    
    override func generatePopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        servings: Int
    ) async throws -> [Recipe] {
        if let error = mockError {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        return mockPopularRecipes
    }
} 