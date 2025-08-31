import XCTest
import Combine
@testable import Cheffy

final class UserScenarioTests: XCTestCase {
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
    
    // MARK: - Scenario 1: Moms Cooking Early Morning
    
    func testMomsEarlyMorningCooking() async throws {
        // Given - Mom needs quick breakfast recipes
        let filters = RecipeFilters(
            cuisine: .american,
            difficulty: .easy,
            dietaryRestrictions: [.vegetarian],
            maxTime: 15, // Very quick for busy mornings
            servings: 4 // Family of 4
        )
        
        // When - Generate quick breakfast recipe
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: "Quick breakfast for kids",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then - Verify recipe meets morning cooking requirements
        guard let recipe = recipe else {
            XCTFail("Recipe is nil")
            return
        }
        XCTAssertEqual(recipe.difficulty, .easy, "Morning recipes should be easy")
        
        let totalTime = recipe.prepTime + recipe.cookTime
        XCTAssertLessThanOrEqual(totalTime, 15, "Morning recipes should be very quick")
        
        XCTAssertEqual(recipe.servings, 4, "Should serve family of 4")
        XCTAssertTrue(recipe.dietaryNotes.contains(.vegetarian), "Should be vegetarian")
        
        // Verify recipe is family-friendly
        XCTAssertTrue(recipe.title.lowercased().contains("breakfast") || 
                     recipe.title.lowercased().contains("pancake") ||
                     recipe.title.lowercased().contains("oatmeal") ||
                     recipe.title.lowercased().contains("smoothie"), "Should be breakfast-appropriate")
        
        // Test multiple quick recipes for variety
        let quickRecipes = try await generateMultipleQuickRecipes(count: 3, maxTime: 15)
        XCTAssertEqual(quickRecipes.count, 3)
        
        for quickRecipe in quickRecipes {
            let recipeTime = (quickRecipe.prepTime ?? 0) + (quickRecipe.cookTime ?? 0)
            XCTAssertLessThanOrEqual(recipeTime, 15, "All morning recipes should be quick")
        }
    }
    
    func testMomsCookingWithKids() async throws {
        // Given - Mom cooking with children present
        let filters = RecipeFilters(
            cuisine: .american,
            difficulty: .easy,
            dietaryRestrictions: [],
            maxTime: 20,
            servings: 4
        )
        
        // When - Generate kid-friendly recipe
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: "Fun recipe kids can help with",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then - Verify recipe is kid-friendly
        guard let recipe = recipe else {
            XCTFail("Recipe is nil")
            return
        }
        XCTAssertEqual(recipe.difficulty, .easy, "Kid recipes should be easy")
        
        // Check for kid-friendly ingredients
        let kidFriendlyIngredients = ["cheese", "pasta", "chicken", "vegetables", "fruit"]
        let hasKidFriendlyIngredients = recipe.ingredients.contains { ingredient in
            kidFriendlyIngredients.contains { friendly in
                ingredient.name.lowercased().contains(friendly)
            }
        }
        XCTAssertTrue(hasKidFriendlyIngredients, "Should contain kid-friendly ingredients")
        
        // Verify steps are simple enough for kids
        for step in recipe.steps {
            XCTAssertLessThanOrEqual(step.description.count, 100, "Steps should be simple for kids")
            XCTAssertLessThanOrEqual(step.duration ?? 0, 10, "Individual steps should be quick")
        }
    }
    
    // MARK: - Scenario 2: Chefs Exploring Cuisines
    
