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
            title: "Test Recipe",
            cuisine: .italian,
            difficulty: .easy,
            prepTime: 30,
            cookTime: 45,
            servings: 2,
            ingredients: [Ingredient(name: "Test Ingredient", amount: 1, unit: "cup")],
            steps: [
                CookingStep(stepNumber: 1, description: "Step 1"),
                CookingStep(stepNumber: 2, description: "Step 2")
            ]
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
        XCTAssertEqual(recipeManager.generatedRecipe?.title, expectedRecipe.title)
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
            Recipe(title: "Recipe 1", cuisine: .italian, difficulty: .easy, prepTime: 30, cookTime: 45, servings: 2, ingredients: [], steps: [CookingStep(stepNumber: 1, description: "Step 1")]),
            Recipe(title: "Recipe 2", cuisine: .italian, difficulty: .medium, prepTime: 45, cookTime: 60, servings: 4, ingredients: [], steps: [CookingStep(stepNumber: 1, description: "Step 1")])
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
            title: "Cached Recipe",
            cuisine: .italian,
            difficulty: .easy,
            prepTime: 30,
            cookTime: 45,
            servings: 2,
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            steps: [CookingStep(stepNumber: 1, description: "Step 1")]
        )
        
        // When
        recipeManager.cacheManager.cacheRecipe(recipe)
        
        // Then
        XCTAssertTrue(recipeManager.hasCachedRecipes())
        XCTAssertGreaterThan(recipeManager.getCachedRecipesCount(), 0)
    }
    
    func testLoadCachedRecipes() {
        // Given
        let recipe = Recipe(
            title: "Test Recipe",
            cuisine: .italian,
            difficulty: .easy,
            prepTime: 30,
            cookTime: 45,
            servings: 2,
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            steps: [CookingStep(stepNumber: 1, description: "Step 1")]
        )
        recipeManager.cacheManager.cacheRecipe(recipe)
        
        // When
        recipeManager.loadAllCachedRecipes()
        
        // Then
        XCTAssertFalse(recipeManager.cachedRecipes.isEmpty)
    }
    
    // MARK: - Favorites Tests
    
    func testAddToFavorites() {
        // Given
        let recipe = Recipe(
            title: "Favorite Recipe",
            cuisine: .italian,
            difficulty: .easy,
            prepTime: 30,
            cookTime: 45,
            servings: 2,
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            steps: [CookingStep(stepNumber: 1, description: "Step 1")]
        )
        
        // When
        recipeManager.saveToFavorites(recipe)
        
        // Then
        XCTAssertTrue(recipeManager.favorites.contains { $0.title == recipe.title })
    }
    
    func testRemoveFromFavorites() {
        // Given
        let recipe = Recipe(
            title: "Favorite Recipe",
            cuisine: .italian,
            difficulty: .easy,
            prepTime: 30,
            cookTime: 45,
            servings: 2,
            ingredients: [Ingredient(name: "Ingredient", amount: 1, unit: "cup")],
            steps: [CookingStep(stepNumber: 1, description: "Step 1")]
        )
        recipeManager.saveToFavorites(recipe)
        
        // When
        recipeManager.removeFromFavorites(recipe)
        
        // Then
        XCTAssertFalse(recipeManager.favorites.contains { $0.title == recipe.title })
    }
    
    // MARK: - Dietary Restrictions Tests
    
    func testFilterRecipesByDietaryRestrictions() {
        // Given
        let vegetarianRecipe = Recipe(
            title: "Vegetarian Pasta",
            cuisine: .italian,
            difficulty: .easy,
            prepTime: 30,
            cookTime: 45,
            servings: 2,
            ingredients: [Ingredient(name: "Pasta", amount: 1, unit: "cup")],
            steps: [CookingStep(stepNumber: 1, description: "Step 1")]
        )
        
        let meatRecipe = Recipe(
            title: "Beef Steak",
            cuisine: .american,
            difficulty: .medium,
            prepTime: 30,
            cookTime: 45,
            servings: 2,
            ingredients: [Ingredient(name: "Beef", amount: 1, unit: "pound")],
            steps: [CookingStep(stepNumber: 1, description: "Step 1")]
        )
        
        recipeManager.cacheManager.cacheRecipe(vegetarianRecipe)
        recipeManager.cacheManager.cacheRecipe(meatRecipe)
        
        // When
        let filteredRecipes = recipeManager.cacheManager.getCachedRecipes(cuisine: .italian).filter { recipe in
            recipe.dietaryNotes.contains(.vegetarian)
        }
        
        // Then
        XCTAssertEqual(filteredRecipes.count, 1)
        XCTAssertEqual(filteredRecipes.first?.title, "Vegetarian Pasta")
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
class MockOpenAIClient: OpenAIClientProtocol {
    var mockRecipe: Recipe?
    var mockPopularRecipes: [Recipe] = []
    var mockError: String?
    
    @Published var isLoading: Bool = false
    @Published var error: String?
    
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
    ) async -> Recipe? {
        if let error = mockError {
            self.error = error
            return nil
        }
        
        return mockRecipe
    }
    
    func generatePopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int?,
        servings: Int
    ) async -> [Recipe]? {
        if let error = mockError {
            self.error = error
            return nil
        }
        
        return mockPopularRecipes
    }
    
    func extractAllIngredientsAsText(from recipes: [Recipe]) -> String {
        return recipes.flatMap { $0.ingredients }.map { "\($0.amount) \($0.unit) \($0.name)" }.joined(separator: ", ")
    }
    
    func analyzeFilterCriteriaViolations(in recipes: [Recipe]) -> String {
        return "Mock analysis"
    }
    
    func parseRecipesFromJSONToText(_ jsonData: Data) -> String {
        return "Mock parsed data"
    }
} 