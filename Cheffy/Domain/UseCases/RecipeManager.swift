import Foundation
import Combine

class RecipeManager: ObservableObject {
    let openAIClient = OpenAIClient()
    let cacheManager = RecipeCacheManager.shared
    
    @Published var generatedRecipe: Recipe?
    @Published var popularRecipes: [Recipe] = []
    @Published var favorites: [Recipe] = []
    @Published var cachedRecipes: [Recipe] = []
    @Published var recentlyViewedRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var generationCount = 0
    @Published var showSavedMessage = false
    @Published var isUsingCachedData = false
    
    // Track last used dietary restrictions for change detection
    private var lastUsedDietaryRestrictions: [DietaryNote] = []
    
    init() {
        
        loadGenerationCount()
        loadFavorites()
        loadCachedData()
        
        // Print cache status on initialization
        print("📱 RecipeManager initialized with \(cachedRecipes.count) cached recipes")
        if !cachedRecipes.isEmpty {
            print("📱 Available cached recipes:")
            for recipe in cachedRecipes {
                print("   - \(recipe.name) (\(recipe.cuisine.rawValue))")
            }
        }
    }
    
    func generateRecipe(
        userPrompt: String? = nil,
        recipeName: String? = nil,
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        ingredients: [String]? = nil,
        maxTime: Int? = nil,
        servings: Int = 2
    ) async {
        isLoading = true
        error = nil
        
        // Clear existing recipe before generating new one
        await MainActor.run {
            self.generatedRecipe = nil
        }
        
        // First, try to find a cached recipe that matches the criteria
        let cachedRecipe = findCachedRecipe(
            userPrompt: userPrompt,
            recipeName: recipeName,
            cuisine: cuisine,
            difficulty: difficulty,
            dietaryRestrictions: dietaryRestrictions,
            ingredients: ingredients,
            maxTime: maxTime,
            servings: servings
        )
        
        if let cachedRecipe = cachedRecipe {
            // Use cached recipe
            await MainActor.run {
                self.generatedRecipe = cachedRecipe
                self.isUsingCachedData = true
                print("📱 Using cached recipe: \(cachedRecipe.name)")
                print("✅ Recipe loaded from cache - no LLM connection needed")
            }
        } else {
            // No cached recipe found, generate new one from LLM
            print("🔄 No cached recipe found, connecting to LLM...")
            
            do {
                let recipe = try await openAIClient.generateRecipe(
                    userPrompt: userPrompt,
                    recipeName: recipeName,
                    cuisine: cuisine,
                    difficulty: difficulty,
                    dietaryRestrictions: dietaryRestrictions,
                    ingredients: ingredients,
                    maxTime: maxTime,
                    servings: servings
                )
                
                await MainActor.run {
                    self.generatedRecipe = recipe
                    self.incrementGenerationCount()
                    self.isUsingCachedData = false
                    
                    // Update dietary restrictions tracking
                    self.updateLastUsedDietaryRestrictions(dietaryRestrictions)
                    
                    // Cache the generated recipe
                    print("🔄 RecipeManager: Caching generated recipe: \(recipe.name)")
                    self.cacheManager.cacheRecipe(recipe)
                    self.updateCachedData()
                    print("✅ RecipeManager: Recipe cached successfully")
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func generatePopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int? = nil,
        servings: Int = 2
    ) async {
        isLoading = true
        error = nil
        
        // Clear existing recipes before generating new ones
        await MainActor.run {
            self.popularRecipes = []
        }
        
        // Check if dietary restrictions have changed significantly
        let cachedRecipes: [Recipe]
        if hasDietaryRestrictionsChanged(dietaryRestrictions) {
            print("⚠️ Dietary restrictions changed for popular recipes - will connect to LLM for fresh recipes")
            // Force LLM generation by setting cached recipes to empty
            cachedRecipes = []
        } else {
            // First, try to find cached recipes that match the criteria
            cachedRecipes = findCachedPopularRecipes(
                cuisine: cuisine,
                difficulty: difficulty,
                dietaryRestrictions: dietaryRestrictions,
                maxTime: maxTime,
                servings: servings
            )
        }
        
        if !cachedRecipes.isEmpty {
            // Use cached recipes if we have any
            await MainActor.run {
                self.popularRecipes = Array(cachedRecipes.prefix(10))
                self.isUsingCachedData = true
                print("📱 Using \(self.popularRecipes.count) cached recipes")
                print("✅ Recipes loaded from cache - no LLM connection needed")
            }
        } else {
            // No cached recipes, generate new ones from LLM
            print("🔄 No cached recipes found, connecting to LLM...")
            
            do {
                let recipes = try await openAIClient.generatePopularRecipes(
                    cuisine: cuisine,
                    difficulty: difficulty,
                    dietaryRestrictions: dietaryRestrictions,
                    maxTime: maxTime,
                    servings: servings
                )
                
                await MainActor.run {
                    self.popularRecipes = recipes
                    self.incrementGenerationCount()
                    self.isUsingCachedData = false
                    
                    // Update dietary restrictions tracking
                    self.updateLastUsedDietaryRestrictions(dietaryRestrictions)
                    
                    // Cache all generated recipes
                    print("🔄 RecipeManager: Caching \(recipes.count) generated recipes")
                    self.cacheManager.cacheRecipes(recipes)
                    self.updateCachedData()
                    print("✅ RecipeManager: All recipes cached successfully")
                }
                            } catch {
                    await MainActor.run {
                        self.error = error.localizedDescription
                        print("❌ Error generating popular recipes: \(error)")
                    }
                }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func saveToFavorites(_ recipe: Recipe) {
        if !favorites.contains(where: { $0.id == recipe.id }) {
            var updatedRecipe = recipe
            updatedRecipe.isFavorite = true
            favorites.append(updatedRecipe)
            saveFavorites()
            
            // Show saved message
            showSavedMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showSavedMessage = false
            }
        }
    }
    
    func removeFromFavorites(_ recipe: Recipe) {
        favorites.removeAll { $0.id == recipe.id }
        saveFavorites()
    }
    
    func toggleFavorite(_ recipe: Recipe) {
        if favorites.contains(where: { $0.id == recipe.id }) {
            removeFromFavorites(recipe)
        } else {
            saveToFavorites(recipe)
        }
    }
    
    func isFavorite(_ recipe: Recipe) -> Bool {
        return favorites.contains(where: { $0.id == recipe.id })
    }
    
    private func loadGenerationCount() {
        generationCount = UserDefaults.standard.integer(forKey: "generation_count")
    }
    
    private func incrementGenerationCount() {
        generationCount += 1
        UserDefaults.standard.set(generationCount, forKey: "generation_count")
    }
    
    func resetGenerationCount() {
        generationCount = 0
        UserDefaults.standard.set(0, forKey: "generation_count")
    }
    
    // MARK: - Favorites Persistence
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: "favorites")
        } catch {
            print("❌ Error saving favorites: \(error)")
        }
    }
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: "favorites") else {
            favorites = []
            return
        }
        