    func testChefsExploringEthnicCuisines() async throws {
        // Given - Chef wants to explore specific cuisines
        let ethnicCuisines: [Cuisine] = [.japanese, .ethiopian, .thai, .mexican, .indian]
        
        for cuisine in ethnicCuisines {
            // When - Generate authentic recipe for specific cuisine
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: "Authentic \(cuisine.rawValue) recipe",
                recipeName: nil,
                cuisine: cuisine,
                difficulty: .hard, // Chefs want challenging recipes
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: 90, // Chefs willing to spend time
                servings: 2
            )
            
            // Then - Verify authentic cuisine characteristics
            guard let recipe = recipe else {
                XCTFail("Recipe is nil")
                return
            }
            XCTAssertEqual(recipe.cuisine, cuisine, "Recipe should match requested cuisine: \(cuisine.rawValue)")
            XCTAssertEqual(recipe.difficulty, .hard, "Chef recipes should be challenging")
            
            // Verify cuisine-specific ingredients
            let cuisineIngredients = getCuisineSpecificIngredients(for: cuisine)
            let hasCuisineIngredients = recipe.ingredients.contains { ingredient in
                cuisineIngredients.contains { specific in
                    ingredient.name.lowercased().contains(specific)
                }
            }
            XCTAssertTrue(hasCuisineIngredients, "\(cuisine.rawValue) recipe should contain authentic ingredients")
            
            // Verify complex cooking techniques
            XCTAssertGreaterThanOrEqual(recipe.steps.count, 6, "Chef recipes should have detailed steps")
            
            for step in recipe.steps {
                XCTAssertGreaterThanOrEqual(step.duration ?? 0, 5, "Chef steps should be substantial")
            }
        }
    }
    
    func testChefsAdvancedTechniques() async throws {
        // Given - Chef wants advanced cooking techniques
        let filters = RecipeFilters(
            cuisine: .french,
            difficulty: .hard,
            dietaryRestrictions: [],
            maxTime: 120,
            servings: 4
        )
        
        // When - Generate advanced recipe
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: "Advanced French cooking techniques",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then - Verify advanced techniques
        guard let recipe = recipe else {
            XCTFail("Recipe is nil")
            return
        }
        XCTAssertEqual(recipe.difficulty, .hard, "Should be advanced difficulty")
        XCTAssertGreaterThanOrEqual(recipe.steps.count, 8, "Advanced recipes should have many steps")
        
        // Check for advanced cooking terms
        let advancedTerms = ["sauté", "braise", "reduction", "emulsify", "deglaze", "confit"]
        let hasAdvancedTerms = recipe.steps.contains { step in
            advancedTerms.contains { term in
                step.description.lowercased().contains(term)
            }
        }
        XCTAssertTrue(hasAdvancedTerms, "Advanced recipe should contain technical terms")
        
        // Verify longer cooking times
        let totalTime = recipe.prepTime + recipe.cookTime
        XCTAssertGreaterThanOrEqual(totalTime, 60, "Advanced recipes should take significant time")
    }
    
    // MARK: - Scenario 3: Newbies in Cooking
    
    func testNewbieCookingBasics() async throws {
        // Given - New cook needs basic guidance
        let filters = RecipeFilters(
            cuisine: .italian,
            difficulty: .easy,
            dietaryRestrictions: [],
            maxTime: 30,
            servings: 2
        )
        
        // When - Generate beginner-friendly recipe
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: "Simple recipe for beginners",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then - Verify beginner-friendly characteristics
        guard let recipe = recipe else {
            XCTFail("Recipe should not be nil")
            return
        }
        XCTAssertEqual(recipe.difficulty, .easy, "Should be easy for beginners")
        XCTAssertLessThanOrEqual(recipe.steps.count, 5, "Beginner recipes should have few steps")
        
        // Verify simple ingredients
        let simpleIngredients = ["pasta", "tomato", "cheese", "olive oil", "garlic", "basil"]
        let hasSimpleIngredients = recipe.ingredients.contains { ingredient in
            simpleIngredients.contains { simple in
                ingredient.name.lowercased().contains(simple)
            }
        }
        XCTAssertTrue(hasSimpleIngredients, "Should contain simple, common ingredients")
        
        // Verify helpful tips in steps
        let stepsWithTips = recipe.steps.filter { !($0.tips?.isEmpty ?? true) }
        XCTAssertGreaterThanOrEqual(stepsWithTips.count, 2, "Beginner recipes should have helpful tips")
        
        // Verify reasonable cooking times
        let totalTime = recipe.prepTime + recipe.cookTime
        XCTAssertLessThanOrEqual(totalTime, 30, "Beginner recipes should be quick")
    }
    
    func testNewbieCookingWithVoiceInstructions() async throws {
        // Given - New cook wants voice guidance
        let filters = RecipeFilters(
            cuisine: .american,
            difficulty: .easy,
            dietaryRestrictions: [],
            maxTime: 25,
            servings: 2
        )
        
        // When - Generate recipe with voice-friendly steps
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: "Recipe with clear voice instructions",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then - Verify voice-friendly characteristics
        guard let recipe = recipe else {
            XCTFail("Recipe should not be nil")
            return
        }
        XCTAssertEqual(recipe.difficulty, .easy, "Voice recipes should be easy")
        
        // Verify clear, descriptive steps
        for step in recipe.steps {
            XCTAssertGreaterThanOrEqual(step.description.count, 20, "Steps should be descriptive for voice")
            XCTAssertLessThanOrEqual(step.description.count, 150, "Steps shouldn't be too long for voice")
            
            // Check for clear action words
            let actionWords = ["add", "stir", "cook", "heat", "mix", "pour", "cut", "chop"]
            let hasActionWord = actionWords.contains { action in
                step.description.lowercased().contains(action)
            }
            XCTAssertTrue(hasActionWord, "Steps should have clear action words for voice")
        }
        
        // Verify helpful tips for voice guidance
        let stepsWithTips = recipe.steps.filter { !($0.tips?.isEmpty ?? true) }
        XCTAssertGreaterThanOrEqual(stepsWithTips.count, 1, "Voice recipes should have helpful tips")
    }
    
    // MARK: - Scenario 4: Restaurant Use Cases
    
    func testRestaurantHighVolumeCooking() async throws {
        // Given - Restaurant needs high-volume recipes
        let filters = RecipeFilters(
            cuisine: .italian,
            difficulty: .medium,
            dietaryRestrictions: [],
            maxTime: 45,
            servings: 20 // Large batch
        )
        
        // When - Generate restaurant-scale recipe
        let recipe = try await mockLLMService.generateRecipe(
            userPrompt: "Restaurant quantity recipe",
            recipeName: nil,
            cuisine: filters.cuisine ?? .italian,
            difficulty: filters.difficulty ?? .medium,
            dietaryRestrictions: filters.dietaryRestrictions ?? [],
            ingredients: nil,
            maxTime: filters.maxTime,
            servings: filters.servings ?? 2
        )
        
        // Then - Verify restaurant-scale characteristics
        guard let recipe = recipe else {
            XCTFail("Recipe should not be nil")
            return
        }
        XCTAssertEqual(recipe.servings, 20, "Should serve restaurant quantity")
        XCTAssertEqual(recipe.difficulty, .medium, "Restaurant recipes should be manageable")
        
        // Verify scalable ingredients
        for ingredient in recipe.ingredients {
            XCTAssertGreaterThanOrEqual(ingredient.amount, 1.0, "Restaurant ingredients should be substantial")
        }
        
        // Verify efficient cooking methods
        let totalTime = recipe.prepTime + recipe.cookTime
        XCTAssertLessThanOrEqual(totalTime, 45, "Restaurant recipes should be time-efficient")
        
        // Verify professional techniques
        let professionalTerms = ["batch", "prep", "mise en place", "service", "plating"]
        let hasProfessionalTerms = recipe.steps.contains { step in
            professionalTerms.contains { term in
                step.description.lowercased().contains(term)
            }
        }
        XCTAssertTrue(hasProfessionalTerms, "Restaurant recipes should use professional terminology")
    }
    
    func testRestaurantMultipleCuisineSupport() async throws {
        // Given - Restaurant serves multiple cuisines
        let cuisines: [Cuisine] = [.italian, .chinese, .mexican, .indian, .american]
        var allRecipes: [Recipe] = []
        
        // When - Generate recipes for each cuisine
        for cuisine in cuisines {
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: "Restaurant \(cuisine.rawValue) dish",
                recipeName: nil,
                cuisine: cuisine,
                difficulty: .medium,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: 60,
                servings: 15
            )
            
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
            allRecipes.append(recipe)
        }
        
        // Then - Verify diverse cuisine support
        XCTAssertEqual(allRecipes.count, cuisines.count, "Should support all requested cuisines")
        
        for (index, cuisine) in cuisines.enumerated() {
            XCTAssertEqual(allRecipes[index].cuisine, cuisine, "Recipe should match cuisine: \(cuisine.rawValue)")
            XCTAssertEqual(allRecipes[index].servings, 15, "All restaurant recipes should serve same quantity")
        }
        
        // Verify consistent quality across cuisines
        for recipe in allRecipes {
            XCTAssertEqual(recipe.difficulty, .medium, "All restaurant recipes should be consistent difficulty")
            XCTAssertGreaterThanOrEqual(recipe.steps.count, 4, "All recipes should have adequate steps")
        }
    }
    
    func testRestaurantRapidFilterChanges() async throws {
        // Given - Restaurant staff rapidly changing filters
        let filterCombinations = [
            RecipeFilters(cuisine: .italian, difficulty: .easy, dietaryRestrictions: [.vegetarian]),
            RecipeFilters(cuisine: .chinese, difficulty: .medium, dietaryRestrictions: [.glutenFree]),
            RecipeFilters(cuisine: .mexican, difficulty: .hard, dietaryRestrictions: [.vegan]),
            RecipeFilters(cuisine: .indian, difficulty: .easy, dietaryRestrictions: [.dairyFree])
        ]
        
        // When - Rapidly generate recipes with different filters
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
        
        // Then - Verify all recipes generated successfully
        XCTAssertEqual(recipes.count, filterCombinations.count, "All filter combinations should generate recipes")
        
        // Verify performance under rapid changes
        TestPerformanceMetrics.assertPerformance(operation: "Rapid filter changes", maxDuration: 6.0)
        
        // Verify each recipe matches its filters
        for (index, filters) in filterCombinations.enumerated() {
            // Verify recipe matches filters
            XCTAssertEqual(recipes[index].cuisine, filters.cuisine)
            XCTAssertEqual(recipes[index].difficulty, filters.difficulty)
            XCTAssertLessThanOrEqual(recipes[index].totalTime, filters.maxTime ?? Int.max)
            XCTAssertEqual(recipes[index].servings, filters.servings)
            for restriction in filters.dietaryRestrictions {
                XCTAssertTrue(recipes[index].dietaryNotes.contains(restriction), "Recipe should contain \(restriction.rawValue)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateMultipleQuickRecipes(count: Int, maxTime: Int) async throws -> [Recipe] {
        var recipes: [Recipe] = []
        
        for _ in 0..<count {
            let recipe = try await mockLLMService.generateRecipe(
                userPrompt: "Quick recipe",
                recipeName: nil,
                cuisine: .american,
                difficulty: .easy,
                dietaryRestrictions: [],
                ingredients: nil,
                maxTime: maxTime,
                servings: 4
            )
            guard let recipe = recipe else {
                XCTFail("Recipe should not be nil")
                return
            }
            recipes.append(recipe)
        }
        
        return recipes
    }
    
    private func getCuisineSpecificIngredients(for cuisine: Cuisine) -> [String] {
        switch cuisine {
        case .japanese:
            return ["miso", "dashi", "mirin", "sake", "nori", "wasabi"]
        case .ethiopian:
            return ["berbere", "teff", "injera", "niter kibbeh", "mitmita"]
        case .thai:
            return ["fish sauce", "palm sugar", "kaffir lime", "galangal", "lemongrass"]
        case .mexican:
            return ["achiote", "epazote", "hoja santa", "poblano", "queso fresco"]
        case .indian:
            return ["garam masala", "turmeric", "cardamom", "fenugreek", "asafoetida"]
        default:
            return []
        }
    }
}
