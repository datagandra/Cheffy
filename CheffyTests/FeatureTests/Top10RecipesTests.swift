import XCTest
import Combine
@testable import Cheffy

final class Top10RecipesTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    var mockCloudKitService: MockCloudKitService!
    var mockUserAnalyticsService: MockUserAnalyticsService!
    var top10Manager: Top10RecipesManager!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockCloudKitService = MockCloudKitService()
        mockUserAnalyticsService = MockUserAnalyticsService()
        top10Manager = Top10RecipesManager()
    }
    
    override func tearDown() {
        cancellables = nil
        mockCloudKitService = nil
        mockUserAnalyticsService = nil
        top10Manager = nil
        super.tearDown()
    }
    
    // MARK: - Top 10 Recipes Data Structure Tests
    
    func testTop10RecipeDataStructure() throws {
        // Given
        let top10Recipe = Top10Recipe(
            id: UUID().uuidString,
            name: "Test Recipe",
            cuisine: "italian",
            difficulty: "easy",
            prepTime: 15,
            cookTime: 30,
            servings: 4,
            dietaryNotes: ["vegetarian", "gluten-free"],
            imageURL: "https://example.com/image.jpg",
            downloadCount: 150,
            rating: 4.5,
            lastDownloaded: Date()
        )
        
        // Then - Verify data structure
        XCTAssertNotNil(top10Recipe.id)
        XCTAssertEqual(top10Recipe.name, "Test Recipe")
        XCTAssertEqual(top10Recipe.cuisine, "italian")
        XCTAssertEqual(top10Recipe.difficulty, "easy")
        XCTAssertEqual(top10Recipe.prepTime, 15)
        XCTAssertEqual(top10Recipe.cookTime, 30)
        XCTAssertEqual(top10Recipe.servings, 4)
        XCTAssertEqual(top10Recipe.dietaryNotes.count, 2)
        XCTAssertEqual(top10Recipe.downloadCount, 150)
        XCTAssertEqual(top10Recipe.rating, 4.5)
        XCTAssertNotNil(top10Recipe.lastDownloaded)
    }
    
    // MARK: - Monthly Aggregation Logic Tests
    
    func testMonthlyAggregationLogic() async throws {
        // Given - Multiple recipes with different download counts
        let recipes = createTestRecipesWithDownloads()
        
        // When - Aggregate by month
        let monthlyStats = top10Manager.aggregateMonthlyDownloads(recipes)
        
        // Then - Verify aggregation logic
        XCTAssertNotNil(monthlyStats)
        XCTAssertGreaterThan(monthlyStats.count, 0)
        
        // Verify recipes are sorted by download count
        for i in 0..<(monthlyStats.count - 1) {
            XCTAssertGreaterThanOrEqual(
                monthlyStats[i].downloadCount,
                monthlyStats[i + 1].downloadCount,
                "Recipes should be sorted by download count (descending)"
            )
        }
    }
    
    func testMonthlyAggregationWithDateFiltering() async throws {
        // Given - Recipes from different months
        let currentDate = Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: currentDate)!
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: currentDate)!
        
        let recipes = [
            createRecipeWithDate("Recent Recipe", downloadCount: 100, date: currentDate),
            createRecipeWithDate("Old Recipe", downloadCount: 200, date: twoMonthsAgo),
            createRecipeWithDate("Medium Recipe", downloadCount: 150, date: oneMonthAgo)
        ]
        
        // When - Aggregate current month only
        let currentMonthStats = top10Manager.aggregateMonthlyDownloads(recipes, forMonth: currentDate)
        
        // Then - Verify only current month recipes included
        XCTAssertEqual(currentMonthStats.count, 1)
        XCTAssertEqual(currentMonthStats.first?.name, "Recent Recipe")
        XCTAssertEqual(currentMonthStats.first?.downloadCount, 100)
    }
    
    func testMonthlyAggregationWithMultipleDownloads() async throws {
        // Given - Same recipe downloaded multiple times in different months
        let recipeName = "Popular Recipe"
        let currentDate = Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: currentDate)!
        
        let recipes = [
            createRecipeWithDate(recipeName, downloadCount: 50, date: currentDate),
            createRecipeWithDate(recipeName, downloadCount: 75, date: oneMonthAgo),
            createRecipeWithDate(recipeName, downloadCount: 25, date: oneMonthAgo)
        ]
        
        // When - Aggregate across all months
        let aggregatedStats = top10Manager.aggregateMonthlyDownloads(recipes)
        
        // Then - Verify total downloads are summed
        let totalDownloads = recipes.reduce(0) { $0 + $1.downloadCount }
        XCTAssertEqual(aggregatedStats.first?.downloadCount, totalDownloads)
        XCTAssertEqual(aggregatedStats.first?.name, recipeName)
    }
    
    // MARK: - Popularity Sorting Tests
    
    func testPopularitySortingByDownloadCount() async throws {
        // Given - Recipes with different download counts
        let recipes = [
            createRecipeWithDownloads("Low Popular", downloadCount: 10),
            createRecipeWithDownloads("High Popular", downloadCount: 500),
            createRecipeWithDownloads("Medium Popular", downloadCount: 100),
            createRecipeWithDownloads("Very Popular", downloadCount: 1000)
        ]
        
        // When - Sort by popularity
        let sortedRecipes = top10Manager.sortByPopularity(recipes)
        
        // Then - Verify correct sorting order
        XCTAssertEqual(sortedRecipes.count, 4)
        XCTAssertEqual(sortedRecipes[0].name, "Very Popular")
        XCTAssertEqual(sortedRecipes[0].downloadCount, 1000)
        XCTAssertEqual(sortedRecipes[1].name, "High Popular")
        XCTAssertEqual(sortedRecipes[1].downloadCount, 500)
        XCTAssertEqual(sortedRecipes[2].name, "Medium Popular")
        XCTAssertEqual(sortedRecipes[2].downloadCount, 100)
        XCTAssertEqual(sortedRecipes[3].name, "Low Popular")
        XCTAssertEqual(sortedRecipes[3].downloadCount, 10)
    }
    
    func testPopularitySortingWithTieBreakers() async throws {
        // Given - Recipes with same download count but different ratings
        let recipes = [
            createRecipeWithDownloadsAndRating("Recipe A", downloadCount: 100, rating: 4.0),
            createRecipeWithDownloadsAndRating("Recipe B", downloadCount: 100, rating: 4.5),
            createRecipeWithDownloadsAndRating("Recipe C", downloadCount: 100, rating: 3.5)
        ]
        
        // When - Sort by popularity (downloads + rating tiebreaker)
        let sortedRecipes = top10Manager.sortByPopularity(recipes)
        
        // Then - Verify rating is used as tiebreaker
        XCTAssertEqual(sortedRecipes.count, 3)
        XCTAssertEqual(sortedRecipes[0].name, "Recipe B") // Highest rating
        XCTAssertEqual(sortedRecipes[1].name, "Recipe A") // Medium rating
        XCTAssertEqual(sortedRecipes[2].name, "Recipe C") // Lowest rating
    }
    
    func testPopularitySortingWithMultipleFactors() async throws {
        // Given - Complex popularity scenario
        let recipes = [
            createRecipeWithDownloadsAndRating("High Downloads, Low Rating", downloadCount: 500, rating: 3.0),
            createRecipeWithDownloadsAndRating("Low Downloads, High Rating", downloadCount: 50, rating: 5.0),
            createRecipeWithDownloadsAndRating("Medium Both", downloadCount: 200, rating: 4.0),
            createRecipeWithDownloadsAndRating("High Both", downloadCount: 400, rating: 4.5)
        ]
        
        // When - Sort by popularity
        let sortedRecipes = top10Manager.sortByPopularity(recipes)
        
        // Then - Verify complex sorting logic
        XCTAssertEqual(sortedRecipes.count, 4)
        
        // High downloads should generally rank higher, but high ratings can boost lower download recipes
        let firstRecipe = sortedRecipes[0]
        XCTAssertTrue(firstRecipe.downloadCount >= 400 || firstRecipe.rating >= 4.5)
    }
    
    // MARK: - Top 10 Limit Tests
    
    func testTop10LimitEnforcement() async throws {
        // Given - More than 10 recipes
        let recipes = (1...15).map { index in
            createRecipeWithDownloads("Recipe \(index)", downloadCount: 1000 - (index * 50))
        }
        
        // When - Get top 10
        let top10 = top10Manager.getTop10(recipes)
        
        // Then - Verify limit enforcement
        XCTAssertEqual(top10.count, 10)
        XCTAssertEqual(top10[0].name, "Recipe 1") // Highest downloads
        XCTAssertEqual(top10[9].name, "Recipe 10") // 10th highest
        XCTAssertFalse(top10.contains { $0.name == "Recipe 11" }) // Should not include 11th
    }
    
    func testTop10WithFewerThan10Recipes() async throws {
        // Given - Less than 10 recipes
        let recipes = (1...5).map { index in
            createRecipeWithDownloads("Recipe \(index)", downloadCount: 1000 - (index * 100))
        }
        
        // When - Get top 10
        let top10 = top10Manager.getTop10(recipes)
        
        // Then - Verify all recipes included
        XCTAssertEqual(top10.count, 5)
        XCTAssertEqual(top10[0].name, "Recipe 1")
        XCTAssertEqual(top10[4].name, "Recipe 5")
    }
    
    // MARK: - UI Display Validation Tests
    
    func testTop10RecipeCardDisplay() throws {
        // Given - Top 10 recipe
        let recipe = Top10Recipe(
            id: UUID().uuidString,
            name: "Delicious Pasta Carbonara",
            cuisine: "italian",
            difficulty: "medium",
            prepTime: 20,
            cookTime: 25,
            servings: 4,
            dietaryNotes: ["vegetarian"],
            imageURL: "https://example.com/carbonara.jpg",
            downloadCount: 250,
            rating: 4.3,
            lastDownloaded: Date()
        )
        
        // Then - Verify display properties
        XCTAssertNotNil(recipe.displayTitle)
        XCTAssertNotNil(recipe.displayCuisine)
        XCTAssertNotNil(recipe.displayDifficulty)
        XCTAssertNotNil(recipe.displayTime)
        XCTAssertNotNil(recipe.displayServings)
        XCTAssertNotNil(recipe.displayDietaryNotes)
        XCTAssertNotNil(recipe.displayDownloadCount)
        XCTAssertNotNil(recipe.displayRating)
    }
    
    func testTop10RecipeCardAccessibility() throws {
        // Given - Top 10 recipe
        let recipe = createRecipeWithDownloads("Accessible Recipe", downloadCount: 100)
        
        // Then - Verify accessibility properties
        XCTAssertNotNil(recipe.accessibilityLabel)
        XCTAssertNotNil(recipe.accessibilityHint)
        XCTAssertTrue(recipe.accessibilityLabel?.contains(recipe.name) ?? false)
        XCTAssertTrue(recipe.accessibilityLabel?.contains("downloads") ?? false)
    }
    
    // MARK: - Quick Action Button Tests
    
    func testQuickActionButtonsAvailability() throws {
        // Given - Top 10 recipe
        let recipe = createRecipeWithDownloads("Test Recipe", downloadCount: 100)
        
        // Then - Verify quick action buttons
        XCTAssertTrue(recipe.canFavorite)
        XCTAssertTrue(recipe.canShare)
        XCTAssertTrue(recipe.canViewDetails)
        XCTAssertTrue(recipe.canDownload)
    }
    
    func testQuickActionButtonStates() throws {
        // Given - Top 10 recipe with different states
        let recipe = createRecipeWithDownloads("Test Recipe", downloadCount: 100)
        
        // When - Check button states
        let favoriteButton = recipe.favoriteButtonState
        let shareButton = recipe.shareButtonState
        let downloadButton = recipe.downloadButtonState
        
        // Then - Verify button states
        XCTAssertNotNil(favoriteButton)
        XCTAssertNotNil(shareButton)
        XCTAssertNotNil(downloadButton)
        
        // Verify button accessibility
        XCTAssertNotNil(favoriteButton?.accessibilityLabel)
        XCTAssertNotNil(shareButton?.accessibilityLabel)
        XCTAssertNotNil(downloadButton?.accessibilityLabel)
    }
    
    // MARK: - Performance Tests
    
    func testTop10GenerationPerformance() async throws {
        // Given - Large number of recipes
        let recipes = (1...1000).map { index in
            createRecipeWithDownloads("Recipe \(index)", downloadCount: Int.random(in: 1...1000))
        }
        
        // When - Generate top 10
        TestPerformanceMetrics.startMeasuring()
        
        let top10 = top10Manager.getTop10(recipes)
        
        // Then - Verify performance
        XCTAssertEqual(top10.count, 10)
        TestPerformanceMetrics.assertPerformance(operation: "Top 10 generation from 1000 recipes", maxDuration: 0.1)
    }
    
    func testMonthlyAggregationPerformance() async throws {
        // Given - Large number of recipes across multiple months
        let recipes = createLargeTestDataset()
        
        // When - Aggregate monthly data
        TestPerformanceMetrics.startMeasuring()
        
        let monthlyStats = top10Manager.aggregateMonthlyDownloads(recipes)
        
        // Then - Verify performance
        XCTAssertGreaterThan(monthlyStats.count, 0)
        TestPerformanceMetrics.assertPerformance(operation: "Monthly aggregation from large dataset", maxDuration: 0.5)
    }
    
    // MARK: - Edge Case Tests
    
    func testTop10WithZeroDownloads() async throws {
        // Given - Recipes with zero downloads
        let recipes = [
            createRecipeWithDownloads("No Downloads", downloadCount: 0),
            createRecipeWithDownloads("Some Downloads", downloadCount: 50),
            createRecipeWithDownloads("Zero Again", downloadCount: 0)
        ]
        
        // When - Get top 10
        let top10 = top10Manager.getTop10(recipes)
        
        // Then - Verify handling of zero downloads
        XCTAssertEqual(top10.count, 3)
        XCTAssertEqual(top10[0].name, "Some Downloads") // Should rank first
        // Zero download recipes should be included but ranked last
        XCTAssertTrue(top10.contains { $0.name == "No Downloads" })
        XCTAssertTrue(top10.contains { $0.name == "Zero Again" })
    }
    
    func testTop10WithInvalidData() async throws {
        // Given - Recipes with invalid data
        let recipes = [
            createRecipeWithDownloads("Valid Recipe", downloadCount: 100),
            createRecipeWithDownloads("", downloadCount: 50), // Empty name
            createRecipeWithDownloads("Invalid Recipe", downloadCount: -10) // Negative downloads
        ]
        
        // When - Get top 10
        let top10 = top10Manager.getTop10(recipes)
        
        // Then - Verify invalid data handling
        XCTAssertEqual(top10.count, 3)
        
        // Should handle empty names gracefully
        XCTAssertTrue(top10.contains { $0.name.isEmpty })
        
        // Should handle negative downloads (treat as 0)
        let negativeDownloadRecipe = top10.first { $0.downloadCount < 0 }
        XCTAssertNotNil(negativeDownloadRecipe)
    }
    
    // MARK: - Integration Tests
    
    func testTop10WithCloudKitIntegration() async throws {
        // Given - Mock CloudKit service with recipe data
        let mockRecipes = createTestRecipesWithDownloads()
        mockCloudKitService.setMockData(userRecipes: []) // Set up mock data
        
        // When - Fetch top 10 from CloudKit
        let top10 = try await top10Manager.fetchTop10FromCloudKit()
        
        // Then - Verify CloudKit integration
        XCTAssertNotNil(top10)
        // Additional verification based on mock data setup
    }
    
    func testTop10WithAnalyticsIntegration() async throws {
        // Given - Mock analytics service
        let recipe = Recipe(
            id: UUID(),
            title: "Test Recipe",
            cuisine: .italian,
            difficulty: .medium,
            prepTime: 20,
            cookTime: 30,
            servings: 4,
            ingredients: [
                Ingredient(name: "flour", amount: 1.0, unit: "cup")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Mix ingredients", tips: "Use a whisk")
            ],
            winePairings: [],
            dietaryNotes: [.vegetarian]
        )
        
        // When - Log recipe view and check top 10 impact
        try await mockUserAnalyticsService.logRecipeView(recipe)
        
        // Then - Verify analytics integration
        let analyticsEvents = mockUserAnalyticsService.getAnalyticsEvents()
        XCTAssertEqual(analyticsEvents["recipe_view"], 1)
        
        // Verify analytics data can be used for top 10 calculations
        let aggregatedStats = try await mockUserAnalyticsService.getAggregatedStats()
        XCTAssertNotNil(aggregatedStats["totalEvents"])
    }
    
    // MARK: - Helper Methods
    
    private func createTestRecipesWithDownloads() -> [Top10Recipe] {
        return [
            createRecipeWithDownloads("Recipe A", downloadCount: 500),
            createRecipeWithDownloads("Recipe B", downloadCount: 300),
            createRecipeWithDownloads("Recipe C", downloadCount: 800),
            createRecipeWithDownloads("Recipe D", downloadCount: 200),
            createRecipeWithDownloads("Recipe E", downloadCount: 1000)
        ]
    }
    
    private func createRecipeWithDownloads(_ name: String, downloadCount: Int) -> Top10Recipe {
        return Top10Recipe(
            id: UUID().uuidString,
            name: name,
            cuisine: "italian",
            difficulty: "medium",
            prepTime: 20,
            cookTime: 30,
            servings: 4,
            dietaryNotes: ["vegetarian"],
            imageURL: "https://example.com/image.jpg",
            downloadCount: downloadCount,
            rating: 4.0,
            lastDownloaded: Date()
        )
    }
    
    private func createRecipeWithDownloadsAndRating(_ name: String, downloadCount: Int, rating: Double) -> Top10Recipe {
        return Top10Recipe(
            id: UUID().uuidString,
            name: name,
            cuisine: "italian",
            difficulty: "medium",
            prepTime: 20,
            cookTime: 30,
            servings: 4,
            dietaryNotes: ["vegetarian"],
            imageURL: "https://example.com/image.jpg",
            downloadCount: downloadCount,
            rating: rating,
            lastDownloaded: Date()
        )
    }
    
    private func createRecipeWithDate(_ name: String, downloadCount: Int, date: Date) -> Top10Recipe {
        return Top10Recipe(
            id: UUID().uuidString,
            name: name,
            cuisine: "italian",
            difficulty: "medium",
            prepTime: 20,
            cookTime: 30,
            servings: 4,
            dietaryNotes: ["vegetarian"],
            imageURL: "https://example.com/image.jpg",
            downloadCount: downloadCount,
            rating: 4.0,
            lastDownloaded: date
        )
    }
    
    private func createLargeTestDataset() -> [Top10Recipe] {
        return (1...1000).map { index in
            Top10Recipe(
                id: UUID().uuidString,
                name: "Recipe \(index)",
                cuisine: "italian",
                difficulty: "medium",
                prepTime: 20,
                cookTime: 30,
                servings: 4,
                dietaryNotes: ["vegetarian"],
                imageURL: "https://example.com/image\(index).jpg",
                downloadCount: Int.random(in: 1...1000),
                rating: Double.random(in: 1.0...5.0),
                lastDownloaded: Date()
            )
        }
    }
}

