import Foundation
import CoreData
import Combine

// MARK: - Recipe Cache Manager
class RecipeCacheManager: ObservableObject {
    static let shared = RecipeCacheManager()
    
    @Published var cachedRecipes: [Recipe] = []
    @Published var recentlyViewedRecipes: [Recipe] = []
    
    private let maxCacheSize = Int.max // No limit on cached recipes
    private let maxRecentlyViewed = Int.max // No limit on recently viewed recipes
    private let cacheExpirationDays = 30 // Days before cache expires
    
    private init() {
        loadCachedRecipes()
        loadRecentlyViewedRecipes()
    }
    
    // MARK: - Recipe Caching
    
    /// Caches a recipe locally for offline access
    /// - Parameter recipe: The recipe to cache
    func cacheRecipe(_ recipe: Recipe) {
        logger.cache("Attempting to cache recipe: \(recipe.name)")
        
        // Check if recipe already exists in cache
        if let existingIndex = cachedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            // Update existing recipe
            cachedRecipes[existingIndex] = recipe
            logger.cache("Updated existing recipe in cache: \(recipe.name)")
        } else {
            // Check for similar recipes to prevent duplicates
            if let similarRecipe = findSimilarRecipe(recipe) {
                logger.cache("Similar recipe already exists: \(similarRecipe.name) - skipping duplicate")
                return
            }
            
            // Add new recipe to cache
            cachedRecipes.append(recipe)
            logger.cache("Added new recipe to cache: \(recipe.name)")
        }
        
        // Add to recently viewed
        addToRecentlyViewed(recipe)
        
        // Save to persistent storage
        saveCachedRecipes()
        saveRecentlyViewedRecipes()
        
