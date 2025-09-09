import Foundation
import os.log
import SwiftUI // Added for Color

/// Service for managing the comprehensive recipe database
class RecipeDatabaseService: ObservableObject {
    static let shared = RecipeDatabaseService()
    
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let logger = Logger.shared
    
    // MARK: - Recipe Database Management
    
    /// Loads all recipes from the local database files
    func loadAllRecipes() async {
        print("🚀 DEBUG: RecipeDatabaseService.loadAllRecipes() called")
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        var allRecipes: [Recipe] = []
        
        // Load recipes from all cuisine JSON files
        let cuisineFiles = [
            "american_cuisines",
            "asian_cuisines_extended", 
            "asian_cuisines",
            "european_cuisines",
            "indian_cuisines",
            "latin_american_cuisines",
            "mediterranean_cuisines",
            "mexican_cuisines",
            "middle_eastern_african_cuisines"
        ]
        
        for fileName in cuisineFiles {
            if let recipes = try? await loadRecipesFromFile(fileName) {
                allRecipes.append(contentsOf: recipes)
                logger.info("Loaded \(recipes.count) recipes from \(fileName).json")
                
                // Debug: Check for Chinese recipes specifically
                if fileName == "asian_cuisines_extended" {
                    let chineseRecipes = recipes.filter { $0.cuisine == .chinese }
                    logger.info("Chinese recipes found in \(fileName): \(chineseRecipes.count)")
                    for recipe in chineseRecipes {
                        logger.info("Chinese recipe: \(recipe.title)")
                    }
                }
            } else {
                logger.warning("Could not find \(fileName).json")
            }
        }
        
        await MainActor.run {
            self.recipes = allRecipes
            self.isLoading = false
            print("🔍 DEBUG: RecipeDatabaseService loaded \(allRecipes.count) recipes")
            logger.info("Loaded \(allRecipes.count) total recipes from JSON files")
            
            // Debug: Count recipes by cuisine
            let indianRecipes = allRecipes.filter { $0.cuisine == .indian }
            logger.info("Indian recipes loaded: \(indianRecipes.count)")
            
            let chineseRecipes = allRecipes.filter { $0.cuisine == .chinese }
            logger.info("Chinese recipes loaded: \(chineseRecipes.count)")
        }
    }
    
    /// Gets all recipes
    func getAllRecipes() -> [Recipe] {
        return recipes
    }
    
    /// Gets recipes by dietary notes
    func getRecipes(for dietaryNotes: [DietaryNote]) -> [Recipe] {
        return recipes.filter { recipe in
            !Set(recipe.dietaryNotes).isDisjoint(with: Set(dietaryNotes))
        }
    }
    