        do {
            favorites = try JSONDecoder().decode([Recipe].self, from: data)
        } catch {
            print("❌ Error loading favorites: \(error)")
            favorites = []
        }
    }
    
    // MARK: - Ingredient Analysis and Text Extraction
    
    /// Extracts all ingredients from current recipes and formats them as text
    /// - Returns: Formatted text containing all ingredients with their details
    func extractAllIngredientsAsText() -> String {
        let allRecipes = popularRecipes + (generatedRecipe != nil ? [generatedRecipe!] : [])
        return openAIClient.extractAllIngredientsAsText(from: allRecipes)
    }
    
    /// Analyzes current recipes and identifies all filter criteria violations
    /// - Returns: Detailed analysis of filter criteria violations
    func analyzeFilterCriteriaViolations() -> String {
        let allRecipes = popularRecipes + (generatedRecipe != nil ? [generatedRecipe!] : [])
        return openAIClient.analyzeFilterCriteriaViolations(in: allRecipes)
    }
    
    /// Parses JSON recipe data and converts to formatted text
    /// - Parameter jsonData: JSON data containing recipe information
    /// - Returns: Formatted text representation of the recipes
    func parseRecipesFromJSONToText(_ jsonData: Data) -> String {
        return openAIClient.parseRecipesFromJSONToText(jsonData)
    }
    
    /// Gets a comprehensive analysis of all current recipes including ingredients and filter violations
    /// - Returns: Complete analysis text
    func getCompleteRecipeAnalysis() -> String {
        var analysis = "🔍 COMPLETE RECIPE ANALYSIS\n"
        analysis += String(repeating: "=", count: 50) + "\n\n"
        
        // Add ingredient extraction
        analysis += extractAllIngredientsAsText()
        analysis += "\n\n"
        
        // Add filter criteria analysis
        analysis += analyzeFilterCriteriaViolations()
        
        return analysis
    }
    
    // MARK: - Cache Management
    
    /// Loads cached data from cache manager
    private func loadCachedData() {
        cachedRecipes = cacheManager.cachedRecipes
        recentlyViewedRecipes = cacheManager.recentlyViewedRecipes
    }
    
    /// Updates cached data from cache manager
    private func updateCachedData() {
        cachedRecipes = cacheManager.cachedRecipes
        recentlyViewedRecipes = cacheManager.recentlyViewedRecipes
    }
    
    /// Gets a cached recipe by ID
    /// - Parameter id: The recipe ID
    /// - Returns: The cached recipe if found, nil otherwise
    func getCachedRecipe(id: UUID) -> Recipe? {
        return cacheManager.getCachedRecipe(id: id)
    }
    
    /// Gets cached recipes by cuisine
    /// - Parameter cuisine: The cuisine type
    /// - Returns: Array of cached recipes for the specified cuisine
    func getCachedRecipes(cuisine: Cuisine) -> [Recipe] {
        return cacheManager.getCachedRecipes(cuisine: cuisine)
    }
    
    /// Gets cached recipes by difficulty
    /// - Parameter difficulty: The difficulty level
    /// - Returns: Array of cached recipes for the specified difficulty
    func getCachedRecipes(difficulty: Difficulty) -> [Recipe] {
        return cacheManager.getCachedRecipes(difficulty: difficulty)
    }
    
    /// Searches cached recipes
    /// - Parameter query: The search query
    /// - Returns: Array of cached recipes matching the query
    func searchCachedRecipes(query: String) -> [Recipe] {
        return cacheManager.searchCachedRecipes(query: query)
    }
    
    /// Gets recently viewed recipes
    /// - Returns: Array of recently viewed recipes
    func getRecentlyViewedRecipes() -> [Recipe] {
        return cacheManager.getRecentlyViewedRecipes()
    }
    
    /// Caches cooking instructions for a recipe
    /// - Parameters:
    ///   - recipeId: The recipe ID
    ///   - instructions: The cooking instructions
    func cacheCookingInstructions(recipeId: UUID, instructions: String) {
        cacheManager.cacheCookingInstructions(recipeId: recipeId, instructions: instructions)
    }
    
    /// Gets cached cooking instructions for a recipe
    /// - Parameter recipeId: The recipe ID
    /// - Returns: The cached cooking instructions if available
    func getCachedCookingInstructions(recipeId: UUID) -> String? {
        return cacheManager.getCachedCookingInstructions(recipeId: recipeId)
    }
    
    /// Removes a recipe from cache
    /// - Parameter recipe: The recipe to remove
    func removeFromCache(_ recipe: Recipe) {
        cacheManager.removeFromCache(recipe)
        updateCachedData()
    }
    
    /// Clears all cached recipes
    func clearCache() {
        cacheManager.clearCache()
        updateCachedData()
    }
    
    /// Cleans expired cache entries
    func cleanExpiredCache() {
        cacheManager.cleanExpiredCache()
        updateCachedData()
    }
    
    /// Gets cache statistics
    /// - Returns: Dictionary with cache statistics
    func getCacheStatistics() -> [String: Any] {
        return cacheManager.getCacheStatistics()
    }
    
    /// Checks if a recipe is cached
    /// - Parameter recipe: The recipe to check
    /// - Returns: True if the recipe is cached
    func isCached(_ recipe: Recipe) -> Bool {
        return cacheManager.getCachedRecipe(id: recipe.id) != nil
    }
    
    /// Loads cached recipes when offline or for faster access
    /// - Parameters:
    ///   - cuisine: Optional cuisine filter
    ///   - difficulty: Optional difficulty filter
    ///   - query: Optional search query
    func loadCachedRecipes(cuisine: Cuisine? = nil, difficulty: Difficulty? = nil, query: String? = nil) {
        var recipes: [Recipe] = []
        
        if let query = query, !query.isEmpty {
            recipes = searchCachedRecipes(query: query)
        } else if let cuisine = cuisine {
            recipes = getCachedRecipes(cuisine: cuisine)
        } else if let difficulty = difficulty {
            recipes = getCachedRecipes(difficulty: difficulty)
        } else {
            recipes = cachedRecipes
        }
        
        if !recipes.isEmpty {
            popularRecipes = recipes
            isUsingCachedData = true
            print("📱 Loaded \(recipes.count) cached recipes")
        } else {
            print("📱 No cached recipes found")
        }
    }
    
    /// Checks if there are any cached recipes available
    /// - Returns: True if there are cached recipes
    func hasCachedRecipes() -> Bool {
        return !cachedRecipes.isEmpty
    }
    
    /// Gets the total number of cached recipes
    /// - Returns: Number of cached recipes
    func getCachedRecipesCount() -> Int {
        return cachedRecipes.count
    }
    
    /// Loads all cached recipes without any filters
    func loadAllCachedRecipes() {
        if !cachedRecipes.isEmpty {
            popularRecipes = cachedRecipes
            isUsingCachedData = true
            print("📱 Loaded all \(cachedRecipes.count) cached recipes")
        } else {
            print("📱 No cached recipes available")
        }
    }
    
    // MARK: - Smart Caching Logic
    
    /// Finds a cached recipe that matches the given criteria
    /// - Parameters: All the recipe generation parameters
    /// - Returns: A matching cached recipe if found, nil otherwise
    private func findCachedRecipe(
        userPrompt: String?,
        recipeName: String?,
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        ingredients: [String]?,
        maxTime: Int?,
        servings: Int
    ) -> Recipe? {
        print("🔍 Searching for cached recipe matching criteria...")
        print("   - Cuisine: \(cuisine.rawValue)")
        print("   - Difficulty: \(difficulty.rawValue)")
        print("   - Servings: \(servings)")
        print("   - Dietary restrictions: \(dietaryRestrictions.count)")
        
        // Check if dietary restrictions have changed significantly
        if hasDietaryRestrictionsChanged(dietaryRestrictions) {
            print("⚠️ Dietary restrictions changed - will connect to LLM for fresh recipe")
            return nil
        }
        
        // Filter cached recipes by basic criteria
        var matchingRecipes = cachedRecipes.filter { recipe in
            recipe.cuisine == cuisine &&
            recipe.difficulty == difficulty &&
            recipe.servings == servings
        }
        
        print("📊 Found \(matchingRecipes.count) recipes matching basic criteria")
        
        // If we have a specific recipe name, prioritize exact matches
        if let recipeName = recipeName, !recipeName.isEmpty {
            let exactMatches = matchingRecipes.filter { recipe in
                recipe.name.lowercased().contains(recipeName.lowercased())
            }
            if !exactMatches.isEmpty {
                print("🎯 Found exact name match: \(exactMatches.first!.name)")
                return exactMatches.first
            }
        }
        
        // Filter by dietary restrictions if specified
        if !dietaryRestrictions.isEmpty {
            matchingRecipes = matchingRecipes.filter { recipe in
                let recipeDietaryNotes = Set(recipe.dietaryNotes)
                let requestedDietaryNotes = Set(dietaryRestrictions)
                return recipeDietaryNotes.isSuperset(of: requestedDietaryNotes)
            }
            print("📊 After dietary filter: \(matchingRecipes.count) recipes")
        }
        
        // Filter by max time if specified
        if let maxTime = maxTime {
            matchingRecipes = matchingRecipes.filter { recipe in
                (recipe.prepTime + recipe.cookTime) <= maxTime
            }
            print("📊 After time filter: \(matchingRecipes.count) recipes")
        }
        
        // Filter by ingredients if specified
        if let ingredients = ingredients, !ingredients.isEmpty {
            matchingRecipes = matchingRecipes.filter { recipe in
                let recipeIngredientNames = recipe.ingredients.map { $0.name.lowercased() }
                let requestedIngredients = ingredients.map { $0.lowercased() }
                return requestedIngredients.allSatisfy { ingredient in
                    recipeIngredientNames.contains { $0.contains(ingredient) }
                }
            }
            print("📊 After ingredient filter: \(matchingRecipes.count) recipes")
        }
        
        // Return the most recently cached recipe that matches
        if let bestMatch = matchingRecipes.first {
            print("✅ Found matching cached recipe: \(bestMatch.name)")
            return bestMatch
        } else {
            print("❌ No matching cached recipe found")
            return nil
        }
    }
    
    /// Finds cached recipes that match the popular recipes criteria
    /// - Parameters: All the recipe generation parameters
    /// - Returns: Array of matching cached recipes
    private func findCachedPopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int?,
        servings: Int
    ) -> [Recipe] {
        print("🔍 Searching for cached popular recipes matching criteria...")
        print("   - Cuisine: \(cuisine.rawValue)")
        print("   - Difficulty: \(difficulty.rawValue)")
        print("   - Servings: \(servings)")
        print("   - Dietary restrictions: \(dietaryRestrictions.count)")
        
        // Filter cached recipes by basic criteria
        var matchingRecipes = cachedRecipes.filter { recipe in
            recipe.cuisine == cuisine &&
            recipe.difficulty == difficulty &&
            recipe.servings == servings
        }
        
        print("📊 Found \(matchingRecipes.count) recipes matching basic criteria")
        
        // Filter by dietary restrictions if specified
        if !dietaryRestrictions.isEmpty {
            matchingRecipes = matchingRecipes.filter { recipe in
                let recipeDietaryNotes = Set(recipe.dietaryNotes)
                let requestedDietaryNotes = Set(dietaryRestrictions)
                return recipeDietaryNotes.isSuperset(of: requestedDietaryNotes)
            }
            print("📊 After dietary filter: \(matchingRecipes.count) recipes")
        }
        
        // Filter by max time if specified
        if let maxTime = maxTime {
            matchingRecipes = matchingRecipes.filter { recipe in
                (recipe.prepTime + recipe.cookTime) <= maxTime
            }
            print("📊 After time filter: \(matchingRecipes.count) recipes")
        }
        
        // Sort by most recently cached (newest first)
        matchingRecipes.sort { recipe1, recipe2 in
            recipe1.createdAt > recipe2.createdAt
        }
        
        print("✅ Found \(matchingRecipes.count) matching cached recipes for popular recipes")
        return matchingRecipes
    }
    
    // MARK: - Dietary Restrictions Change Detection
    
    /// Checks if dietary restrictions have changed significantly from the last request
    /// - Parameter currentRestrictions: The current dietary restrictions
    /// - Returns: True if restrictions have changed significantly
    private func hasDietaryRestrictionsChanged(_ currentRestrictions: [DietaryNote]) -> Bool {
        // If this is the first request, no change detected
        if lastUsedDietaryRestrictions.isEmpty {
            lastUsedDietaryRestrictions = currentRestrictions
            print("📱 First dietary restrictions set: \(currentRestrictions.map { $0.rawValue })")
            return false
        }
        
        // Check if restrictions have changed
        let currentSet = Set(currentRestrictions)
        let lastSet = Set(lastUsedDietaryRestrictions)
        
        let hasChanged = currentSet != lastSet
        
        if hasChanged {
            print("⚠️ Dietary restrictions changed:")
            print("   Previous: \(lastUsedDietaryRestrictions.map { $0.rawValue })")
            print("   Current: \(currentRestrictions.map { $0.rawValue })")
            
            // Update the last used restrictions
            lastUsedDietaryRestrictions = currentRestrictions
        } else {
            print("✅ Dietary restrictions unchanged: \(currentRestrictions.map { $0.rawValue })")
        }
        
        return hasChanged
    }
    
    /// Updates the last used dietary restrictions (called when LLM generates new recipe)
    private func updateLastUsedDietaryRestrictions(_ restrictions: [DietaryNote]) {
        lastUsedDietaryRestrictions = restrictions
        print("📱 Updated last used dietary restrictions: \(restrictions.map { $0.rawValue })")
    }
} 