        logger.cache("Successfully cached recipe: \(recipe.name)")
        logger.cache("Current cache size: \(cachedRecipes.count)/\(maxCacheSize)")
    }
    
    /// Caches multiple recipes at once
    /// - Parameter recipes: Array of recipes to cache
    func cacheRecipes(_ recipes: [Recipe]) {
        for recipe in recipes {
            cacheRecipe(recipe)
        }
    }
    
    /// Retrieves a cached recipe by ID
    /// - Parameter id: The recipe ID
    /// - Returns: The cached recipe if found, nil otherwise
    func getCachedRecipe(id: UUID) -> Recipe? {
        return cachedRecipes.first { $0.id == id }
    }
    
    /// Retrieves cached recipes by cuisine
    /// - Parameter cuisine: The cuisine type
    /// - Returns: Array of cached recipes for the specified cuisine
    func getCachedRecipes(cuisine: Cuisine) -> [Recipe] {
        return cachedRecipes.filter { $0.cuisine == cuisine }
    }
    
    /// Retrieves cached recipes by difficulty
    /// - Parameter difficulty: The difficulty level
    /// - Returns: Array of cached recipes for the specified difficulty
    func getCachedRecipes(difficulty: Difficulty) -> [Recipe] {
        return cachedRecipes.filter { $0.difficulty == difficulty }
    }
    
    /// Searches cached recipes by name
    /// - Parameter query: The search query
    /// - Returns: Array of cached recipes matching the query
    func searchCachedRecipes(query: String) -> [Recipe] {
        let lowercasedQuery = query.lowercased()
        return cachedRecipes.filter { recipe in
            recipe.name.lowercased().contains(lowercasedQuery) ||
            recipe.ingredients.contains { ingredient in
                ingredient.name.lowercased().contains(lowercasedQuery)
            }
        }
    }
    
    /// Removes a recipe from cache
    /// - Parameter recipe: The recipe to remove
    func removeFromCache(_ recipe: Recipe) {
        cachedRecipes.removeAll { $0.id == recipe.id }
        saveCachedRecipes()
        logger.cache("Removed from cache: \(recipe.name)")
    }
    
    /// Clears all cached recipes
    func clearCache() {
        cachedRecipes.removeAll()
        saveCachedRecipes()
        logger.cache("Cleared all cached recipes")
    }
    
    /// Removes expired recipes from cache
    func cleanExpiredCache() {
        let expirationDate = Calendar.current.date(byAdding: .day, value: -cacheExpirationDays, to: Date()) ?? Date()
        cachedRecipes.removeAll { recipe in
            recipe.createdAt < expirationDate
        }
        saveCachedRecipes()
        logger.cache("Cleaned expired cache entries")
    }
    
    // MARK: - Recently Viewed Recipes
    
    /// Adds a recipe to recently viewed list
    /// - Parameter recipe: The recipe to add
    private func addToRecentlyViewed(_ recipe: Recipe) {
        // Remove if already exists
        recentlyViewedRecipes.removeAll { $0.id == recipe.id }
        
        // Add to beginning
        recentlyViewedRecipes.insert(recipe, at: 0)
    }
    
    /// Gets recently viewed recipes
    /// - Returns: Array of recently viewed recipes
    func getRecentlyViewedRecipes() -> [Recipe] {
        return recentlyViewedRecipes
    }
    
    // MARK: - Cooking Instructions Caching
    
    /// Caches cooking instructions for a recipe
    /// - Parameters:
    ///   - recipeId: The recipe ID
    ///   - instructions: The cooking instructions
    func cacheCookingInstructions(recipeId: UUID, instructions: String) {
        let key = "cooking_instructions_\(recipeId.uuidString)"
        UserDefaults.standard.set(instructions, forKey: key)
        logger.cache("Cached cooking instructions for recipe: \(recipeId)")
    }
    
    /// Retrieves cached cooking instructions for a recipe
    /// - Parameter recipeId: The recipe ID
    /// - Returns: The cached cooking instructions if available
    func getCachedCookingInstructions(recipeId: UUID) -> String? {
        let key = "cooking_instructions_\(recipeId.uuidString)"
        return UserDefaults.standard.string(forKey: key)
    }
    
    /// Removes cached cooking instructions for a recipe
    /// - Parameter recipeId: The recipe ID
    func removeCachedCookingInstructions(recipeId: UUID) {
        let key = "cooking_instructions_\(recipeId.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - Cache Statistics
    
    /// Gets cache statistics
    /// - Returns: Dictionary with cache statistics
    func getCacheStatistics() -> [String: Any] {
        let totalCached = cachedRecipes.count
        let recentlyViewed = recentlyViewedRecipes.count
        let cacheSize = getCacheSizeInMB()
        
        return [
            "totalCached": totalCached,
            "recentlyViewed": recentlyViewed,
            "cacheSizeMB": cacheSize,
            "maxCacheSize": maxCacheSize,
            "cacheExpirationDays": cacheExpirationDays
        ]
    }
    
    /// Calculates cache size in MB
    /// - Returns: Cache size in megabytes
    private func getCacheSizeInMB() -> Double {
        // This is a rough estimation
        let estimatedSizePerRecipe = 1024 // 1KB per recipe
        let totalSize = cachedRecipes.count * estimatedSizePerRecipe
        return Double(totalSize) / 1024.0 / 1024.0 // Convert to MB
    }
    
    // MARK: - Persistence
    
    /// Saves cached recipes to UserDefaults
    private func saveCachedRecipes() {
        do {
            let data = try JSONEncoder().encode(cachedRecipes)
            UserDefaults.standard.set(data, forKey: "cached_recipes")
            logger.cache("Saved \(cachedRecipes.count) recipes to UserDefaults")
        } catch {
            logger.error("Error saving cached recipes: \(error)")
        }
    }
    
    /// Loads cached recipes from UserDefaults
    private func loadCachedRecipes() {
        guard let data = UserDefaults.standard.data(forKey: "cached_recipes") else {
            cachedRecipes = []
            logger.cache("No cached recipes found in UserDefaults")
            return
        }
        
        do {
            cachedRecipes = try JSONDecoder().decode([Recipe].self, from: data)
            logger.cache("Loaded \(cachedRecipes.count) recipes from UserDefaults")
        } catch {
            logger.error("Error loading cached recipes: \(error)")
            cachedRecipes = []
        }
    }
    
    /// Saves recently viewed recipes to UserDefaults
    private func saveRecentlyViewedRecipes() {
        do {
            let data = try JSONEncoder().encode(recentlyViewedRecipes)
            UserDefaults.standard.set(data, forKey: "recently_viewed_recipes")
        } catch {
            logger.error("Error saving recently viewed recipes: \(error)")
        }
    }
    
    /// Loads recently viewed recipes from UserDefaults
    private func loadRecentlyViewedRecipes() {
        guard let data = UserDefaults.standard.data(forKey: "recently_viewed_recipes") else {
            recentlyViewedRecipes = []
            return
        }
        
        do {
            recentlyViewedRecipes = try JSONDecoder().decode([Recipe].self, from: data)
        } catch {
            logger.error("Error loading recently viewed recipes: \(error)")
            recentlyViewedRecipes = []
        }
    }
    
    /// Finds similar recipes to prevent duplicates
    /// - Parameter recipe: The recipe to check for similarity
    /// - Returns: A similar recipe if found, nil otherwise
    private func findSimilarRecipe(_ recipe: Recipe) -> Recipe? {
        return cachedRecipes.first { existingRecipe in
            // Check for exact name match (case-insensitive)
            if existingRecipe.name.lowercased() == recipe.name.lowercased() {
                return true
            }
            
            // Check for very similar names (90% similarity)
            let similarity = calculateNameSimilarity(existingRecipe.name, recipe.name)
            if similarity > 0.9 {
                return true
            }
            
            // Check for same cuisine, difficulty, and similar ingredients
            if existingRecipe.cuisine == recipe.cuisine &&
               existingRecipe.difficulty == recipe.difficulty {
                let ingredientSimilarity = calculateIngredientSimilarity(existingRecipe.ingredients, recipe.ingredients)
                if ingredientSimilarity > 0.8 {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Calculates name similarity between two recipe names
    /// - Parameters: Two recipe names to compare
    /// - Returns: Similarity score between 0 and 1
    private func calculateNameSimilarity(_ name1: String, _ name2: String) -> Double {
        let words1 = Set(name1.lowercased().split(separator: " ").map(String.init))
        let words2 = Set(name2.lowercased().split(separator: " ").map(String.init))
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    /// Calculates ingredient similarity between two ingredient lists
    /// - Parameters: Two ingredient lists to compare
    /// - Returns: Similarity score between 0 and 1
    private func calculateIngredientSimilarity(_ ingredients1: [Ingredient], _ ingredients2: [Ingredient]) -> Double {
        let names1 = Set(ingredients1.map { $0.name.lowercased() })
        let names2 = Set(ingredients2.map { $0.name.lowercased() })
        
        let intersection = names1.intersection(names2).count
        let union = names1.union(names2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
} 