    /// Creates sample recipes for testing
    private func createSampleRecipes() -> [Recipe] {
        return [
            Recipe(
                title: "Chicken Tikka Masala",
                cuisine: .indian,
                difficulty: .medium,
                prepTime: 20,
                cookTime: 45,
                servings: 4,
                ingredients: [
                    Ingredient(name: "chicken breast", amount: 500, unit: "g"),
                    Ingredient(name: "yogurt", amount: 200, unit: "ml"),
                    Ingredient(name: "tomato sauce", amount: 400, unit: "ml"),
                    Ingredient(name: "onion", amount: 1, unit: "medium"),
                    Ingredient(name: "garlic", amount: 4, unit: "cloves"),
                    Ingredient(name: "ginger", amount: 2, unit: "tbsp"),
                    Ingredient(name: "turmeric", amount: 1, unit: "tsp"),
                    Ingredient(name: "cumin", amount: 1, unit: "tsp"),
                    Ingredient(name: "coriander", amount: 1, unit: "tsp"),
                    Ingredient(name: "cream", amount: 200, unit: "ml")
                ],
                steps: [
                    CookingStep(stepNumber: 1, description: "Marinate chicken in yogurt and spices", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 2, description: "Sauté onions, garlic, and ginger", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 3, description: "Add tomato sauce and simmer", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 4, description: "Add chicken and cook until done", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 5, description: "Stir in cream and serve", duration: nil, temperature: nil, imageURL: nil, tips: nil)
                ],
                winePairings: [],
                dietaryNotes: [.vegetarian],
                platingTips: "Serve with basmati rice and naan bread",
                chefNotes: "Traditional Indian curry dish",
                imageURL: nil,
                stepImages: [],
                createdAt: Date(),
                isFavorite: false
            ),
            Recipe(
                title: "Margherita Pizza",
                cuisine: .italian,
                difficulty: .easy,
                prepTime: 30,
                cookTime: 15,
                servings: 4,
                ingredients: [
                    Ingredient(name: "pizza dough", amount: 1, unit: "ball"),
                    Ingredient(name: "tomato sauce", amount: 200, unit: "ml"),
                    Ingredient(name: "mozzarella cheese", amount: 200, unit: "g"),
                    Ingredient(name: "basil leaves", amount: 10, unit: "pieces"),
                    Ingredient(name: "olive oil", amount: 2, unit: "tbsp"),
                    Ingredient(name: "salt", amount: 1, unit: "tsp")
                ],
                steps: [
                    CookingStep(stepNumber: 1, description: "Preheat oven to 450°F", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 2, description: "Roll out pizza dough", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 3, description: "Spread tomato sauce", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 4, description: "Add mozzarella cheese", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 5, description: "Bake for 12-15 minutes", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 6, description: "Add fresh basil and serve", duration: nil, temperature: nil, imageURL: nil, tips: nil)
                ],
                winePairings: [],
                dietaryNotes: [.vegetarian],
                platingTips: "Cut into 8 slices and serve hot",
                chefNotes: "Classic Italian pizza",
                imageURL: nil,
                stepImages: [],
                createdAt: Date(),
                isFavorite: false
            ),
            Recipe(
                title: "Beef Tacos",
                cuisine: .mexican,
                difficulty: .easy,
                prepTime: 15,
                cookTime: 20,
                servings: 4,
                ingredients: [
                    Ingredient(name: "ground beef", amount: 500, unit: "g"),
                    Ingredient(name: "taco seasoning", amount: 1, unit: "packet"),
                    Ingredient(name: "tortillas", amount: 8, unit: "pieces"),
                    Ingredient(name: "lettuce", amount: 1, unit: "head"),
                    Ingredient(name: "tomato", amount: 2, unit: "pieces"),
                    Ingredient(name: "onion", amount: 1, unit: "medium"),
                    Ingredient(name: "cheese", amount: 200, unit: "g"),
                    Ingredient(name: "sour cream", amount: 200, unit: "ml")
                ],
                steps: [
                    CookingStep(stepNumber: 1, description: "Brown ground beef in skillet", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 2, description: "Add taco seasoning and water", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 3, description: "Simmer for 5 minutes", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 4, description: "Warm tortillas", duration: nil, temperature: nil, imageURL: nil, tips: nil),
                    CookingStep(stepNumber: 5, description: "Assemble tacos with toppings", duration: nil, temperature: nil, imageURL: nil, tips: nil)
                ],
                winePairings: [],
                dietaryNotes: [],
                platingTips: "Serve with salsa and guacamole",
                chefNotes: "Quick and easy Mexican favorite",
                imageURL: nil,
                stepImages: [],
                createdAt: Date(),
                isFavorite: false
            )
        ]
    }
    
