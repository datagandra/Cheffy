import Foundation
import os.log

/// Service for managing the comprehensive recipe database
class RecipeDatabaseService: ObservableObject {
    static let shared = RecipeDatabaseService()
    
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let logger = Logger()
    
    // MARK: - Recipe Database Management
    
    /// Loads all recipes from the local database files
    func loadAllRecipes() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            var allRecipes: [Recipe] = []
            
            // Load recipes from each cuisine file
            let cuisineFiles = [
                "asian_cuisines.json",
                "mediterranean_cuisines.json",
                "indian_cuisines.json",
                "american_cuisines.json",
                "mexican_cuisines.json"
                // Add more files as they're created
            ]
            
            for fileName in cuisineFiles {
                if let recipes = try await loadRecipesFromFile(fileName) {
                    allRecipes.append(contentsOf: recipes)
                }
            }
            
            await MainActor.run {
                self.recipes = allRecipes
                self.isLoading = false
                logger.info("Loaded \(allRecipes.count) recipes from database")
            }
            
        } catch {
            await MainActor.run {
                self.error = "Failed to load recipes: \(error.localizedDescription)"
                self.isLoading = false
                logger.error("Failed to load recipes: \(error)")
            }
        }
    }
    
    /// Loads recipes from a specific cuisine file
    private func loadRecipesFromFile(_ fileName: String) async throws -> [Recipe]? {
        guard let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".json", with: ""), 
                                       withExtension: "json", 
                                       subdirectory: "recipes") else {
            logger.warning("Recipe file not found: \(fileName)")
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let recipeData = try JSONDecoder().decode(RecipeDatabase.self, from: data)
        
        var recipes: [Recipe] = []
        
        for (cuisineName, cuisineRecipes) in recipeData.cuisines {
            for recipeData in cuisineRecipes {
                let recipe = Recipe(
                    id: UUID(),
                    title: recipeData.title,
                    cuisine: Cuisine(rawValue: cuisineName) ?? .other,
                    ingredients: recipeData.ingredients,
                    instructions: recipeData.instructions,
                    difficulty: Difficulty(rawValue: recipeData.difficulty ?? "medium") ?? .medium,
                    prepTime: 15, // Default prep time
                    cookTime: recipeData.cooking_time ?? 45, // Use provided cooking time or default
                    servings: 4, // Default servings
                    imageURL: nil,
                    isFavorite: false,
                    createdAt: Date(),
                    tags: [cuisineName.lowercased()] + (recipeData.proteins ?? [])
                )
                recipes.append(recipe)
            }
        }
        
        return recipes
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
            recipe.ingredients.contains { $0.lowercased().contains(lowercasedQuery) } ||
            recipe.tags.contains { $0.lowercased().contains(lowercasedQuery) }
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
            recipe.tags.contains { $0.lowercased().contains(lowercasedProtein) } ||
            recipe.ingredients.contains { $0.lowercased().contains(lowercasedProtein) }
        }
    }
    
    /// Gets all available protein types
    func getAvailableProteins() -> [String] {
        let allProteins = recipes.flatMap { $0.tags }.filter { tag in
            let proteinKeywords = ["chicken", "beef", "pork", "lamb", "fish", "shrimp", "salmon", "tuna", "clams", "cheese", "egg", "tofu", "paneer", "lentils", "beans"]
            return proteinKeywords.contains { tag.lowercased().contains($0) }
        }
        return Array(Set(allProteins)).sorted()
    }
    
    /// Gets recipes by dietary restrictions
    func getRecipes(for dietaryRestrictions: [DietaryNote]) -> [Recipe] {
        return recipes.filter { recipe in
            // Get dietary restrictions from recipe data if available
            let recipeData = getRecipeData(for: recipe)
            let recipeRestrictions = recipeData?.dietary_restrictions ?? []
            let ingredients = recipe.ingredients.joined(separator: " ").lowercased()
            
            for restriction in dietaryRestrictions {
                // Check explicit dietary restrictions first
                let restrictionString = restriction.rawValue.lowercased()
                if recipeRestrictions.contains(restrictionString) {
                    continue // Recipe explicitly supports this restriction
                }
                
                // Fallback to ingredient-based filtering
                switch restriction {
                case .vegetarian:
                    if ingredients.contains("chicken") || ingredients.contains("beef") || 
                       ingredients.contains("pork") || ingredients.contains("lamb") ||
                       ingredients.contains("fish") || ingredients.contains("shrimp") ||
                       ingredients.contains("clams") {
                        return false
                    }
                case .vegan:
                    if ingredients.contains("chicken") || ingredients.contains("beef") || 
                       ingredients.contains("pork") || ingredients.contains("lamb") ||
                       ingredients.contains("fish") || ingredients.contains("shrimp") ||
                       ingredients.contains("clams") || ingredients.contains("cheese") || 
                       ingredients.contains("milk") || ingredients.contains("cream") ||
                       ingredients.contains("butter") || ingredients.contains("egg") ||
                       ingredients.contains("yogurt") {
                        return false
                    }
                case .glutenFree:
                    if ingredients.contains("flour") || ingredients.contains("bread") ||
                       ingredients.contains("pasta") || ingredients.contains("wheat") ||
                       ingredients.contains("all-purpose") || ingredients.contains("bun") ||
                       ingredients.contains("tortilla") {
                        return false
                    }
                case .dairyFree:
                    if ingredients.contains("cheese") || ingredients.contains("milk") ||
                       ingredients.contains("cream") || ingredients.contains("butter") ||
                       ingredients.contains("yogurt") || ingredients.contains("sour cream") ||
                       ingredients.contains("condensed milk") || ingredients.contains("evaporated milk") {
                        return false
                    }
                case .nutFree:
                    if ingredients.contains("peanut") || ingredients.contains("almond") ||
                       ingredients.contains("walnut") || ingredients.contains("cashew") ||
                       ingredients.contains("pistachio") || ingredients.contains("pine nut") ||
                       ingredients.contains("pecan") {
                        return false
                    }
                default:
                    break
                }
            }
            return true
        }
    }
    
    /// Helper function to get recipe data for dietary restrictions
    private func getRecipeData(for recipe: Recipe) -> RecipeData? {
        // This would need to be implemented to access the original recipe data
        // For now, we'll use ingredient-based filtering
        return nil
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
    let cuisines: [String: [RecipeData]]
}

struct RecipeData: Codable {
    let title: String
    let cuisine: String
    let ingredients: [String]
    let instructions: String
    let proteins: [String]?
    let dietary_restrictions: [String]?
    let cooking_time: Int?
    let difficulty: String?
}

struct RecipeStats {
    let totalRecipes: Int
    let totalCuisines: Int
    let recipesByDifficulty: [Difficulty: Int]
    let averagePrepTime: Int
    let averageCookTime: Int
} 