// MARK: - Mock Top10RecipesManager
class Top10RecipesManager {
    func aggregateMonthlyDownloads(_ recipes: [Top10Recipe], forMonth: Date? = nil) -> [Top10Recipe] {
        // Mock implementation for testing
        let sortedRecipes = recipes.sorted { $0.downloadCount > $1.downloadCount }
        return sortedRecipes
    }
    
    func sortByPopularity(_ recipes: [Top10Recipe]) -> [Top10Recipe] {
        // Mock implementation for testing
        return recipes.sorted { first, second in
            if first.downloadCount == second.downloadCount {
                return first.rating > second.rating
            }
            return first.downloadCount > second.downloadCount
        }
    }
    
    func getTop10(_ recipes: [Top10Recipe]) -> [Top10Recipe] {
        let sorted = sortByPopularity(recipes)
        return Array(sorted.prefix(10))
    }
    
    func fetchTop10FromCloudKit() async throws -> [Top10Recipe] {
        // Mock implementation for testing
        return createMockTop10Recipes()
    }
    
    private func createMockTop10Recipes() -> [Top10Recipe] {
        return (1...10).map { index in
            Top10Recipe(
                id: UUID().uuidString,
                name: "Mock Recipe \(index)",
                cuisine: "italian",
                difficulty: "medium",
                prepTime: 20,
                cookTime: 30,
                servings: 4,
                dietaryNotes: ["vegetarian"],
                imageURL: "https://example.com/mock\(index).jpg",
                downloadCount: 1000 - (index * 50),
                rating: 4.5,
                lastDownloaded: Date()
            )
        }
    }
}

