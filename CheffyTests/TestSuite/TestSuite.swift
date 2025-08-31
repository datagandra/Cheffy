import XCTest
import Combine
@testable import Cheffy

// MARK: - Test Suite Configuration
class TestSuite: XCTestCase {
    
    // MARK: - Test Categories
    enum TestCategory: String, CaseIterable {
        case unit = "Unit Tests"
        case integration = "Integration Tests"
        case ui = "UI Tests"
        case performance = "Performance Tests"
        case accessibility = "Accessibility Tests"
        case stress = "Stress Tests"
    }
    
    // MARK: - Test Data
    struct TestData {
        static let sampleRecipes: [Recipe] = [
            Recipe(
                id: UUID(),
                name: "Quick Pasta Carbonara",
                cuisine: .italian,
                difficulty: .easy,
                servings: 2,
                prepTime: 10,
                cookTime: 15,
                ingredients: [
                    Ingredient(name: "Spaghetti", amount: 200, unit: "g", notes: "Fresh pasta preferred"),
                    Ingredient(name: "Eggs", amount: 2, unit: "whole", notes: "Room temperature"),
                    Ingredient(name: "Pancetta", amount: 100, unit: "g", notes: "Cubed")
                ],
                steps: [
                    RecipeStep(stepNumber: 1, description: "Boil pasta in salted water", duration: 10, temperature: nil, tips: ["Salt the water well"]),
                    RecipeStep(stepNumber: 2, description: "Cook pancetta until crispy", duration: 5, temperature: nil, tips: ["Medium heat"]),
                    RecipeStep(stepNumber: 3, description: "Mix eggs with cheese", duration: 2, temperature: nil, tips: ["Don't scramble"])
                ],
                dietaryNotes: [.vegetarian],
                nutritionInfo: NutritionInfo(),
                tags: ["quick", "pasta", "italian"]
            ),
            Recipe(
                id: UUID(),
                name: "Vegetarian Curry",
                cuisine: .indian,
                difficulty: .medium,
                servings: 4,
                prepTime: 20,
                cookTime: 30,
                ingredients: [
                    Ingredient(name: "Chickpeas", amount: 400, unit: "g", notes: "Canned or cooked"),
                    Ingredient(name: "Coconut Milk", amount: 400, unit: "ml", notes: "Full fat for creaminess"),
                    Ingredient(name: "Curry Powder", amount: 2, unit: "tbsp", notes: "Mild or hot to taste")
                ],
                steps: [
                    RecipeStep(stepNumber: 1, description: "Sauté onions and garlic", duration: 5, temperature: nil, tips: ["Until translucent"]),
                    RecipeStep(stepNumber: 2, description: "Add spices and cook", duration: 2, temperature: nil, tips: ["Don't burn the spices"]),
                    RecipeStep(stepNumber: 3, description: "Simmer with coconut milk", duration: 25, temperature: nil, tips: ["Low heat to prevent curdling"])
                ],
                dietaryNotes: [.vegetarian, .vegan, .glutenFree],
                nutritionInfo: NutritionInfo(),
                tags: ["curry", "vegetarian", "indian"]
            )
        ]
        
        static let dietaryRestrictions: [DietaryNote] = [.vegetarian, .vegan, .glutenFree, .dairyFree]
        static let cuisines: [Cuisine] = [.italian, .indian, .chinese, .mexican, .japanese]
        static let difficulties: [Difficulty] = [.easy, .medium, .hard]
        static let cookingTimes: [Int] = [15, 30, 45, 60, 90]
    }
    
    // MARK: - Test Utilities
    func waitForAsyncOperation(timeout: TimeInterval = 5.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
    
    func createMockRecipe(with filters: RecipeFilters) -> Recipe {
        return Recipe(
            id: UUID(),
            name: "Mock Recipe with Filters",
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            servings: filters.servings ?? 2,
            prepTime: filters.maxTime.map { $0 / 2 } ?? 15,
            cookTime: filters.maxTime.map { $0 / 2 } ?? 30,
            ingredients: [],
            steps: [],
            dietaryNotes: filters.dietaryRestrictions ?? [],
            nutritionInfo: NutritionInfo(),
            tags: []
        )
    }
    
    func assertRecipeMatchesFilters(_ recipe: Recipe, filters: RecipeFilters) {
        if let cuisine = filters.cuisine {
            XCTAssertEqual(recipe.cuisine, cuisine, "Recipe cuisine should match filter")
        }
        
        if let difficulty = filters.difficulty {
            XCTAssertEqual(recipe.difficulty, difficulty, "Recipe difficulty should match filter")
        }
        
        if let maxTime = filters.maxTime {
            let totalTime = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0)
            XCTAssertLessThanOrEqual(totalTime, maxTime, "Recipe total time should be within filter limit")
        }
        
        if let dietaryRestrictions = filters.dietaryRestrictions {
            for restriction in dietaryRestrictions {
                XCTAssertTrue(recipe.dietaryNotes.contains(restriction), "Recipe should contain dietary restriction: \(restriction)")
            }
        }
    }
}

// MARK: - Recipe Filters Test Helper
struct RecipeFilters {
    let cuisine: Cuisine?
    let difficulty: Difficulty?
    let dietaryRestrictions: [DietaryNote]?
    let maxTime: Int?
    let servings: Int?
    
    init(cuisine: Cuisine? = nil, difficulty: Difficulty? = nil, dietaryRestrictions: [DietaryNote]? = nil, maxTime: Int? = nil, servings: Int? = nil) {
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.dietaryRestrictions = dietaryRestrictions
        self.maxTime = maxTime
        self.servings = servings
    }
}

// MARK: - Test Performance Metrics
class TestPerformanceMetrics {
    static var startTime: Date?
    static var endTime: Date?
    
    static func startMeasuring() {
        startTime = Date()
    }
    
    static func stopMeasuring() -> TimeInterval {
        endTime = Date()
        return endTime?.timeIntervalSince(startTime ?? Date()) ?? 0
    }
    
    static func assertPerformance(operation: String, maxTime: TimeInterval) {
        let executionTime = stopMeasuring()
        XCTAssertLessThan(executionTime, maxTime, "\(operation) took too long: \(executionTime)s (max: \(maxTime)s)")
    }
}
