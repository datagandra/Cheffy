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
            title: "Spaghetti Carbonara",
            cuisine: .italian,
            difficulty: .medium,
            prepTime: 15,
            cookTime: 20,
            servings: 4,
            ingredients: [
                Ingredient(name: "Spaghetti", amount: 400, unit: "grams", notes: "Dried"),
                Ingredient(name: "Eggs", amount: 4, unit: "large", notes: "Fresh"),
                Ingredient(name: "Pancetta", amount: 150, unit: "grams", notes: "Cubed"),
                Ingredient(name: "Parmesan", amount: 100, unit: "grams", notes: "Freshly grated")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Boil pasta according to package instructions"),
                CookingStep(stepNumber: 2, description: "Cook pancetta until crispy"),
                CookingStep(stepNumber: 3, description: "Mix eggs and cheese in a bowl"),
                CookingStep(stepNumber: 4, description: "Combine pasta with egg mixture and pancetta")
            ]
        ),
        Recipe(
            title: "Chicken Curry",
            cuisine: .indian,
            difficulty: .easy,
            prepTime: 20,
            cookTime: 30,
            servings: 6,
            ingredients: [
                Ingredient(name: "Chicken", amount: 500, unit: "grams", notes: "Boneless, cubed"),
                Ingredient(name: "Onion", amount: 2, unit: "medium", notes: "Diced"),
                Ingredient(name: "Garlic", amount: 4, unit: "cloves", notes: "Minced"),
                Ingredient(name: "Coconut Milk", amount: 400, unit: "ml", notes: "Full fat")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Sauté onions and garlic"),
                CookingStep(stepNumber: 2, description: "Add chicken and brown"),
                CookingStep(stepNumber: 3, description: "Add coconut milk and simmer"),
                CookingStep(stepNumber: 4, description: "Season and serve")
            ]
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

    static func createMockRecipe(
        title: String = "Mock Recipe",
        cuisine: Cuisine = .italian,
        difficulty: Difficulty = .easy,
        prepTime: Int = 15,
        cookTime: Int = 20,
        servings: Int = 2,
        dietaryRestrictions: [DietaryNote] = []
    ) -> Recipe {
        return Recipe(
            title: title,
            cuisine: cuisine,
            difficulty: difficulty,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            ingredients: [
                Ingredient(name: "Mock Ingredient", amount: 100, unit: "grams", notes: "For testing")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Mock step for testing")
            ],
            dietaryNotes: dietaryRestrictions
        )
    }


}

// MARK: - Recipe Filters Test Helper
struct RecipeFilters {
    let cuisine: Cuisine
    let difficulty: Difficulty
    let dietaryRestrictions: [DietaryNote]
    let maxTime: Int?
    let servings: Int
    
    init(cuisine: Cuisine = .any, difficulty: Difficulty = .easy, dietaryRestrictions: [DietaryNote] = [], maxTime: Int? = nil, servings: Int = 4) {
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.dietaryRestrictions = dietaryRestrictions
        self.maxTime = maxTime
        self.servings = servings
    }
}

// MARK: - Test Performance Metrics
class TestPerformanceMetrics {
    static var startTime: Date = Date()
    static var endTime: Date = Date()
    
    static func startMeasuring() {
        startTime = Date()
    }
    
    static func stopMeasuring() -> TimeInterval {
        endTime = Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    static func assertPerformance(operation: String, maxDuration: TimeInterval, file: StaticString = #file, line: UInt = #line) {
        let duration = stopMeasuring()
        XCTAssertLessThan(duration, maxDuration, "\(operation) took \(duration)s, expected less than \(maxDuration)s", file: file, line: line)
    }
}