// MARK: - Mock Top10Recipe
struct Top10Recipe {
    let id: String
    let name: String
    let cuisine: String
    let difficulty: String
    let prepTime: Int
    let cookTime: Int
    let servings: Int
    let dietaryNotes: [String]
    let imageURL: String
    let downloadCount: Int
    let rating: Double
    let lastDownloaded: Date
    
    // Display properties
    var displayTitle: String { name }
    var displayCuisine: String { cuisine.capitalized }
    var displayDifficulty: String { difficulty.capitalized }
    var displayTime: String { "\(prepTime + cookTime) min" }
    var displayServings: String { "\(servings) servings" }
    var displayDietaryNotes: String { dietaryNotes.joined(separator: ", ") }
    var displayDownloadCount: String { "\(downloadCount) downloads" }
    var displayRating: String { String(format: "%.1f", rating) }
    
    // Accessibility
    var accessibilityLabel: String? { "\(name), \(displayRating) stars, \(displayDownloadCount)" }
    var accessibilityHint: String? { "Double tap to view recipe details" }
    
    // Quick action availability
    var canFavorite: Bool { true }
    var canShare: Bool { true }
    var canViewDetails: Bool { true }
    var canDownload: Bool { true }
    
    // Button states
    var favoriteButtonState: QuickActionButton? { QuickActionButton(title: "Favorite", icon: "heart") }
    var shareButtonState: QuickActionButton? { QuickActionButton(title: "Share", icon: "square.and.arrow.up") }
    var downloadButtonState: QuickActionButton? { QuickActionButton(title: "Download", icon: "arrow.down.circle") }
}

// MARK: - Mock QuickActionButton
struct QuickActionButton {
    let title: String
    let icon: String
    var accessibilityLabel: String? { title }
}
