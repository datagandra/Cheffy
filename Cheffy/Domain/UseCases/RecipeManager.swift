import Foundation
import Combine
import os.log

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
        
        // Log cache status on initialization
        os_log("RecipeManager initialized - cachedRecipes: %{public}d, favorites: %{public}d, generationCount: %{public}d", log: .default, type: .info, cachedRecipes.count, favorites.count, generationCount)
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
                logger.cache("Using cached recipe: \(cachedRecipe.name)")
                logger.cache("Recipe loaded from cache - no LLM connection needed")
            }
        } else {
            // No cached recipe found, generate new one from LLM
            logger.cache("No cached recipe found, connecting to LLM...")
            
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
            os_log("Recipe cached successfully - recipeName: %{public}@", log: .default, type: .info, recipe.name)
            self.cacheManager.cacheRecipe(recipe)
            self.updateCachedData()
            

        }
            } catch {
                // Check if it's an API key error and fall back to local recipes
                if let geminiError = error as? GeminiError, case .noAPIKey = geminiError {
                    logger.warning("No API key available, falling back to local recipe database")
                    await fallbackToLocalRecipes(
                        cuisine: cuisine,
                        difficulty: difficulty,
                        dietaryRestrictions: dietaryRestrictions
                    )
                } else {
                    await MainActor.run {
                        self.error = error.localizedDescription
                    }
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
        
        // CRITICAL FIX: Handle Non-Vegetarian and empty restrictions for guaranteed diversity
        if dietaryRestrictions.isEmpty || dietaryRestrictions.contains(.nonVegetarian) {
            let reason = dietaryRestrictions.isEmpty ? "No dietary restrictions" : "Non-Vegetarian selected"
            logger.warning("\(reason) - using HYBRID approach for guaranteed meat + vegetarian diversity")
            await generateHybridDiverseRecipes(
                cuisine: cuisine,
                difficulty: difficulty,
                maxTime: maxTime,
                servings: servings
            )
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        // Check if dietary restrictions have changed significantly
        let cachedRecipes: [Recipe]
        if hasDietaryRestrictionsChanged(dietaryRestrictions) {
            logger.warning("Dietary restrictions changed for popular recipes - will connect to LLM for fresh recipes")
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
            // Use cached recipes if we have any, but filter them properly
            let filteredCachedRecipes = findCachedPopularRecipes(
                cuisine: cuisine,
                difficulty: difficulty,
                dietaryRestrictions: dietaryRestrictions,
                maxTime: maxTime,
                servings: servings
            )
            
            if !filteredCachedRecipes.isEmpty {
                await MainActor.run {
                    self.popularRecipes = filteredCachedRecipes
                    self.isUsingCachedData = true
                    logger.cache("Using \(self.popularRecipes.count) filtered cached recipes")
                    logger.cache("Recipes loaded from cache - no LLM connection needed")
                }
            } else {
                // No matching cached recipes, generate new ones from LLM
                logger.cache("No matching cached recipes found, connecting to LLM...")
                await generatePopularRecipesFromLLM(
                    cuisine: cuisine,
                    difficulty: difficulty,
                    dietaryRestrictions: dietaryRestrictions,
                    maxTime: maxTime,
                    servings: servings
                )
            }
        } else {
            // No cached recipes, generate new ones from LLM
            logger.cache("No cached recipes found, connecting to LLM...")
            await generatePopularRecipesFromLLM(
                cuisine: cuisine,
                difficulty: difficulty,
                dietaryRestrictions: dietaryRestrictions,
                maxTime: maxTime,
                servings: servings
            )
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
    
    /// Clears all cached recipes to force fresh LLM generation
    func clearRecipeCache() {
        cachedRecipes.removeAll()
        logger.warning("Recipe cache cleared - next generation will use fresh LLM data")
    }
    
    /// Generates diverse recipes using a hybrid approach: database recipes + LLM generation
    /// This ensures guaranteed diversity when no dietary restrictions are selected
    private func generateHybridDiverseRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        maxTime: Int?,
        servings: Int
    ) async {
        logger.warning("Starting HYBRID recipe generation for guaranteed diversity")
        
        var allRecipes: [Recipe] = []
        
        // Step 1: Load meat-based recipes from our database
        let meatRecipes = loadMeatBasedRecipesFromDatabase(cuisine: cuisine, servings: servings)
        allRecipes.append(contentsOf: meatRecipes)
        logger.warning("Loaded \(meatRecipes.count) meat-based recipes from database")
        
        // Step 2: Generate vegetarian recipes from LLM (since LLM is good at those)
        let vegetarianRecipes = await generateVegetarianRecipesFromLLM(
            cuisine: cuisine,
            difficulty: difficulty,
            maxTime: maxTime,
            servings: servings
        )
        allRecipes.append(contentsOf: vegetarianRecipes)
        logger.warning("Generated \(vegetarianRecipes.count) vegetarian recipes from LLM")
        
        // Step 3: Ensure we have at least 10 recipes total
        if allRecipes.count < 10 {
            let additionalRecipes = await generateAdditionalRecipesFromLLM(
                cuisine: cuisine,
                difficulty: difficulty,
                maxTime: maxTime,
                servings: servings,
                targetCount: 10 - allRecipes.count
            )
            allRecipes.append(contentsOf: additionalRecipes)
            logger.warning("Generated \(additionalRecipes.count) additional recipes to reach minimum count")
        }
        
        // Step 4: Shuffle and limit to 20 recipes
        allRecipes.shuffle()
        let finalRecipes = Array(allRecipes.prefix(20))
        
        await MainActor.run {
            self.popularRecipes = finalRecipes
            logger.warning("HYBRID generation complete: \(finalRecipes.count) diverse recipes (meat + vegetarian)")
        }
    }
    
    /// Loads meat-based recipes from our local recipe database
    private func loadMeatBasedRecipesFromDatabase(cuisine: Cuisine, servings: Int) -> [Recipe] {
        var meatRecipes: [Recipe] = []
        
        // Load recipes from JSON files based on cuisine
        let cuisineFileName = getCuisineFileName(cuisine)
        logger.warning("🔍 Attempting to load meat recipes from: \(cuisineFileName).json")
        
        // Debug: List all available resources in the bundle
        if let resourcePath = Bundle.main.resourcePath {
            logger.warning("📁 Bundle resource path: \(resourcePath)")
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                let jsonFiles = items.filter { $0.hasSuffix(".json") }
                logger.warning("📋 Available JSON files: \(jsonFiles)")
            } catch {
                logger.error("❌ Could not list bundle contents: \(error)")
            }
        }
        
        guard let url = Bundle.main.url(forResource: cuisineFileName, withExtension: "json") else {
            logger.error("❌ Could not find JSON file: \(cuisineFileName).json")
            // Try alternative paths
            let alternativePaths = [
                "\(cuisineFileName)",
                "Resources/\(cuisineFileName)",
                "Cheffy/Resources/\(cuisineFileName)"
            ]
            
            for path in alternativePaths {
                if let altUrl = Bundle.main.url(forResource: path, withExtension: "json") {
                    logger.warning("✅ Found file at alternative path: \(path).json")
                    // Continue with this URL
                    return loadRecipesFromURL(altUrl, cuisine: cuisine, servings: servings)
                }
            }
            return meatRecipes
        }
        
        return loadRecipesFromURL(url, cuisine: cuisine, servings: servings)
    }
    
    /// Helper function to load recipes from a specific URL
    private func loadRecipesFromURL(_ url: URL, cuisine: Cuisine, servings: Int) -> [Recipe] {
        var meatRecipes: [Recipe] = []
        
        logger.warning("📖 Reading from URL: \(url)")
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("❌ Could not read data from: \(url)")
            return meatRecipes
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("❌ Could not parse JSON from: \(url)")
            return meatRecipes
        }
        
        guard let cuisines = json["cuisines"] as? [String: Any] else {
            logger.error("❌ Could not find 'cuisines' key in JSON")
            return meatRecipes
        }
        
        guard let recipes = cuisines[cuisine.rawValue] as? [[String: Any]] else {
            logger.error("❌ Could not find recipes for cuisine: \(cuisine.rawValue)")
            return meatRecipes
        }
        
        logger.warning("✅ Found \(recipes.count) total recipes in \(url.lastPathComponent) for \(cuisine.rawValue)")
        
        for (index, recipeData) in recipes.enumerated() {
            guard let title = recipeData["title"] as? String,
                  let ingredients = recipeData["ingredients"] as? [String],
                  let instructions = recipeData["instructions"] as? String,
                  let cookingTime = recipeData["cooking_time"] as? Int,
                  let difficultyString = recipeData["difficulty"] as? String else {
                logger.warning("⚠️ Skipping recipe \(index) - missing required fields")
                continue
            }
            
            // Check if this is a meat-based recipe
            let hasMeat = ingredients.contains { ingredient in
                let lowercased = ingredient.lowercased()
                return lowercased.contains("chicken") || lowercased.contains("beef") || 
                       lowercased.contains("lamb") || lowercased.contains("pork") ||
                       lowercased.contains("fish") || lowercased.contains("shrimp") ||
                       lowercased.contains("goat") || lowercased.contains("turkey") ||
                       lowercased.contains("mutton") || lowercased.contains("prawn")
            }
            
            if hasMeat {
                logger.warning("🥩 Found meat recipe: \(title)")
                let difficulty = Difficulty(rawValue: difficultyString.lowercased()) ?? .medium
                let recipe = Recipe(
                    title: title,
                    cuisine: cuisine,
                    difficulty: difficulty,
                    prepTime: max(5, cookingTime / 3),
                    cookTime: max(10, cookingTime * 2 / 3),
                    servings: servings,
                    ingredients: ingredients.map { Ingredient(name: $0, amount: 1.0, unit: "piece") },
                    steps: [CookingStep(stepNumber: 1, description: instructions, duration: cookingTime)],
                    winePairings: [],
                    dietaryNotes: [], // Will be inferred from ingredients
                    platingTips: "Serve with traditional \(cuisine.rawValue) presentation",
                    chefNotes: "Traditional \(cuisine.rawValue) recipe from our database"
                )
                meatRecipes.append(recipe)
            } else {
                logger.debug("🥬 Skipping vegetarian recipe: \(title)")
            }
        }
        
        logger.warning("✅ Successfully loaded \(meatRecipes.count) meat-based recipes from \(cuisine.rawValue) database")
        return meatRecipes
    }
    
    /// Generates vegetarian recipes from LLM (since LLM is good at those)
    private func generateVegetarianRecipesFromLLM(
        cuisine: Cuisine,
        difficulty: Difficulty,
        maxTime: Int?,
        servings: Int
    ) async -> [Recipe] {
        // Create a temporary dietary restriction for vegetarian recipes
        let vegetarianRestrictions: [DietaryNote] = [.vegetarian]
        
        do {
            let recipes = try await openAIClient.generatePopularRecipes(
                cuisine: cuisine,
                difficulty: difficulty,
                dietaryRestrictions: vegetarianRestrictions,
                maxTime: maxTime,
                servings: servings
            )
            return recipes
        } catch {
            logger.warning("LLM failed (likely quota exceeded) - falling back to database-only mode: \(error)")
            // Fallback: Generate vegetarian recipes from database instead
            return generateVegetarianRecipesFromDatabase(cuisine: cuisine, servings: servings)
        }
    }
    
    /// Fallback: Generate vegetarian recipes from database when LLM fails
    private func generateVegetarianRecipesFromDatabase(cuisine: Cuisine, servings: Int) -> [Recipe] {
        var vegetarianRecipes: [Recipe] = []
        
        let cuisineFileName = getCuisineFileName(cuisine)
        logger.warning("🔄 LLM fallback: Loading vegetarian recipes from \(cuisineFileName).json")
        
        guard let url = Bundle.main.url(forResource: cuisineFileName, withExtension: "json") else {
            logger.error("❌ Could not find JSON file: \(cuisineFileName).json")
            return vegetarianRecipes
        }
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("❌ Could not read data from: \(cuisineFileName).json")
            return vegetarianRecipes
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("❌ Could not parse JSON from: \(cuisineFileName).json")
            return vegetarianRecipes
        }
        
        guard let cuisines = json["cuisines"] as? [String: Any] else {
            logger.error("❌ Could not find 'cuisines' key in JSON")
            return vegetarianRecipes
        }
        
        guard let recipes = cuisines[cuisine.rawValue] as? [[String: Any]] else {
            logger.error("❌ Could not find recipes for cuisine: \(cuisine.rawValue)")
            return vegetarianRecipes
        }
        
        for (index, recipeData) in recipes.enumerated() {
            guard let title = recipeData["title"] as? String,
                  let ingredients = recipeData["ingredients"] as? [String],
                  let instructions = recipeData["instructions"] as? String,
                  let cookingTime = recipeData["cooking_time"] as? Int,
                  let difficultyString = recipeData["difficulty"] as? String else {
                logger.warning("⚠️ Skipping recipe \(index) - missing required fields")
                continue
            }
            
            // Check if this is a vegetarian recipe (no meat)
            let hasMeat = ingredients.contains { ingredient in
                let lowercased = ingredient.lowercased()
                return lowercased.contains("chicken") || lowercased.contains("beef") || 
                       lowercased.contains("lamb") || lowercased.contains("pork") ||
                       lowercased.contains("fish") || lowercased.contains("shrimp") ||
                       lowercased.contains("goat") || lowercased.contains("turkey") ||
                       lowercased.contains("mutton") || lowercased.contains("prawn")
            }
            
            if !hasMeat {
                logger.warning("🥬 Found vegetarian recipe: \(title)")
                let difficulty = Difficulty(rawValue: difficultyString.lowercased()) ?? .medium
                let recipe = Recipe(
                    title: title,
                    cuisine: cuisine,
                    difficulty: difficulty,
                    prepTime: max(5, cookingTime / 3),
                    cookTime: max(10, cookingTime * 2 / 3),
                    servings: servings,
                    ingredients: ingredients.map { Ingredient(name: $0, amount: 1.0, unit: "piece") },
                    steps: [CookingStep(stepNumber: 1, description: instructions, duration: cookingTime)],
                    winePairings: [],
                    dietaryNotes: [.vegetarian],
                    platingTips: "Serve with traditional \(cuisine.rawValue) presentation",
                    chefNotes: "Traditional \(cuisine.rawValue) recipe from our database (LLM fallback)"
                )
                vegetarianRecipes.append(recipe)
            }
        }
        
        logger.warning("✅ LLM fallback: Loaded \(vegetarianRecipes.count) vegetarian recipes from \(cuisine.rawValue) database")
        return vegetarianRecipes
    }
    
    /// Fallback: Generate additional recipes from database when LLM fails
    private func generateAdditionalRecipesFromDatabase(cuisine: Cuisine, servings: Int, targetCount: Int) -> [Recipe] {
        var additionalRecipes: [Recipe] = []
        
        let cuisineFileName = getCuisineFileName(cuisine)
        logger.warning("🔄 LLM fallback: Loading additional recipes from \(cuisineFileName).json")
        
        guard let url = Bundle.main.url(forResource: cuisineFileName, withExtension: "json") else {
            logger.error("❌ Could not find JSON file: \(cuisineFileName).json")
            return additionalRecipes
        }
        
        guard let data = try? Data(contentsOf: url) else {
            logger.error("❌ Could not read data from: \(cuisineFileName).json")
            return additionalRecipes
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("❌ Could not parse JSON from: \(cuisineFileName).json")
            return additionalRecipes
        }
        
        guard let cuisines = json["cuisines"] as? [String: Any] else {
            logger.error("❌ Could not find 'cuisines' key in JSON")
            return additionalRecipes
        }
        
        guard let recipes = cuisines[cuisine.rawValue] as? [[String: Any]] else {
            logger.error("❌ Could not find recipes for cuisine: \(cuisine.rawValue)")
            return additionalRecipes
        }
        
        // Take a mix of meat and vegetarian recipes to reach target count
        var recipeCount = 0
        for (index, recipeData) in recipes.enumerated() {
            if recipeCount >= targetCount { break }
            
            guard let title = recipeData["title"] as? String,
                  let ingredients = recipeData["ingredients"] as? [String],
                  let instructions = recipeData["instructions"] as? String,
                  let cookingTime = recipeData["cooking_time"] as? Int,
                  let difficultyString = recipeData["difficulty"] as? String else {
                logger.warning("⚠️ Skipping recipe \(index) - missing required fields")
                continue
            }
            
            let difficulty = Difficulty(rawValue: difficultyString.lowercased()) ?? .medium
            let recipe = Recipe(
                title: title,
                cuisine: cuisine,
                difficulty: difficulty,
                prepTime: max(5, cookingTime / 3),
                cookTime: max(10, cookingTime * 2 / 3),
                servings: servings,
                ingredients: ingredients.map { Ingredient(name: $0, amount: 1.0, unit: "piece") },
                steps: [CookingStep(stepNumber: 1, description: instructions, duration: cookingTime)],
                winePairings: [],
                dietaryNotes: [], // Will be inferred from ingredients
                platingTips: "Serve with traditional \(cuisine.rawValue) presentation",
                chefNotes: "Traditional \(cuisine.rawValue) recipe from our database (LLM fallback)"
            )
            additionalRecipes.append(recipe)
            recipeCount += 1
        }
        
        logger.warning("✅ LLM fallback: Loaded \(additionalRecipes.count) additional recipes from \(cuisine.rawValue) database")
        return additionalRecipes
    }
    
    /// Generates additional recipes to reach target count
    private func generateAdditionalRecipesFromLLM(
        cuisine: Cuisine,
        difficulty: Difficulty,
        maxTime: Int?,
        servings: Int,
        targetCount: Int
    ) async -> [Recipe] {
        do {
            let recipes = try await openAIClient.generatePopularRecipes(
                cuisine: cuisine,
                difficulty: difficulty,
                dietaryRestrictions: [], // No restrictions for variety
                maxTime: maxTime,
                servings: servings
            )
            return Array(recipes.prefix(targetCount))
        } catch {
            logger.warning("LLM failed (likely quota exceeded) - falling back to database for additional recipes: \(error)")
            // Fallback: Generate additional recipes from database instead
            return generateAdditionalRecipesFromDatabase(cuisine: cuisine, servings: servings, targetCount: targetCount)
        }
    }
    
    /// Gets the filename for a cuisine's recipe database
    private func getCuisineFileName(_ cuisine: Cuisine) -> String {
        switch cuisine {
        case .indian:
            return "indian_cuisines"
        case .italian:
            return "european_cuisines" // Italian recipes are in european_cuisines.json
        case .chinese:
            return "asian_cuisines"
        case .mexican:
            return "mexican_cuisines"
        case .mediterranean:
            return "mediterranean_cuisines"
        case .american:
            return "american_cuisines"
        case .thai:
            return "asian_cuisines"
        case .japanese:
            return "asian_cuisines"
        case .french:
            return "european_cuisines"
        case .greek:
            return "mediterranean_cuisines"
        case .spanish:
            return "european_cuisines"
        case .lebanese:
            return "middle_eastern_african_cuisines"
        case .moroccan:
            return "middle_eastern_african_cuisines"
        case .vietnamese:
            return "asian_cuisines"
        case .korean:
            return "asian_cuisines"
        case .turkish:
            return "middle_eastern_african_cuisines"
        case .persian:
            return "middle_eastern_african_cuisines"
        case .ethiopian:
            return "middle_eastern_african_cuisines"
        case .brazilian:
            return "latin_american_cuisines"
        case .peruvian:
            return "latin_american_cuisines"
        case .any:
            return "indian_cuisines" // Default to Indian for multi-cuisine
        }
    }
    
    // MARK: - Favorites Persistence
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: "favorites")
        } catch {
            logger.error("Error saving favorites: \(error)")
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
            logger.error("Error loading favorites: \(error)")
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
            logger.cache("Loaded \(recipes.count) cached recipes")
        } else {
            logger.cache("No cached recipes found")
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
            logger.cache("Loaded all \(cachedRecipes.count) cached recipes")
        } else {
            logger.cache("No cached recipes available")
        }
    }
    
    // MARK: - Fallback Methods
    
    private func fallbackToLocalRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote]
    ) async {
        logger.info("Using local recipe database as fallback")
        
        // Load recipes from local database
        let recipeDatabase = RecipeDatabaseService.shared
        await recipeDatabase.loadAllRecipes()
        
        // Filter recipes based on criteria
        var filteredRecipes = recipeDatabase.recipes.filter { recipe in
            recipe.cuisine == cuisine
        }
        
        // Apply dietary restrictions filter
        if !dietaryRestrictions.isEmpty {
            filteredRecipes = filteredRecipes.filter { recipe in
                let recipeDietaryNotes = Set(recipe.dietaryNotes.map { $0.rawValue })
                let userDietaryNotes = Set(dietaryRestrictions.map { $0.rawValue })
                return !recipeDietaryNotes.isDisjoint(with: userDietaryNotes)
            }
        }
        
        // If no recipes match exact criteria, show all recipes for the cuisine
        if filteredRecipes.isEmpty {
            filteredRecipes = recipeDatabase.recipes.filter { recipe in
                recipe.cuisine == cuisine
            }
        }
        
        // Select a random recipe or the first one
        let selectedRecipe = filteredRecipes.randomElement() ?? filteredRecipes.first
        
        await MainActor.run {
            if let recipe = selectedRecipe {
                self.generatedRecipe = recipe
                self.isUsingCachedData = true
                self.error = nil
                logger.info("Successfully loaded recipe from local database: \(recipe.title)")
            } else {
                self.error = "No recipes found for \(cuisine.rawValue) cuisine. Please try a different cuisine or set up your API key."
            }
        }
    }
    
    private func fallbackToLocalPopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote]
    ) async {
        logger.info("Using local recipe database as fallback for popular recipes")
        
        // Load recipes from local database
        let recipeDatabase = RecipeDatabaseService.shared
        await recipeDatabase.loadAllRecipes()
        
        // Filter recipes based on criteria
        var filteredRecipes = recipeDatabase.recipes.filter { recipe in
            recipe.cuisine == cuisine
        }
        
        // Apply dietary restrictions filter
        if !dietaryRestrictions.isEmpty {
            filteredRecipes = filteredRecipes.filter { recipe in
                let recipeDietaryNotes = Set(recipe.dietaryNotes.map { $0.rawValue })
                let userDietaryNotes = Set(dietaryRestrictions.map { $0.rawValue })
                return !recipeDietaryNotes.isDisjoint(with: userDietaryNotes)
            }
        }
        
        // If no recipes match exact criteria, show all recipes for the cuisine
        if filteredRecipes.isEmpty {
            filteredRecipes = recipeDatabase.recipes.filter { recipe in
                recipe.cuisine == cuisine
            }
        }
        
        // Take up to 20 recipes for better variety
        let selectedRecipes = Array(filteredRecipes.prefix(20))
        
        await MainActor.run {
            if !selectedRecipes.isEmpty {
                self.popularRecipes = selectedRecipes
                self.isUsingCachedData = true
                self.error = nil
                logger.info("Successfully loaded \(selectedRecipes.count) recipes from local database")
            } else {
                self.error = "No recipes found for \(cuisine.rawValue) cuisine. Please try a different cuisine or set up your API key."
            }
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
        logger.debug("Searching for cached recipe matching criteria...")
        logger.debug("   - Cuisine: \(cuisine.rawValue)")
        logger.debug("   - Difficulty: \(difficulty.rawValue)")
        logger.debug("   - Servings: \(servings)")
        logger.debug("   - Dietary restrictions: \(dietaryRestrictions.count)")
        
        // Check if dietary restrictions have changed significantly
        if hasDietaryRestrictionsChanged(dietaryRestrictions) {
            logger.warning("Dietary restrictions changed - will connect to LLM for fresh recipe")
            return nil
        }
        
        // Filter cached recipes by basic criteria
        var matchingRecipes = cachedRecipes.filter { recipe in
            let cuisineMatches = cuisine == .any || recipe.cuisine == cuisine
            return cuisineMatches &&
            recipe.difficulty == difficulty &&
            recipe.servings == servings
        }
        
        logger.debug("Found \(matchingRecipes.count) recipes matching basic criteria")
        
        // If we have a specific recipe name, prioritize exact matches
        if let recipeName = recipeName, !recipeName.isEmpty {
            let exactMatches = matchingRecipes.filter { recipe in
                recipe.name.lowercased().contains(recipeName.lowercased())
            }
            if !exactMatches.isEmpty {
                logger.debug("Found exact name match: \(exactMatches.first!.name)")
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
            logger.debug("After dietary filter: \(matchingRecipes.count) recipes")
        }
        
        // Filter by max time if specified
        if let maxTime = maxTime {
            matchingRecipes = matchingRecipes.filter { recipe in
                (recipe.prepTime + recipe.cookTime) <= maxTime
            }
            logger.debug("After time filter: \(matchingRecipes.count) recipes")
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
            logger.debug("After ingredient filter: \(matchingRecipes.count) recipes")
        }
        
        // Return the most recently cached recipe that matches
        if let bestMatch = matchingRecipes.first {
            logger.debug("Found matching cached recipe: \(bestMatch.name)")
            return bestMatch
        } else {
            logger.debug("No matching cached recipe found")
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
        logger.debug("Searching for cached popular recipes matching criteria...")
        logger.debug("   - Cuisine: \(cuisine.rawValue)")
        logger.debug("   - Difficulty: \(difficulty.rawValue)")
        logger.debug("   - Servings: \(servings)")
        logger.debug("   - Dietary restrictions: \(dietaryRestrictions.count)")
        
        // Filter cached recipes by basic criteria
        var matchingRecipes = cachedRecipes.filter { recipe in
            let cuisineMatches = cuisine == .any || recipe.cuisine == cuisine
            let difficultyMatches = recipe.difficulty == difficulty
            // Make servings filter more flexible - allow recipes with similar serving sizes
            let servingsMatches = abs(recipe.servings - servings) <= 2 || recipe.servings == servings
            
            return cuisineMatches && difficultyMatches && servingsMatches
        }
        
        logger.debug("Found \(matchingRecipes.count) recipes matching basic criteria")
        
        // Filter by dietary restrictions if specified
        if !dietaryRestrictions.isEmpty {
            matchingRecipes = matchingRecipes.filter { recipe in
                let recipeDietaryNotes = Set(recipe.dietaryNotes)
                let requestedDietaryNotes = Set(dietaryRestrictions)
                return recipeDietaryNotes.isSuperset(of: requestedDietaryNotes)
            }
            logger.debug("After dietary filter: \(matchingRecipes.count) recipes")
        } else {
            // No dietary restrictions selected - show ALL recipes (this is the key fix!)
            logger.debug("No dietary restrictions selected - showing ALL recipes")
        }
        
        // Filter by max time if specified
        if let maxTime = maxTime {
            matchingRecipes = matchingRecipes.filter { recipe in
                let totalTime = recipe.prepTime + recipe.cookTime
                let isWithinTime = totalTime <= maxTime
                
                if !isWithinTime {
                    logger.warning("Recipe '\(recipe.title)' filtered out: total time \(totalTime) min > max time \(maxTime) min (prep: \(recipe.prepTime) min, cook: \(recipe.cookTime) min)")
                }
                
                return isWithinTime
            }
            logger.debug("After time filter: \(matchingRecipes.count) recipes")
            
            // If we have very few recipes after time filtering, log a warning
            if matchingRecipes.count < 3 {
                logger.warning("Only \(matchingRecipes.count) recipes meet the \(maxTime) minute time constraint")
            }
        }
        
        // Sort by most recently cached (newest first)
        matchingRecipes.sort { recipe1, recipe2 in
            recipe1.createdAt > recipe2.createdAt
        }
        
        // Final validation: ensure all recipes meet time constraint
        if let maxTime = maxTime {
            let invalidRecipes = matchingRecipes.filter { recipe in
                (recipe.prepTime + recipe.cookTime) > maxTime
            }
            
            if !invalidRecipes.isEmpty {
                logger.error("CRITICAL: Found \(invalidRecipes.count) recipes that violate time constraint:")
                for recipe in invalidRecipes {
                    logger.error("  - '\(recipe.title)': \(recipe.prepTime) + \(recipe.cookTime) = \(recipe.prepTime + recipe.cookTime) min > \(maxTime) min")
                }
                
                // Remove invalid recipes
                matchingRecipes = matchingRecipes.filter { recipe in
                    (recipe.prepTime + recipe.cookTime) <= maxTime
                }
                logger.warning("Removed \(invalidRecipes.count) invalid recipes, remaining: \(matchingRecipes.count)")
            }
        }
        
        // Remove duplicate recipes based on title
        let originalCount = matchingRecipes.count
        matchingRecipes = removeDuplicateCachedRecipes(matchingRecipes)
        let uniqueCount = matchingRecipes.count
        
        if originalCount != uniqueCount {
            logger.debug("Removed \(originalCount - uniqueCount) duplicate cached recipes")
        }
        
        logger.debug("Found \(matchingRecipes.count) unique matching cached recipes for popular recipes")
        
        // Ensure minimum recipe count for better user experience
        if matchingRecipes.count < 10 {
            logger.warning("Only \(matchingRecipes.count) recipes found - below minimum threshold of 10")
            
            // If we have very few recipes, try more relaxed filtering to get more recipes
            if matchingRecipes.count < 5 {
                logger.warning("Very few recipes found - trying relaxed filtering...")
                
                // Try more relaxed filtering: only match cuisine and difficulty
                let relaxedRecipes = cachedRecipes.filter { recipe in
                    let cuisineMatches = cuisine == .any || recipe.cuisine == cuisine
                    let difficultyMatches = recipe.difficulty == difficulty
                    return cuisineMatches && difficultyMatches
                }
                
                if relaxedRecipes.count > matchingRecipes.count {
                    logger.debug("Relaxed filtering found \(relaxedRecipes.count) recipes (was \(matchingRecipes.count))")
                    // Use relaxed recipes but still apply dietary and time filters
                    var newMatchingRecipes = relaxedRecipes
                    
                    // Apply dietary restrictions if specified
                    if !dietaryRestrictions.isEmpty {
                        newMatchingRecipes = newMatchingRecipes.filter { recipe in
                            let recipeDietaryNotes = Set(recipe.dietaryNotes)
                            let requestedDietaryNotes = Set(dietaryRestrictions)
                            return recipeDietaryNotes.isSuperset(of: requestedDietaryNotes)
                        }
                    }
                    
                    // Apply time filter if specified
                    if let maxTime = maxTime {
                        newMatchingRecipes = newMatchingRecipes.filter { recipe in
                            (recipe.prepTime + recipe.cookTime) <= maxTime
                        }
                    }
                    
                    // Remove duplicates and sort
                    newMatchingRecipes = removeDuplicateCachedRecipes(newMatchingRecipes)
                    newMatchingRecipes.sort { recipe1, recipe2 in
                        recipe1.createdAt > recipe2.createdAt
                    }
                    
                    if newMatchingRecipes.count > matchingRecipes.count {
                        logger.debug("Using relaxed filtering results: \(newMatchingRecipes.count) recipes")
                        matchingRecipes = newMatchingRecipes
                    }
                }
            }
        }
        
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
            logger.debug("First dietary restrictions set: \(currentRestrictions.map { $0.rawValue })")
            return false
        }
        
        // Check if restrictions have changed
        let currentSet = Set(currentRestrictions)
        let lastSet = Set(lastUsedDietaryRestrictions)
        
        let hasChanged = currentSet != lastSet
        
        if hasChanged {
            logger.warning("Dietary restrictions changed:")
            logger.debug("   Previous: \(lastUsedDietaryRestrictions.map { $0.rawValue })")
            logger.debug("   Current: \(currentRestrictions.map { $0.rawValue })")
            
            // Update the last used restrictions
            lastUsedDietaryRestrictions = currentRestrictions
        } else {
            logger.debug("Dietary restrictions unchanged: \(currentRestrictions.map { $0.rawValue })")
        }
        
        return hasChanged
    }
    
    /// Updates the last used dietary restrictions (called when LLM generates new recipe)
    private func updateLastUsedDietaryRestrictions(_ restrictions: [DietaryNote]) {
        lastUsedDietaryRestrictions = restrictions
        logger.debug("Updated last used dietary restrictions: \(restrictions.map { $0.rawValue })")
    }
    
    // MARK: - Recipe Deduplication
    
    /// Removes duplicate recipes from cached results based on title similarity
    private func removeDuplicateCachedRecipes(_ recipes: [Recipe]) -> [Recipe] {
        var uniqueRecipes: [Recipe] = []
        var seenTitles: Set<String> = []
        
        for recipe in recipes {
            // Clean the recipe title by removing common prefixes and suffixes
            let cleanTitle = cleanRecipeTitle(recipe.title)
            
            if !seenTitles.contains(cleanTitle) {
                seenTitles.insert(cleanTitle)
                uniqueRecipes.append(recipe)
            } else {
                logger.debug("Removing duplicate cached recipe: '\(recipe.title)' (clean title: '\(cleanTitle)')")
            }
        }
        
        return uniqueRecipes
    }
    
    /// Cleans recipe titles by removing common prefixes and suffixes
    private func cleanRecipeTitle(_ title: String) -> String {
        var cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes that might be added by the LLM
        let prefixesToRemove = [
            "Top 10 recipes: ",
            "Top 10: ",
            "Popular recipes: ",
            "Recipe: ",
            "Dish: ",
            "Food: "
        ]
        
        for prefix in prefixesToRemove {
            if cleanTitle.hasPrefix(prefix) {
                cleanTitle = String(cleanTitle.dropFirst(prefix.count))
                break
            }
        }
        
        // Remove common suffixes
        let suffixesToRemove = [
            " (Popular)",
            " (Trending)",
            " (Famous)",
            " (Classic)"
        ]
        
        for suffix in suffixesToRemove {
            if cleanTitle.hasSuffix(suffix) {
                cleanTitle = String(cleanTitle.dropLast(suffix.count))
                break
            }
        }
        
        return cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - LLM Recipe Generation
    
    /// Generates popular recipes from LLM when no cached recipes are available
    private func generatePopularRecipesFromLLM(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int?,
        servings: Int
    ) async {
        do {
            var recipes = try await openAIClient.generatePopularRecipes(
                cuisine: cuisine,
                difficulty: difficulty,
                dietaryRestrictions: dietaryRestrictions,
                maxTime: maxTime,
                servings: servings
            )
            
            // Final validation: ensure all recipes meet time constraint if specified
            if let maxTime = maxTime {
                let invalidRecipes = recipes.filter { recipe in
                    (recipe.prepTime + recipe.cookTime) > maxTime
                }
                
                if !invalidRecipes.isEmpty {
                    logger.error("CRITICAL: LLM generated \(invalidRecipes.count) recipes that violate time constraint:")
                    for recipe in invalidRecipes {
                        logger.error("  - '\(recipe.title)': \(recipe.prepTime) + \(recipe.cookTime) = \(recipe.prepTime + recipe.cookTime) min > \(maxTime) min")
                    }
                    
                    // Remove invalid recipes
                    recipes = recipes.filter { recipe in
                        (recipe.prepTime + recipe.cookTime) <= maxTime
                    }
                    logger.warning("Removed \(invalidRecipes.count) invalid recipes, remaining: \(recipes.count)")
                }
            }
            
            await MainActor.run {
                self.popularRecipes = recipes
                self.incrementGenerationCount()
                self.isUsingCachedData = false
                
                // Update dietary restrictions tracking
                self.updateLastUsedDietaryRestrictions(dietaryRestrictions)
                
                // Cache all generated recipes
                logger.cache("RecipeManager: Caching \(recipes.count) generated recipes")
                self.cacheManager.cacheRecipes(recipes)
                self.updateCachedData()
                logger.cache("RecipeManager: All recipes cached successfully")
            }
        } catch {
            // Check if it's an API key error and fall back to local recipes
            if let geminiError = error as? GeminiError, case .noAPIKey = geminiError {
                logger.warning("No API key available, falling back to local recipe database for popular recipes")
                await fallbackToLocalPopularRecipes(
                    cuisine: cuisine,
                    difficulty: difficulty,
                    dietaryRestrictions: dietaryRestrictions
                )
            } else {
                await MainActor.run {
                    self.error = error.localizedDescription
                    logger.error("Error generating popular recipes: \(error)")
                }
            }
        }
    }
} 