    /// Loads recipes from a specific cuisine file
    private func loadRecipesFromFile(_ fileName: String) async throws -> [Recipe]? {
        guard let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".json", with: ""), 
                                       withExtension: "json") else {
            logger.warning("Recipe file not found: \(fileName)")
            return nil
        }
        
        let data = try Data(contentsOf: url)
        
        // Parse JSON using the standardized new format
        let recipeData = try JSONDecoder().decode(RecipeDatabase.self, from: data)
        
        var recipes: [Recipe] = []
        
        logger.info("Successfully parsed JSON for \(fileName) - found \(recipeData.cuisines.count) cuisines")
        
        for (cuisineName, cuisineRecipes) in recipeData.cuisines {
            logger.info("Processing \(cuisineName) cuisine with \(cuisineRecipes.count) recipes")
            for localRecipeData in cuisineRecipes {
                // All recipes now use the new format
                guard let recipeName = localRecipeData.recipe_name,
                      let recipeIngredients = localRecipeData.ingredients,
                      let cookingTimeCategory = localRecipeData.cooking_time_category,
                      let recipeDifficulty = localRecipeData.difficulty else {
                    logger.warning("Skipping recipe in \(cuisineName) - missing required fields")
                    continue
                }
                
                let title = recipeName
                let ingredients = recipeIngredients
                
                // Handle cooking_instructions as either string or array
                let instructions: String
                if let cookingInstructionsString = localRecipeData.cooking_instructions {
                    instructions = cookingInstructionsString
                } else if let cookingInstructionsArray = localRecipeData.cooking_instructions_array {
                    instructions = cookingInstructionsArray.joined(separator: " ")
                } else {
                    instructions = "No cooking instructions available"
                }
                
                let difficultyString = recipeDifficulty
                
                // Convert cooking_time_category to numeric cooking time
                let cookingTime: Int
                switch cookingTimeCategory.lowercased() {
                case "under 5 min": cookingTime = 5
                case "under 10 min": cookingTime = 10
                case "under 15 min": cookingTime = 15
                case "under 20 min": cookingTime = 20
                case "under 25 min": cookingTime = 25
                case "under 30 min": cookingTime = 30
                case "under 40 min": cookingTime = 40
                case "under 45 min": cookingTime = 45
                case "under 50 min": cookingTime = 50
                case "under 1 hour": cookingTime = 60
                case "under 1.5 hours": cookingTime = 90
                case "under 2 hours": cookingTime = 120
                case "any time": cookingTime = 180
                default: cookingTime = 45
                }
                
                let difficulty = Difficulty(rawValue: difficultyString.lowercased()) ?? .medium
                
                // Parse dietary restrictions
                var dietaryNotes: [DietaryNote] = []
                if let dietaryRestrictions = localRecipeData.dietary_restrictions {
                    for restriction in dietaryRestrictions {
                        if let note = DietaryNote(rawValue: restriction) {
                            dietaryNotes.append(note)
                        }
                    }
                }
                
                // Parse diet_type
                if let dietType = localRecipeData.diet_type {
                    if dietType == "vegetarian" {
                        dietaryNotes.append(.vegetarian)
                    } else if dietType == "vegan" {
                        dietaryNotes.append(.vegan)
                    }
                }
                
                // Parse meal_type and lunchbox_presentation
                let mealType: MealType
                let lunchboxPresentation: String?
                
                if let mealTypeString = localRecipeData.meal_type {
                    mealType = MealType(rawValue: mealTypeString) ?? .regular
                    print("🔍 RECIPE PARSING: '\(title)' -> meal_type: '\(mealTypeString)' -> \(mealType.rawValue)")
                } else {
                    mealType = .regular // Default fallback
                    print("🔍 RECIPE PARSING: '\(title)' -> No meal_type found, defaulting to regular")
                }
                
                lunchboxPresentation = localRecipeData.lunchbox_presentation
                
                // Parse servings
                let servings: Int
                if let servingsValue = localRecipeData.servings {
                    servings = servingsValue
                } else {
                    servings = 4 // Default fallback
                }
                
                let recipe = Recipe(
                    title: title,
                    cuisine: Cuisine(rawValue: cuisineName) ?? .italian,
                    difficulty: difficulty,
                    prepTime: max(1, cookingTime / 4), // Use 1/4 for prep time
                    cookTime: max(1, cookingTime * 3 / 4), // Use 3/4 for cook time
                    servings: servings,
                    ingredients: ingredients.map { parseIngredient(from: $0) },
                    steps: [CookingStep(stepNumber: 1, description: instructions, duration: cookingTime)],
                    winePairings: [],
                    dietaryNotes: dietaryNotes,
                    platingTips: "Serve with traditional \(cuisineName) presentation",
                    chefNotes: "Traditional \(cuisineName) recipe from our database",
                    mealType: mealType,
                    lunchboxPresentation: lunchboxPresentation
                )
                recipes.append(recipe)
            }
        }
        
        return recipes
    }
    
    /// Parses ingredient string to Ingredient object
    private func parseIngredient(from ingredientString: String) -> Ingredient {
        // Try to parse amount and unit from ingredient string
        let components = ingredientString.components(separatedBy: ",")
        let mainPart = components.first ?? ingredientString
        
        // Look for common measurement patterns
        let measurementPattern = "([0-9]+(?:\\.[0-9]+)?)\\s*(cup|tbsp|tsp|oz|lb|g|kg|ml|clove|inch|large|medium|small|piece|slice|can|packet|head|bunch|stalk|tablespoon|teaspoon|pound|gram|kilogram|milliliter|ounce)"
        
        if let regex = try? NSRegularExpression(pattern: measurementPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: mainPart, options: [], range: NSRange(mainPart.startIndex..., in: mainPart)) {
            
            let amountString = String(mainPart[Range(match.range(at: 1), in: mainPart)!])
            let unit = String(mainPart[Range(match.range(at: 2), in: mainPart)!])
            
            // Extract the ingredient name (everything after the measurement)
            let measurementEnd = mainPart.index(mainPart.startIndex, offsetBy: match.range.upperBound)
            let ingredientName = String(mainPart[measurementEnd...]).trimmingCharacters(in: .whitespaces)
            
            return Ingredient(
                name: ingredientName.isEmpty ? mainPart : ingredientName,
                amount: Double(amountString) ?? 1.0,
                unit: unit,
                notes: components.count > 1 ? components.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces) : nil
            )
        }
        
        // Fallback: treat as simple ingredient
        return Ingredient(
            name: mainPart,
            amount: 1.0,
            unit: "piece",
            notes: components.count > 1 ? components.dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces) : nil
        )
    }
    
    /// Parses cooking instructions into detailed steps
    private func parseInstructionsToSteps(_ instructions: String) -> [CookingStep] {
        // Split instructions by sentences or common cooking step indicators
        let sentences = instructions.components(separatedBy: [".", "!", "?"])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var steps: [CookingStep] = []
        
        for (index, sentence) in sentences.enumerated() {
            let stepNumber = index + 1
            let description = sentence.trimmingCharacters(in: .whitespaces)
            
            // Estimate duration based on cooking verbs
            var estimatedDuration: Int = 5
            let lowercasedSentence = description.lowercased()
            
            if lowercasedSentence.contains("marinate") || lowercasedSentence.contains("soak") {
                estimatedDuration = 30
            } else if lowercasedSentence.contains("simmer") || lowercasedSentence.contains("cook") {
                estimatedDuration = 15
            } else if lowercasedSentence.contains("bake") || lowercasedSentence.contains("roast") {
                estimatedDuration = 25
            } else if lowercasedSentence.contains("fry") || lowercasedSentence.contains("sauté") {
                estimatedDuration = 10
            } else if lowercasedSentence.contains("boil") {
                estimatedDuration = 20
            }
            
            let step = CookingStep(
                stepNumber: stepNumber,
                description: description,
                duration: estimatedDuration,
                temperature: nil,
                imageURL: nil,
                tips: nil
            )
            steps.append(step)
        }
        
        // If no steps were created, create a single step with the full instructions
        if steps.isEmpty {
            steps.append(CookingStep(
                stepNumber: 1,
                description: instructions,
                duration: 30,
                temperature: nil,
                imageURL: nil,
                tips: nil
            ))
        }
        
        return steps
    }
    
    /// Gets recipes by cuisine
    func getRecipes(for cuisine: Cuisine) -> [Recipe] {
        return recipes.filter { $0.cuisine == cuisine }
    }
    
    /// Gets all available cuisines
    func getAvailableCuisines() -> [Cuisine] {
        return Array(Set(recipes.map { $0.cuisine })).sorted { $0.rawValue < $1.rawValue }
    }
    
    /// Searches recipes by title or ingredients
    func searchRecipes(query: String) -> [Recipe] {
        let lowercasedQuery = query.lowercased()
        return recipes.filter { recipe in
            recipe.title.lowercased().contains(lowercasedQuery) ||
            recipe.ingredients.contains { $0.name.lowercased().contains(lowercasedQuery) }
        }
    }
    
    /// Gets random recipes for discovery
    func getRandomRecipes(count: Int = 5) -> [Recipe] {
        return Array(recipes.shuffled().prefix(count))
    }
    
    /// Gets recipes by difficulty level
    func getRecipes(by difficulty: Difficulty) -> [Recipe] {
        return recipes.filter { $0.difficulty == difficulty }
    }
    
    /// Gets recipes by cooking time (quick meals under 30 minutes)
    func getQuickRecipes() -> [Recipe] {
        return recipes.filter { $0.prepTime + $0.cookTime <= 30 }
    }
    
    /// Gets recipes by protein type
    func getRecipes(by protein: String) -> [Recipe] {
        let lowercasedProtein = protein.lowercased()
        return recipes.filter { recipe in
            recipe.ingredients.contains { $0.name.lowercased().contains(lowercasedProtein) }
        }
    }
    
    /// Gets all available protein types
    func getAvailableProteins() -> [String] {
        let allProteins = recipes.flatMap { $0.ingredients }.map { $0.name }.filter { ingredientName in
            let proteinKeywords = ["chicken", "beef", "pork", "lamb", "fish", "shrimp", "salmon", "tuna", "clams", "cheese", "egg", "tofu", "paneer", "lentils", "beans"]
            return proteinKeywords.contains { ingredientName.lowercased().contains($0) }
        }
        return Array(Set(allProteins)).sorted()
    }
    

    
    /// Gets recipe statistics
    func getRecipeStats() -> RecipeStats {
        let totalRecipes = recipes.count
        let cuisines = getAvailableCuisines()
        let difficulties = Dictionary(grouping: recipes, by: { $0.difficulty })
        
        return RecipeStats(
            totalRecipes: totalRecipes,
            totalCuisines: cuisines.count,
            recipesByDifficulty: difficulties.mapValues { $0.count },
            averagePrepTime: recipes.map { $0.prepTime }.reduce(0, +) / max(recipes.count, 1),
            averageCookTime: recipes.map { $0.cookTime }.reduce(0, +) / max(recipes.count, 1)
        )
    }
    
    

}

// MARK: - Data Models

struct RecipeDatabase: Codable {
    let cuisines: [String: [LocalRecipeData]]
}

struct LocalRecipeData: Codable {
    let title: String?
    let recipe_name: String?
    let cuisine: String?
    let ingredients: [String]?
    let instructions: String?
    let cooking_instructions: String?
    let cooking_instructions_array: [String]?
    let proteins: [String]?
    let dietary_restrictions: [String]?
    let cooking_time: Int?
    let cooking_time_category: String?
    let difficulty: String?
    let meal_type: String?
    let lunchbox_presentation: String?
    let servings: Int?
    let diet_type: String?
}

struct RecipeStats {
    let totalRecipes: Int
    let totalCuisines: Int
    let recipesByDifficulty: [Difficulty: Int]
    let averagePrepTime: Int
    let averageCookTime: Int
} 

