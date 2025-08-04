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
        print("🔄 Attempting to cache recipe: \(recipe.name)")
        
        // Check if recipe already exists in cache
        if let existingIndex = cachedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            // Update existing recipe
            cachedRecipes[existingIndex] = recipe
            print("📝 Updated existing recipe in cache: \(recipe.name)")
        } else {
            // Add new recipe to cache
            cachedRecipes.append(recipe)
            print("➕ Added new recipe to cache: \(recipe.name)")
        }
        
        // Add to recently viewed
        addToRecentlyViewed(recipe)
        
        // Save to persistent storage
        saveCachedRecipes()
        saveRecentlyViewedRecipes()
        
        print("✅ Successfully cached recipe: \(recipe.name)")
        print("📊 Current cache size: \(cachedRecipes.count)/\(maxCacheSize)")
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
        print("🗑️ Removed from cache: \(recipe.name)")
    }
    
    /// Clears all cached recipes
    func clearCache() {
        cachedRecipes.removeAll()
        saveCachedRecipes()
        print("🗑️ Cleared all cached recipes")
    }
    
    /// Removes expired recipes from cache
    func cleanExpiredCache() {
        let expirationDate = Calendar.current.date(byAdding: .day, value: -cacheExpirationDays, to: Date()) ?? Date()
        cachedRecipes.removeAll { recipe in
            recipe.createdAt < expirationDate
        }
        saveCachedRecipes()
        print("🧹 Cleaned expired cache entries")
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
        print("📝 Cached cooking instructions for recipe: \(recipeId)")
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
            print("💾 Saved \(cachedRecipes.count) recipes to UserDefaults")
        } catch {
            print("❌ Error saving cached recipes: \(error)")
        }
    }
    
    /// Loads cached recipes from UserDefaults
    private func loadCachedRecipes() {
        guard let data = UserDefaults.standard.data(forKey: "cached_recipes") else {
            cachedRecipes = []
            print("📱 No cached recipes found in UserDefaults")
            return
        }
        
        do {
            cachedRecipes = try JSONDecoder().decode([Recipe].self, from: data)
            print("📱 Loaded \(cachedRecipes.count) recipes from UserDefaults")
        } catch {
            print("❌ Error loading cached recipes: \(error)")
            cachedRecipes = []
        }
    }
    
    /// Saves recently viewed recipes to UserDefaults
    private func saveRecentlyViewedRecipes() {
        do {
            let data = try JSONEncoder().encode(recentlyViewedRecipes)
            UserDefaults.standard.set(data, forKey: "recently_viewed_recipes")
        } catch {
            print("❌ Error saving recently viewed recipes: \(error)")
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
            print("❌ Error loading recently viewed recipes: \(error)")
            recentlyViewedRecipes = []
        }
    }
} 