import XCTest
import Foundation
@testable import Cheffy

final class QuickRecipeTests: XCTestCase {
    
    var recipeManager: RecipeManager!
    var mockOpenAIClient: MockOpenAIClient!
    
    override func setUpWithError() throws {
        super.setUp()
        recipeManager = RecipeManager()
        mockOpenAIClient = MockOpenAIClient()
        recipeManager.openAIClient = mockOpenAIClient
    }
    
    override func tearDownWithError() throws {
        recipeManager = nil
        mockOpenAIClient = nil
        super.tearDown()
    }
    
    // MARK: - Cooking Time Filter Tests
    
    func testCookingTimeFilterUnder20Minutes() {
        let filter = CookingTimeFilter.under20min
        
        XCTAssertEqual(filter.maxTotalTime, 20)
        XCTAssertTrue(filter.isQuickRecipe)
        XCTAssertEqual(filter.quickRecipeBadge, "⚡ Quick")
    }
    
    func testCookingTimeFilterUnder30Minutes() {
        let filter = CookingTimeFilter.under30min
        
        XCTAssertEqual(filter.maxTotalTime, 30)
        XCTAssertTrue(filter.isQuickRecipe)
        XCTAssertEqual(filter.quickRecipeBadge, "⚡ Fast")
    }
    
    func testCookingTimeFilterNonQuickRecipes() {
        let filter = CookingTimeFilter.under45min
        
        XCTAssertEqual(filter.maxTotalTime, 45)
        XCTAssertFalse(filter.isQuickRecipe)
        XCTAssertEqual(filter.quickRecipeBadge, "")
    }
    
    // MARK: - User Persona Tests
    
    func testUserPersonaSchoolKid() {
        let persona = UserPersona.schoolKid
        
        XCTAssertEqual(persona.rawValue, "School-going Kid")
        XCTAssertTrue(persona.description.contains("healthy"))
        XCTAssertTrue(persona.description.contains("simple"))
        XCTAssertTrue(persona.description.contains("fun"))
        XCTAssertTrue(persona.description.contains("fast"))
        XCTAssertTrue(persona.nutritionFocus.contains("healthy"))
        XCTAssertTrue(persona.safetyNotes.contains("child-safe"))
    }
    
    func testUserPersonaOfficeAdult() {
        let persona = UserPersona.officeAdult
        
        XCTAssertEqual(persona.rawValue, "Office-going Adult")
        XCTAssertTrue(persona.description.contains("energy-packed"))
        XCTAssertTrue(persona.description.contains("balanced"))
        XCTAssertTrue(persona.description.contains("quick"))
        XCTAssertTrue(persona.nutritionFocus.contains("energy-sustaining"))
        XCTAssertTrue(persona.safetyNotes.contains("busy schedules"))
    }
    
    func testUserPersonaGeneral() {
        let persona = UserPersona.general
        
        XCTAssertEqual(persona.rawValue, "General")
        XCTAssertTrue(persona.description.contains("General recipes"))
        XCTAssertTrue(persona.nutritionFocus.contains("general health"))
        XCTAssertTrue(persona.safetyNotes.contains("Standard safety"))
    }
    
    // MARK: - Quick Recipe Generation Tests
    
    func testGenerateQuickRecipesWithSchoolKidPersona() async throws {
        // Given
        let cuisine = Cuisine.italian
        let difficulty = Difficulty.easy
        let dietaryRestrictions: [DietaryNote] = [.vegetarian]
        let maxTime = 20
        let servings = 4
        let userPersona = UserPersona.schoolKid
        
        // Mock successful response
        let mockRecipes = [
            createMockQuickRecipe(name: "Quick Pasta", prepTime: 5, cookTime: 12),
            createMockQuickRecipe(name: "Fast Pizza", prepTime: 8, cookTime: 15)
        ]
        mockOpenAIClient.mockQuickRecipes = mockRecipes
        
        // When
        let result = await recipeManager.generateQuickRecipes(
            cuisine: cuisine,
            difficulty: difficulty,
            dietaryRestrictions: dietaryRestrictions,
            maxTime: maxTime,
            servings: servings,
            userPersona: userPersona
        )
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2)
        
        // Verify all recipes meet time constraints
        for recipe in result ?? [] {
            let totalTime = recipe.prepTime + recipe.cookTime
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe '\(recipe.title)' exceeds time limit")
        }
        
        // Verify all recipes are vegetarian
        for recipe in result ?? [] {
            XCTAssertTrue(recipe.dietaryNotes.contains(.vegetarian), "Recipe '\(recipe.title)' is not vegetarian")
        }
    }
    
    func testGenerateQuickRecipesWithOfficeAdultPersona() async throws {
        // Given
        let cuisine = Cuisine.indian
        let difficulty = Difficulty.medium
        let dietaryRestrictions: [DietaryNote] = [.nonVegetarian]
        let maxTime = 30
        let servings = 2
        let userPersona = UserPersona.officeAdult
        
        // Mock successful response
        let mockRecipes = [
            createMockQuickRecipe(name: "Quick Chicken Curry", prepTime: 10, cookTime: 18),
            createMockQuickRecipe(name: "Fast Fish Fry", prepTime: 8, cookTime: 20)
        ]
        mockOpenAIClient.mockQuickRecipes = mockRecipes
        
        // When
        let result = await recipeManager.generateQuickRecipes(
            cuisine: cuisine,
            difficulty: difficulty,
            dietaryRestrictions: dietaryRestrictions,
            maxTime: maxTime,
            servings: servings,
            userPersona: userPersona
        )
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2)
        
        // Verify all recipes meet time constraints
        for recipe in result ?? [] {
            let totalTime = recipe.prepTime + recipe.cookTime
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe '\(recipe.title)' exceeds time limit")
        }
        
        // Verify all recipes are non-vegetarian
        for recipe in result ?? [] {
            XCTAssertTrue(recipe.dietaryNotes.contains(.nonVegetarian), "Recipe '\(recipe.title)' is not non-vegetarian")
        }
    }
    
    func testGenerateQuickRecipesTimeConstraintEnforcement() async throws {
        // Given
        let maxTime = 15
        let userPersona = UserPersona.general
        
        // Mock response with some recipes exceeding time limit
        let mockRecipes = [
            createMockQuickRecipe(name: "Quick Salad", prepTime: 5, cookTime: 0), // 5 min total
            createMockQuickRecipe(name: "Slow Roast", prepTime: 10, cookTime: 120), // 130 min total - should be filtered out
            createMockQuickRecipe(name: "Fast Stir Fry", prepTime: 8, cookTime: 6) // 14 min total
        ]
        mockOpenAIClient.mockQuickRecipes = mockRecipes
        
        // When
        let result = await recipeManager.generateQuickRecipes(
            cuisine: .chinese,
            difficulty: .easy,
            dietaryRestrictions: [],
            maxTime: maxTime,
            servings: 2,
            userPersona: userPersona
        )
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2) // Only 2 recipes should meet time constraint
        
        // Verify all returned recipes meet time constraint
        for recipe in result ?? [] {
            let totalTime = recipe.prepTime + recipe.cookTime
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe '\(recipe.title)' exceeds time limit")
        }
        
        // Verify the slow recipe was filtered out
        let recipeNames = result?.map { $0.title } ?? []
        XCTAssertFalse(recipeNames.contains("Slow Roast"), "Slow recipe should have been filtered out")
    }
    
    func testGenerateQuickRecipesDietaryRestrictionEnforcement() async throws {
        // Given
        let dietaryRestrictions: [DietaryNote] = [.vegan, .glutenFree]
        let userPersona = UserPersona.general
        
        // Mock response with mixed dietary compliance
        let mockRecipes = [
            createMockQuickRecipe(name: "Vegan Quinoa Bowl", prepTime: 8, cookTime: 12, dietaryNotes: [.vegan, .glutenFree]),
            createMockQuickRecipe(name: "Chicken Salad", prepTime: 5, cookTime: 0, dietaryNotes: [.glutenFree]), // Not vegan
            createMockQuickRecipe(name: "Vegan Pasta", prepTime: 10, cookTime: 15, dietaryNotes: [.vegan]) // Not gluten-free
        ]
        mockOpenAIClient.mockQuickRecipes = mockRecipes
        
        // When
        let result = await recipeManager.generateQuickRecipes(
            cuisine: .mediterranean,
            difficulty: .easy,
            dietaryRestrictions: dietaryRestrictions,
            maxTime: 30,
            servings: 2,
            userPersona: userPersona
        )
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1) // Only 1 recipe should meet all dietary restrictions
        
        // Verify all returned recipes meet dietary restrictions
        for recipe in result ?? [] {
            let recipeDietaryNotes = Set(recipe.dietaryNotes)
            let requestedDietaryNotes = Set(dietaryRestrictions)
            XCTAssertTrue(recipeDietaryNotes.isSuperset(of: requestedDietaryNotes), "Recipe '\(recipe.title)' doesn't meet dietary restrictions")
        }
        
        // Verify only the compliant recipe was returned
        let recipeNames = result?.map { $0.title } ?? []
        XCTAssertTrue(recipeNames.contains("Vegan Quinoa Bowl"), "Compliant recipe should be included")
        XCTAssertFalse(recipeNames.contains("Chicken Salad"), "Non-vegan recipe should be filtered out")
        XCTAssertFalse(recipeNames.contains("Vegan Pasta"), "Non-gluten-free recipe should be filtered out")
    }
    
    func testGenerateQuickRecipesCaching() async throws {
        // Given
        let userPersona = UserPersona.schoolKid
        
        // First call should hit LLM
        let mockRecipes = [createMockQuickRecipe(name: "Quick Recipe", prepTime: 5, cookTime: 10)]
        mockOpenAIClient.mockQuickRecipes = mockRecipes
        
        // When - First call
        let firstResult = await recipeManager.generateQuickRecipes(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            maxTime: 20,
            servings: 2,
            userPersona: userPersona
        )
        
        // Then - Should get recipes from LLM
        XCTAssertNotNil(firstResult)
        XCTAssertEqual(firstResult?.count, 1)
        
        // When - Second call with same parameters
        let secondResult = await recipeManager.generateQuickRecipes(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            maxTime: 20,
            servings: 2,
            userPersona: userPersona
        )
        
        // Then - Should get recipes from cache (same recipes)
        XCTAssertNotNil(secondResult)
        XCTAssertEqual(secondResult?.count, 1)
        XCTAssertEqual(firstResult?.first?.title, secondResult?.first?.title)
    }
    
    // MARK: - Helper Methods
    
    private func createMockQuickRecipe(
        name: String,
        prepTime: Int,
        cookTime: Int,
        dietaryNotes: [DietaryNote] = [.vegetarian]
    ) -> Recipe {
        return Recipe(
            id: UUID().uuidString,
            title: name,
            name: name,
            description: "A quick and delicious recipe",
            prepTime: prepTime,
            cookTime: cookTime,
            servings: 2,
            difficulty: .easy,
            cuisine: .italian,
            ingredients: [
                Ingredient(name: "Test Ingredient", amount: 1.0, unit: "cup")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Test step", duration: prepTime)
            ],
            dietaryNotes: dietaryNotes,
            imageURL: nil,
            winePairings: [],
            platingTips: "Test plating",
            chefNotes: "Test chef notes",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Mock OpenAI Client for Quick Recipes

extension MockOpenAIClient {
    var mockQuickRecipes: [Recipe]? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.mockQuickRecipes) as? [Recipe] }
        set { objc_setAssociatedObject(self, newValue, &AssociatedKeys.mockQuickRecipes, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    func generateQuickRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int,
        servings: Int,
        userPersona: UserPersona
    ) async throws -> [Recipe]? {
        return mockQuickRecipes
    }
}

private struct AssociatedKeys {
    static var mockQuickRecipes = "mockQuickRecipes"
}
