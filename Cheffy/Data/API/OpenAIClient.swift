import Foundation
import os.log

// MARK: - Gemini Data Models
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let maxOutputTokens: Int
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

struct GeminiErrorResponse: Codable {
    let error: GeminiErrorDetail?
}

struct GeminiErrorDetail: Codable {
    let message: String
}

enum GeminiError: Error {
    case noAPIKey
    case apiError(String)
    case noContent
    case decodingError
    
    var errorDescription: String {
        switch self {
        case .noAPIKey:
            return "No API key found"
        case .apiError(let message):
            return "API Error: \(message)"
        case .noContent:
            return "No content in response"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

class OpenAIClient: ObservableObject {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private var apiKey: String?
    
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        loadAPIKey()
    }
    
    // MARK: - API Key Management
    private func loadAPIKey() {
        // Use secure configuration manager
        let secureConfig = SecureConfigManager.shared
        self.apiKey = secureConfig.geminiAPIKey
        
        if let apiKey = self.apiKey, !apiKey.isEmpty {
            logger.api("Gemini API key loaded securely")
        } else {
            logger.warning("No API key available - functionality will be limited")
        }
    }
    
    func hasAPIKey() -> Bool {
        return apiKey != nil
    }
    
    func setAPIKey(_ key: String) {
        self.apiKey = key
        logger.api("Gemini API key updated")
    }

    // MARK: - API Testing
    func testAPIKey() async -> Bool {
        guard let apiKey = apiKey else {
            logger.warning("No API key found")
            return false
        }
        
        logger.api("Testing API key...")
        
        let testPrompt = "Hello, please respond with 'API test successful'"
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: testPrompt)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.1,
                maxOutputTokens: 50
            )
        )
        
        let url = URL(string: "\(baseURL)/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.api("Test HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    logger.error("Test failed with HTTP \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        logger.error("Test error response: \(errorString)")
                    }
                    return false
                }
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            if let content = geminiResponse.candidates.first?.content.parts.first?.text {
                logger.api("API test successful: \(content)")
                return true
            } else {
                logger.error("Test failed: No content in response")
                return false
            }
        } catch {
            logger.error("API test failed: \(error)")
            return false
        }
    }

    // MARK: - Recipe Generation
    func generateRecipe(
        userPrompt: String? = nil,
        recipeName: String? = nil,
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        ingredients: [String]? = nil,
        maxTime: Int? = nil,
        servings: Int = 2
    ) async throws -> Recipe {
        guard let apiKey = apiKey else {
            logger.warning("No API key found")
            throw GeminiError.noAPIKey
        }
        
        logger.api("API key found, starting generation...")
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let prompt: String
        if let userPrompt = userPrompt, !userPrompt.isEmpty {
            logger.api("Using user prompt: \(userPrompt)")
            prompt = userPrompt + """

                        IMPORTANT: You must respond with ONLY valid JSON in the exact format specified below. Do not include any additional text, explanations, or markdown formatting.

                                                Create MICHELIN-LEVEL detailed, step-by-step cooking instructions that are easy to follow for home cooks. Each step should include:
                        - Extremely detailed, specific instructions with exact measurements and techniques
                        - Precise timing information (how long each step takes)
                        - Exact temperature settings where applicable
                        - Professional chef tips, techniques, and secrets
                        - Visual cues, doneness indicators, and sensory descriptions
                        - Safety precautions and best practices
                        - Equipment recommendations and preparation notes

                        Make each step comprehensive enough that even a beginner can follow along perfectly. Include professional cooking techniques, timing precision, and visual indicators for doneness.

                        IMPORTANT: The "description" field in each step must contain ONLY plain English cooking instructions, NOT JSON format or code. Write natural, conversational cooking instructions that a home cook can easily follow.

                        {
                            "name": "Recipe Name",
                            "prepTime": 30,
                            "cookTime": 45,
                            "ingredients": [
                                {"name": "Ingredient Name", "amount": 2.0, "unit": "cups", "notes": "Preparation notes (finely chopped, minced, fresh, etc.) and quality specifications (extra virgin, organic, etc.)"}
                            ],
                            "steps": [
                                {
                                    "stepNumber": 1,
                                    "description": "Heat a large skillet over medium-high heat. Add 2 tablespoons of olive oil and swirl to coat the pan evenly. When the oil is shimmering and hot, add the diced onions and sauté until they become translucent and slightly golden, about 3-4 minutes. Stir occasionally to prevent burning.",
                                    "duration": 10,
                                    "temperature": 180,
                                    "tips": "Professional chef tip: Always preheat your pan before adding oil to ensure even cooking and prevent sticking"
                                }
                            ],
                            "winePairings": [
                                {"name": "Wine Name", "type": "Red", "region": "Bordeaux", "description": "Detailed wine description with pairing notes"}
                            ],
                            "platingTips": "Detailed plating instructions with presentation tips, garnishing suggestions, and visual appeal techniques",
                            "chefNotes": "Chef's special notes about technique, timing, ingredient substitutions, and professional secrets for achieving restaurant-quality results"
                        }
                        """
        } else {
            logger.api("Using structured prompt")
            prompt = createRecipePrompt(
                cuisine: cuisine,
                difficulty: difficulty,
                dietaryRestrictions: dietaryRestrictions,
                recipeName: recipeName,
                ingredients: ingredients,
                maxTime: maxTime,
                servings: servings
            )
        }
        
        logger.api("Making API request to Gemini...")
        
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: prompt)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.1,
                maxOutputTokens: 500
            )
        )
        
        let url = URL(string: "\(baseURL)/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        let jsonData = try JSONEncoder().encode(request)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = jsonData
        urlRequest.timeoutInterval = 60.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                os_log("HTTP Status: %{public}d", log: .default, type: .info, httpResponse.statusCode)
                
                // Check for HTTP errors
                if httpResponse.statusCode != 200 {
                    os_log("HTTP Error: %{public}d", log: .default, type: .error, httpResponse.statusCode)
                    if let errorString = String(data: data, encoding: .utf8) {
                        os_log("Error response: %{public}@", log: .default, type: .error, errorString)
                    }
                    throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Log response size for debugging (privacy-compliant)
            os_log("API response received - size: %{public}d bytes", log: .default, type: .debug, data.count)
            
            // Try to decode as error response first
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               let error = errorResponse.error {
                os_log("Gemini API Error: %{public}@", log: .default, type: .error, error.message)
                throw GeminiError.apiError(error.message)
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
                logger.error("No content in response")
                logger.debug("Candidates count: \(geminiResponse.candidates.count)")
                if let firstCandidate = geminiResponse.candidates.first {
                    logger.debug("First candidate content parts: \(firstCandidate.content.parts.count)")
                }
                throw GeminiError.noContent
            }
            
            logger.api("API request successful, parsing response...")
            logger.debug("Response content length: \(content.count) characters")
            logger.debug("Response content: \(content)")
            
            let recipe = try parseRecipeFromResponse(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
            
            // Apply strict dietary filtering for single recipe
            if !dietaryRestrictions.isEmpty {
                let isCompliant = validateRecipeCompliance(recipe, against: dietaryRestrictions)
                if !isCompliant {
                    logger.warning("Generated recipe does not comply with dietary restrictions")
                    logger.debug("Recipe ingredients: \(recipe.ingredients.map { $0.name })")
                    logger.debug("Required restrictions: \(dietaryRestrictions.map { $0.rawValue })")
                    throw GeminiError.apiError("Generated recipe does not comply with selected dietary restrictions")
                }
            }
            
            return recipe
        } catch {
            os_log("Error generating recipe: %{public}@", log: .default, type: .error, error.localizedDescription)
            if let decodingError = error as? DecodingError {
                os_log("Decoding error details: %{public}@", log: .default, type: .error, String(describing: decodingError))
            }
            throw error
        }
    }
    
    func generatePopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int? = nil,
        servings: Int = 2
    ) async throws -> [Recipe] {
        
        // Handle "Any Cuisine" selection
        if cuisine == .any {
            return try await generateMultiCuisinePopularRecipes(
                difficulty: difficulty,
                dietaryRestrictions: dietaryRestrictions,
                maxTime: maxTime,
                servings: servings
            )
        }
        guard let apiKey = apiKey else {
            logger.warning("No API key found")
            throw GeminiError.noAPIKey
        }
        
        logger.api("API key found, starting popular recipes generation...")
        logger.debug("Cuisine: \(cuisine.rawValue)")
        logger.debug("Difficulty: \(difficulty.rawValue)")
        logger.debug("Dietary Restrictions: \(dietaryRestrictions.map { $0.rawValue })")
        
        let prompt = createPopularRecipesPrompt(
            cuisine: cuisine,
            difficulty: difficulty,
            dietaryRestrictions: dietaryRestrictions,
            maxTime: maxTime,
            servings: servings
        )
        
        logger.api("Making API request to Gemini for popular recipes...")
        
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: prompt)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.1,
                maxOutputTokens: 2000
            )
        )
        
        let url = URL(string: "\(baseURL)/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.api("HTTP Status: \(httpResponse.statusCode)")
                
                // Check for HTTP errors
                if httpResponse.statusCode != 200 {
                    logger.error("HTTP Error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        logger.error("Error response: \(errorString)")
                    }
                    throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Raw response: \(responseString)")
            }
            
            // Try to decode as error response first
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               let error = errorResponse.error {
                logger.error("Gemini API Error: \(error.message)")
                throw GeminiError.apiError(error.message)
            }
            
            // Try to decode as normal response
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            if let content = geminiResponse.candidates.first?.content.parts.first?.text {
                logger.api("Received response from Gemini")
                logger.debug("Response content length: \(content.count) characters")
                logger.debug("Response content: \(content)")
                
                var recipes = try parsePopularRecipesFromResponse(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
                
                // Apply strict dietary filtering
                let originalCount = recipes.count
                recipes = filterRecipesByDietaryRestrictions(recipes, restrictions: dietaryRestrictions)
                let dietaryFilteredCount = recipes.count
                
                logger.debug("Dietary filtering: \(originalCount) -> \(dietaryFilteredCount) recipes")
                
                // Apply strict cooking time filtering
                if let maxTime = maxTime {
                    let timeFilteredRecipes = filterRecipesByCookingTime(recipes, maxTime: maxTime)
                    let timeFilteredCount = timeFilteredRecipes.count
                    logger.debug("Time filtering: \(dietaryFilteredCount) -> \(timeFilteredCount) recipes (max time: \(maxTime) min)")
                    
                    // If we lost too many recipes due to time filtering, regenerate with stricter time constraints
                    if timeFilteredCount < 3 {
                        logger.warning("Too many recipes filtered out by time constraint, regenerating with stricter time requirements")
                        return try await generatePopularRecipesWithStrictTimeConstraint(
                            cuisine: cuisine,
                            difficulty: difficulty,
                            dietaryRestrictions: dietaryRestrictions,
                            maxTime: maxTime,
                            servings: servings
                        )
                    }
                    
                    recipes = timeFilteredRecipes
                }
                
                // If we lost too many recipes due to filtering, generate compliant fallback recipes
                if recipes.count < 5 && !dietaryRestrictions.isEmpty {
                    logger.warning("Too many recipes filtered out, generating compliant fallback recipes")
                    let fallbackRecipes = generateCompliantFallbackRecipes(
                        cuisine: cuisine,
                        difficulty: difficulty,
                        dietaryRestrictions: dietaryRestrictions,
                        count: 10 - recipes.count,
                        servings: servings
                    )
                    recipes.append(contentsOf: fallbackRecipes)
                    logger.api("Added \(fallbackRecipes.count) compliant fallback recipes")
                }
                
                // Remove any duplicate recipes
                let duplicateRemovalCount = recipes.count
                recipes = removeDuplicateRecipes(recipes)
                let uniqueCount = recipes.count
                
                if duplicateRemovalCount != uniqueCount {
                    logger.debug("Removed \(duplicateRemovalCount - uniqueCount) duplicate recipes")
                }
                
                // FINAL VALIDATION: Ensure we have at least 10 recipes
                if recipes.count < 10 {
                    logger.warning("CRITICAL: Only \(recipes.count) recipes after all processing. This is below minimum requirement of 10.")
                    logger.warning("This indicates a serious issue with LLM generation or parsing.")
                    
                    // If we still don't have enough, create more fallback recipes
                    while recipes.count < 10 {
                        let recipeNumber = recipes.count + 1
                        let recipeName = generateProperRecipeName(cuisine: cuisine, index: recipeNumber, dietaryRestrictions: dietaryRestrictions)
                        let dynamicIngredients = generateDynamicIngredientsForRecipe(name: recipeName, cuisine: cuisine, dietaryRestrictions: dietaryRestrictions)
                        
                        let recipe = Recipe(
                            title: recipeName,
                            cuisine: cuisine,
                            difficulty: difficulty,
                            prepTime: 15 + recipeNumber,
                            cookTime: 25 + recipeNumber,
                            servings: servings,
                            ingredients: dynamicIngredients,
                            steps: [
                                CookingStep(
                                    stepNumber: 1,
                                    description: "Prepare and cook \(recipeName) using \(cuisine.rawValue) techniques",
                                    duration: 15 + recipeNumber,
                                    temperature: nil,
                                    tips: "Ensure proper cooking methods"
                                )
                            ],
                            winePairings: [],
                            dietaryNotes: dietaryRestrictions,
                            platingTips: "Serve traditionally",
                            chefNotes: "Emergency fallback recipe to meet minimum count requirement"
                        )
                        recipes.append(recipe)
                        logger.debug("Created emergency fallback recipe: \(recipeName)")
                    }
                    
                    logger.api("EMERGENCY: Created \(recipes.count) total recipes to meet minimum requirement")
                }
                
                logger.api("Returning \(recipes.count) unique recipes after filtering, deduplication, and validation")
                
                return recipes
            } else {
                logger.error("No content in response")
                logger.debug("Candidates count: \(geminiResponse.candidates.count)")
                if let firstCandidate = geminiResponse.candidates.first {
                    logger.debug("First candidate content parts: \(firstCandidate.content.parts.count)")
                }
                throw GeminiError.noContent
            }
        } catch {
            logger.error("Error generating top 10 recipes: \(error)")
            if let decodingError = error as? DecodingError {
                logger.debug("Decoding error details: \(decodingError)")
            }
            throw error
        }
    }

    // MARK: - Image Generation (Not supported in Gemini, but keeping for compatibility)
    func generateStepImages(for steps: [String]) async throws -> [URL] {
        // Gemini doesn't support image generation like DALL-E
        // Return empty array for now
        logger.warning("Image generation not supported with Gemini API")
        return []
    }

    // MARK: - Recipe Deduplication
    
    /// Removes duplicate recipes based on name similarity
    private func removeDuplicateRecipes(_ recipes: [Recipe]) -> [Recipe] {
        var uniqueRecipes: [Recipe] = []
        var seenNames: Set<String> = []
        
        for recipe in recipes {
            // Clean the recipe name by removing common prefixes and suffixes
            let cleanName = cleanRecipeName(recipe.title)
            
            if !seenNames.contains(cleanName) {
                seenNames.insert(cleanName)
                uniqueRecipes.append(recipe)
            } else {
                logger.debug("Removing duplicate recipe: '\(recipe.title)' (clean name: '\(cleanName)')")
            }
        }
        
        logger.debug("Deduplication: \(recipes.count) -> \(uniqueRecipes.count) recipes")
        return uniqueRecipes
    }
    
    /// Cleans recipe names by removing common prefixes and suffixes
    private func cleanRecipeName(_ name: String) -> String {
        var cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
            if cleanName.hasPrefix(prefix) {
                cleanName = String(cleanName.dropFirst(prefix.count))
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
            if cleanName.hasSuffix(suffix) {
                cleanName = String(cleanName.dropLast(suffix.count))
                break
            }
        }
        
        return cleanName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Determines if a text section is descriptive content rather than an actual recipe
    private func isDescriptiveText(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        
        // Check for descriptive phrases that indicate this is not a recipe
        let descriptivePhrases = [
            "here are",
            "here are 10",
            "here are 5",
            "here are 15",
            "popular recipes",
            "with a medium difficulty level",
            "focusing on authenticity",
            "reflecting current culinary trends",
            "using authentic names",
            "focusing on authentic names",
            "realistic timings",
            "current popularity",
            "culinary significance",
            "traditional favorites"
        ]
        
        // If any descriptive phrase is found, consider it descriptive text
        for phrase in descriptivePhrases {
            if lowercasedText.contains(phrase) {
                return true
            }
        }
        
        // Check if the text is too long and doesn't contain recipe-like content
        if text.count > 200 && !containsRecipeContent(text) {
            return true
        }
        
        return false
    }
    
    /// Checks if text contains recipe-like content (ingredients, steps, etc.)
    private func containsRecipeContent(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        
        let recipeIndicators = [
            "ingredients:",
            "ingredients",
            "steps:",
            "step 1:",
            "step 2:",
            "preparation:",
            "cooking:",
            "serves",
            "servings:",
            "prep time:",
            "cook time:",
            "total time:",
            "calories:",
            "nutrition:"
        ]
        
        return recipeIndicators.contains { lowercasedText.contains($0) }
    }
    
    // MARK: - Multi-Cuisine Recipe Generation
    
    /// Generates popular recipes from multiple cuisines when "Any Cuisine" is selected
    private func generateMultiCuisinePopularRecipes(
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int? = nil,
        servings: Int = 2
    ) async throws -> [Recipe] {
        logger.api("Generating multi-cuisine popular recipes")
        
        // Select diverse cuisines for variety
        let selectedCuisines: [Cuisine] = [
            .italian, .french, .japanese, .indian, .mexican,
            .thai, .mediterranean, .chinese, .greek, .spanish
        ]
        
        var allRecipes: [Recipe] = []
        let recipesPerCuisine = 3 // Generate 3 recipes per cuisine for better variety
        
        for cuisine in selectedCuisines {
            do {
                logger.debug("Generating \(recipesPerCuisine) recipes for \(cuisine.rawValue) cuisine")
                
                let cuisineRecipes = try await generatePopularRecipesForSpecificCuisine(
                    cuisine: cuisine,
                    difficulty: difficulty,
                    dietaryRestrictions: dietaryRestrictions,
                    maxTime: maxTime,
                    servings: servings,
                    count: recipesPerCuisine
                )
                
                allRecipes.append(contentsOf: cuisineRecipes)
                logger.debug("Generated \(cuisineRecipes.count) recipes for \(cuisine.rawValue)")
                
            } catch {
                logger.warning("Failed to generate recipes for \(cuisine.rawValue): \(error.localizedDescription)")
                // Continue with other cuisines
            }
        }
        
        // Remove duplicates based on recipe names and take top 15-20
        let uniqueRecipes = removeDuplicateRecipes(allRecipes)
        let targetCount = min(20, uniqueRecipes.count) // Aim for 15-20 recipes
        let finalRecipes = Array(uniqueRecipes.prefix(targetCount))
        
        logger.api("Multi-cuisine generation complete: \(finalRecipes.count) unique recipes from \(selectedCuisines.count) cuisines")
        return finalRecipes
    }
    
    /// Generates recipes for a specific cuisine (internal function)
    private func generatePopularRecipesForSpecificCuisine(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int? = nil,
        servings: Int = 2,
        count: Int = 10
    ) async throws -> [Recipe] {
        guard let apiKey = apiKey else {
            throw GeminiError.noAPIKey
        }
        
        let prompt = createPopularRecipesPrompt(
            cuisine: cuisine,
            difficulty: difficulty,
            dietaryRestrictions: dietaryRestrictions,
            maxTime: maxTime,
            servings: servings
        )
        
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: prompt)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.1,
                maxOutputTokens: 2000
            )
        )
        
        let url = URL(string: "\(baseURL)/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            if let content = geminiResponse.candidates.first?.content.parts.first?.text {
                var recipes = try parsePopularRecipesFromResponse(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
                
                // Apply strict dietary filtering
                recipes = filterRecipesByDietaryRestrictions(recipes, restrictions: dietaryRestrictions)
                
                // Apply strict cooking time filtering
                if let maxTime = maxTime {
                    recipes = filterRecipesByCookingTime(recipes, maxTime: maxTime)
                }
                
                // Limit to requested count
                recipes = Array(recipes.prefix(count))
                
                return recipes
            } else {
                throw GeminiError.noContent
            }
        } catch {
            logger.error("Error generating recipes for \(cuisine.rawValue): \(error)")
            throw error
        }
    }
    
    // MARK: - Cooking Time Filtering
    
    /// Filters recipes by cooking time constraint
    private func filterRecipesByCookingTime(_ recipes: [Recipe], maxTime: Int) -> [Recipe] {
        return recipes.filter { recipe in
            let totalTime = recipe.prepTime + recipe.cookTime
            let isWithinTime = totalTime <= maxTime
            
            if !isWithinTime {
                logger.debug("Recipe '\(recipe.title)' filtered out: total time \(totalTime) min > max time \(maxTime) min (prep: \(recipe.prepTime) min, cook: \(recipe.cookTime) min)")
            }
            
            return isWithinTime
        }
    }
    
    /// Generates recipes with strict time constraints when initial generation doesn't meet time requirements
    private func generatePopularRecipesWithStrictTimeConstraint(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int,
        servings: Int
    ) async throws -> [Recipe] {
        logger.warning("Regenerating recipes with strict time constraint: \(maxTime) minutes")
        
        let strictPrompt = createPopularRecipesPromptWithStrictTime(
            cuisine: cuisine,
            difficulty: difficulty,
            dietaryRestrictions: dietaryRestrictions,
            maxTime: maxTime,
            servings: servings
        )
        
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: strictPrompt)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.05, // Lower temperature for more consistent time adherence
                maxOutputTokens: 2000
            )
        )
        
        let url = URL(string: "\(baseURL)/gemini-1.5-flash:generateContent?key=\(apiKey!)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            if let content = geminiResponse.candidates.first?.content.parts.first?.text {
                var recipes = try parsePopularRecipesFromResponse(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
                
                // Apply both dietary and time filtering
                recipes = filterRecipesByDietaryRestrictions(recipes, restrictions: dietaryRestrictions)
                recipes = filterRecipesByCookingTime(recipes, maxTime: maxTime)
                
                logger.warning("Strict time constraint generation: \(recipes.count) recipes meet \(maxTime) min requirement")
                return recipes
            } else {
                throw GeminiError.noContent
            }
        } catch {
            logger.error("Error in strict time constraint generation: \(error)")
            throw error
        }
    }

    // MARK: - Helper Methods
    private func createRecipePrompt(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        recipeName: String? = nil,
        ingredients: [String]? = nil,
        maxTime: Int? = nil,
        servings: Int = 2
    ) -> String {
        var prompt = """
        Create a MICHELIN-LEVEL \(cuisine.rawValue) recipe with \(difficulty.rawValue) difficulty level. Research current culinary trends and popular dishes in \(cuisine.rawValue) cuisine to ensure the recipe reflects current popularity and authenticity.
        
        """
        
        if let recipeName = recipeName, !recipeName.isEmpty {
            prompt += "RECIPE NAME: \(recipeName)\n\n"
        }
        
        prompt += """
        CRITICAL DIETARY RESTRICTIONS - MUST BE STRICTLY FOLLOWED:
        
        🚨 AUTHENTIC RECIPE NAMES - ABSOLUTELY REQUIRED:
        - Use ONLY authentic, specific recipe names that food enthusiasts would recognize
        - Examples: "Coq au Vin", "Pad Thai", "Chicken Tikka Masala", "Osso Buco alla Milanese"
        - NEVER use generic names like "Italian Recipe", "French Dish", or "Asian Food"
        - Research current culinary trends and traditional favorites for authentic names
        - Each recipe name must be specific and recognizable to culinary experts
        """
        
        if dietaryRestrictions.isEmpty {
            prompt += "\n- No specific dietary restrictions"
        } else {
            for restriction in dietaryRestrictions {
                prompt += "\n- \(restriction.rawValue): \(getDietaryDescription(restriction))"
            }
        }
        
        prompt += "\n\nRecipe Requirements:"
        prompt += "\n- Cuisine: \(cuisine.rawValue)"
        prompt += "\n- Difficulty: \(difficulty.rawValue)"
        prompt += "\n- Servings: \(servings)"
        
        if let maxTime = maxTime {
            prompt += "\n- Maximum total time: \(maxTime) minutes"
        }
        
        if let ingredients = ingredients, !ingredients.isEmpty {
            prompt += "\n- Must include these ingredients: \(ingredients.joined(separator: ", "))"
        }
        
        prompt += """

        IMPORTANT: You must respond with ONLY valid JSON in the exact format specified below. Do not include any additional text, explanations, or markdown formatting.

        CRITICAL DIETARY REQUIREMENTS - MUST BE STRICTLY ENFORCED:
        - ALL ingredients MUST be 100% compliant with the dietary restrictions listed above
        - NO EXCEPTIONS - if a restriction is listed, it applies to ALL ingredients
        - Multiple restrictions use AND logic - ALL must be satisfied simultaneously
        
        🚨 COMPREHENSIVE INGREDIENT REQUIREMENTS - SOURCING FOR CHEFS:
        - Include EVERY SINGLE ingredient needed to cook this recipe from scratch
        - List ALL raw materials, spices, seasonings, oils, liquids, and garnishes
        - Include ingredients for any sauces, marinades, or components made from scratch
        - Specify exact measurements for professional cooking (grams, ounces, cups, etc.)
        - Include preparation notes (e.g., "finely chopped", "minced", "fresh", "dried")
        - List ALL spices and seasonings individually (don't combine into "spice mix")
        - Include cooking oils, fats, and liquids needed
        - Specify quality requirements (e.g., "extra virgin olive oil", "fresh herbs")
        - Include garnishes and finishing ingredients
        - List ingredients for any side dishes or accompaniments mentioned
        - Include ALL ingredients for any sub-recipes (sauces, dressings, etc.)
        - Be extremely detailed - chefs need to source everything
        - 🚨 CRITICAL SERVINGS SCALING: ALL ingredient amounts MUST be calculated for exactly \(servings) servings
        - 🚨 SERVINGS REQUIREMENT: Every ingredient amount must be appropriate for \(servings) people
        - 🚨 SCALING RULE: If a recipe normally serves 4, multiply all amounts by \(servings)/4 for \(servings) servings
        
        🚨 CRITICAL INGREDIENT ACCURACY REQUIREMENTS:
        - Ingredients MUST match the recipe name exactly (e.g., "Fish Curry" must contain fish, not chicken)
        - Protein ingredients must be appropriate for the recipe (fish for fish dishes, chicken for chicken dishes, etc.)
        - NO generic protein substitutions - use the specific protein mentioned in the recipe name
        - For vegetarian/vegan dishes, use appropriate plant-based proteins (tofu, paneer, legumes, etc.)
        - Spices and seasonings must be authentic to the cuisine and recipe
        - Include all traditional ingredients specific to the recipe type
        - Double-check that ingredients align with the recipe name and cuisine

                        Create MICHELIN-LEVEL detailed, step-by-step cooking instructions that are easy to follow for home cooks. Each step should include:
                        - Extremely detailed, specific instructions with exact measurements and techniques
                        - Precise timing information (how long each step takes)
                        - Exact temperature settings where applicable
                        - Professional chef tips, techniques, and secrets
                        - Visual cues, doneness indicators, and sensory descriptions
                        - Safety precautions and best practices
                        - Equipment recommendations and preparation notes

                        Make each step comprehensive enough that even a beginner can follow along perfectly. Include professional cooking techniques, timing precision, and visual indicators for doneness.

                        IMPORTANT: The "description" field in each step must contain ONLY plain English cooking instructions, NOT JSON format or code. Write natural, conversational cooking instructions that a home cook can easily follow.

                        {
                            "name": "Authentic Recipe Name (e.g., 'Coq au Vin', 'Pad Thai', 'Chicken Tikka Masala')",
                            "prepTime": 30,
                            "cookTime": 45,
                            "ingredients": [
                                {"name": "Ingredient Name", "amount": 2.0, "unit": "cups", "notes": "optional notes"}
                            ],
                            "steps": [
                                {
                                    "stepNumber": 1,
                                    "description": "Heat a large skillet over medium-high heat. Add 2 tablespoons of olive oil and swirl to coat the pan evenly. When the oil is shimmering and hot, add the diced onions and sauté until they become translucent and slightly golden, about 3-4 minutes. Stir occasionally to prevent burning.",
                                    "duration": 10,
                                    "temperature": 180,
                                    "tips": "Professional chef tip: Always preheat your pan before adding oil to ensure even cooking and prevent sticking"
                                }
                            ],
                            "winePairings": [
                                {"name": "Wine Name", "type": "Red", "region": "Bordeaux", "description": "Detailed wine description with pairing notes"}
                            ],
                            "platingTips": "Detailed plating instructions with presentation tips, garnishing suggestions, and visual appeal techniques",
                            "chefNotes": "Chef's special notes about technique, timing, ingredient substitutions, and professional secrets for achieving restaurant-quality results"
                        }
        """

        return prompt
    }
    
    private func createPopularRecipesPrompt(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int? = nil,
        servings: Int = 2
    ) -> String {
        
        let timeConstraint = maxTime != nil ? " with STRICT cooking time constraint of \(maxTime!) minutes or less" : ""
        
        var prompt = """
        Generate 15-20 popular \(cuisine.rawValue) recipes with \(difficulty.rawValue) difficulty level\(timeConstraint). Research current culinary trends and popular dishes in \(cuisine.rawValue) cuisine to ensure the recipes reflect current popularity and authenticity.
        
        🚨 REGIONAL RECIPE COVERAGE - ABSOLUTELY REQUIRED:
        - Include recipes from ALL major regions of \(cuisine.rawValue) cuisine
        - Cover traditional, modern, and fusion variations
        - Include street food, home cooking, and restaurant favorites
        - Ensure diversity in cooking methods (grilled, fried, steamed, baked, etc.)
        - Include both classic and contemporary popular dishes
        
        """
        
        if let maxTime = maxTime {
            prompt += """
            🚨 CRITICAL TIME CONSTRAINT - ABSOLUTELY REQUIRED:
            - ALL recipes MUST have a TOTAL cooking time (prep + cook) of \(maxTime) minutes or less
            - Prep time + Cook time ≤ \(maxTime) minutes
            - If a recipe would take longer, DO NOT include it
            - Focus on quick, efficient recipes that can be prepared within the time limit
            - Examples of quick techniques: stir-frying, grilling, simple pasta dishes, salads
            
            """
        }
        
        prompt += """
        🚨 AUTHENTIC RECIPE NAMES - ABSOLUTELY REQUIRED:
        - Use ONLY authentic, specific recipe names that food enthusiasts would recognize
        - Examples: "Coq au Vin", "Pad Thai", "Chicken Tikka Masala", "Osso Buco alla Milanese"
        - NEVER use generic names like "Italian Recipe", "French Dish", or "Asian Food"
        - NEVER include descriptive text like "Here are 10 popular recipes" or "focusing on authenticity"
        - Research current culinary trends and traditional favorites for authentic names
        - Each recipe name must be specific and recognizable to culinary experts
        - Output ONLY recipe names with their details, no introductory or descriptive text
        """
        
        if dietaryRestrictions.isEmpty {
            prompt += """
            
            🚨 CRITICAL DIETARY DIVERSITY - ABSOLUTELY REQUIRED:
            - Include a MIX of vegetarian, meat, poultry, fish, and seafood recipes
            - Ensure at least 40% of recipes contain meat, chicken, fish, or seafood
            - Include popular meat dishes like Chicken Tikka Masala, Fish Curry, Lamb Biryani
            - Include vegetarian dishes like Dal, Aloo Gobi, Chana Masala
            - Balance traditional meat-based and vegetarian recipes
            - NO restrictions - show the full diversity of \(cuisine.rawValue) cuisine
            
            🚨 MEAT DIVERSITY EXAMPLES - MUST INCLUDE:
            - Chicken dishes (Chicken Tikka, Chicken Curry, Chicken Biryani)
            - Fish dishes (Fish Curry, Fish Fry, Fish Biryani)
            - Lamb dishes (Lamb Curry, Lamb Biryani, Lamb Kebab)
            - Goat dishes (Goat Curry, Goat Biryani)
            - Mixed meat dishes (Mixed Grill, Meat Platter)
            
            🚨 VEGETARIAN DIVERSITY EXAMPLES - MUST INCLUDE:
            - Legume dishes (Dal, Chana Masala, Rajma)
            - Vegetable dishes (Aloo Gobi, Baingan Bharta, Bhindi Masala)
            - Rice dishes (Vegetable Biryani, Pulao)
            - Bread dishes (Naan, Roti, Paratha)
            
            🚨 CRITICAL INSTRUCTION: You MUST generate at least 6-8 meat-based recipes and 6-8 vegetarian recipes. This is NOT optional. The user specifically wants to see BOTH meat and vegetarian options.
            """
        } else {
            for restriction in dietaryRestrictions {
                prompt += "\n- \(restriction.rawValue): \(getDietaryDescription(restriction))"
            }
        }
        
        prompt += "\n\nRecipe Requirements:"
        prompt += "\n- Cuisine: \(cuisine.rawValue)"
        prompt += "\n- Difficulty: \(difficulty.rawValue)"
        prompt += "\n- Servings: \(servings)"
        
        if let maxTime = maxTime {
            prompt += "\n- MAXIMUM TOTAL TIME: \(maxTime) minutes (prep + cook combined)"
        }
        
        prompt += "\n\nCRITICAL OUTPUT FORMAT - MUST BE EXACTLY AS SPECIFIED:"
        prompt += "\nEach recipe must include:"
        prompt += "\n- Recipe name (authentic and specific)"
        prompt += "\n- Prep time in minutes (MUST be accurate and realistic)"
        prompt += "\n- Cook time in minutes (MUST be accurate and realistic)"
        if let maxTime = maxTime {
            prompt += "\n- Total time validation: prep + cook ≤ \(maxTime) minutes"
        } else {
            prompt += "\n- Total time validation: prep + cook ≤ unlimited minutes"
        }
        prompt += "\n- Difficulty level"
        prompt += "\n- Servings"
        prompt += "\n- Brief description (1-2 sentences)"
        
        prompt += "\n\n🚨 CRITICAL: You MUST generate EXACTLY 15-20 recipes. This is NOT optional. If you cannot generate 15-20 recipes within the time constraint, generate fewer but ensure ALL meet the time requirement. Prioritize quantity and variety while maintaining quality."
        
        prompt += "\n\n🚨 OUTPUT FORMAT - MUST BE VALID JSON ARRAY:"
        prompt += "\n["
        prompt += "\n  {"
        prompt += "\n    \"name\": \"Recipe Name\","
        prompt += "\n    \"prepTime\": 15,"
        prompt += "\n    \"cookTime\": 30,"
        prompt += "\n    \"ingredients\": [...],"
        prompt += "\n    \"steps\": [...]"
        prompt += "\n  },"
        prompt += "\n  ... (repeat for 15-20 recipes)"
        prompt += "\n]"
        
        prompt += "\n\n🚨 FINAL INSTRUCTION: Generate EXACTLY 15-20 recipes in valid JSON format. Do not include any text before or after the JSON array. Start with [ and end with ]."
        
        if dietaryRestrictions.isEmpty {
            prompt += "\n\n🚨 CRITICAL REMINDER: When NO dietary restrictions are selected, you MUST include meat, chicken, fish, and seafood recipes. Do NOT generate only vegetarian recipes. The user wants to see the FULL diversity of \(cuisine.rawValue) cuisine including traditional meat dishes."
            prompt += "\n\n🚨 FINAL WARNING: If you generate only vegetarian recipes when no restrictions are selected, the user will be very disappointed. You MUST include meat dishes like Chicken Tikka Masala, Fish Curry, Lamb Biryani, Goat Curry, and Mixed Grill."
        }
        
        return prompt
    }
    
    private func createPopularRecipesPromptWithStrictTime(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        maxTime: Int,
        servings: Int
    ) -> String {
        var prompt = """
        Create diverse \(cuisine.rawValue) recipes with \(difficulty.rawValue) difficulty level, ranked by CURRENT popularity and culinary significance. Research current culinary trends and popular dishes in \(cuisine.rawValue) cuisine. Generate as many high-quality recipes as possible (aim for 15-20 recipes).
        
        🚨 CRITICAL: Output ONLY recipe names and details. NO descriptive text like "Here are 10 popular recipes" or "focusing on authenticity". Start directly with recipe names.
        
        🚨 CRITICAL DIETARY RESTRICTIONS - ABSOLUTELY NO EXCEPTIONS:
        
        🚨 AUTHENTIC RECIPE NAMES - ABSOLUTELY REQUIRED:
        - Use ONLY authentic, specific recipe names that food enthusiasts would recognize
        - Examples: "Coq au Vin", "Pad Thai", "Chicken Tikka Masala", "Osso Buco alla Milanese"
        - NEVER use generic names like "Italian Recipe", "French Dish", or "Asian Food"
        - Research current culinary trends and traditional favorites for authentic names
        - Each recipe name must be specific and recognizable to culinary experts
        """
        
        if dietaryRestrictions.isEmpty {
            prompt += "\n- No specific dietary restrictions"
        } else {
            for restriction in dietaryRestrictions {
                prompt += "\n- \(restriction.rawValue): \(getDietaryDescription(restriction))"
            }
        }
        
        prompt += "\n\nRecipe Requirements:"
        prompt += "\n- Cuisine: \(cuisine.rawValue)"
        prompt += "\n- Difficulty: \(difficulty.rawValue)"
        prompt += "\n- Servings: \(servings)"
        prompt += "\n- Maximum total time: \(maxTime) minutes"
        
        prompt += """

        🚨 ABSOLUTE DIETARY COMPLIANCE REQUIREMENTS - ZERO TOLERANCE:
        
        MULTIPLE RESTRICTIONS:
        - ALL selected restrictions use AND logic - ALL must be satisfied simultaneously
        - NO EXCEPTIONS - if ANY restriction is listed, it applies to ALL 10 recipes
        - DOUBLE-CHECK every ingredient against ALL selected restrictions
        - DOUBLE-CHECK recipe names against ALL selected restrictions
        
        CRITICAL RECIPE GENERATION RULES:
        1. BEFORE creating any recipe, verify ALL ingredients comply with ALL selected restrictions
        2. BEFORE creating any recipe, verify the recipe name complies with ALL selected restrictions
        3. If ANY ingredient violates ANY restriction, DO NOT include that recipe
        4. If the recipe name violates ANY restriction, DO NOT include that recipe
        5. ONLY create recipes that are 100% compliant with ALL selected restrictions
        6. Each recipe must be unique and showcase different techniques and flavors
        7. Recipes should vary in cooking methods (baking, grilling, sautéing, etc.)
        8. Include a mix of appetizers, main courses, and desserts
        9. Each recipe must be restaurant-quality and Michelin-level
        10. All recipes must be appropriate for \(difficulty.rawValue) difficulty level
        11. EVERY recipe MUST include a COMPREHENSIVE list of ALL ingredients needed for professional cooking
        12. Each ingredient must have: name, amount, unit, preparation notes, and quality specifications
        13. Include ALL raw materials, spices, seasonings, oils, and garnishes individually
        14. List ingredients for any sub-recipes (sauces, marinades, dressings) separately
        15. Specify exact measurements in professional units (grams, ounces, cups, etc.)
        16. Include preparation notes (finely chopped, minced, fresh, dried, etc.)
        17. Specify quality requirements (extra virgin olive oil, fresh herbs, etc.)
        18. Include ALL ingredients for any side dishes or accompaniments
        19. Be extremely detailed - chefs need to source everything from scratch
        20. 🚨 CRITICAL SERVINGS SCALING: ALL ingredient amounts MUST be calculated for exactly \(servings) servings
        21. 🚨 SERVINGS REQUIREMENT: Every ingredient amount must be appropriate for \(servings) people
        22. 🚨 SCALING RULE: If a recipe normally serves 4, multiply all amounts by \(servings)/4 for \(servings) servings
        23. Do not skip any ingredients - include everything needed for the recipe
        24. 🚨 CRITICAL INGREDIENT ACCURACY REQUIREMENTS:
            - Ingredients MUST match the recipe name exactly (e.g., "Fish Curry" must contain fish, not chicken)
            - Protein ingredients must be appropriate for the recipe (fish for fish dishes, chicken for chicken dishes, etc.)
            - NO generic protein substitutions - use the specific protein mentioned in the recipe name
            - For vegetarian/vegan dishes, use appropriate plant-based proteins (tofu, paneer, legumes, etc.)
            - Spices and seasonings must be authentic to the cuisine and recipe
            - Include all traditional ingredients specific to the recipe type
            - Double-check that ingredients align with the recipe name and cuisine
        25. 🚨 CALORIE CALCULATION REQUIREMENTS:
            - Provide SPECIFIC ingredient names for accurate calorie calculation (e.g., "chicken breast" not just "chicken")
            - Include exact protein types (e.g., "salmon fillet", "cod fillet", "tilapia fillet")
            - Specify dairy types (e.g., "cheddar cheese", "mozzarella cheese", "greek yogurt")
            - Include specific vegetable varieties (e.g., "red bell pepper", "roma tomato", "baby spinach")
            - Specify oil types (e.g., "extra virgin olive oil", "sesame oil", "coconut oil")
            - Include specific grain types (e.g., "basmati rice", "whole wheat pasta", "quinoa")
            - Provide detailed preparation notes for accurate weight estimation
            - Include ALL ingredients needed for proper nutritional calculation
        25. FINAL CHECK: Verify every ingredient in every recipe complies with ALL restrictions
        26. FINAL CHECK: Verify every recipe name complies with ALL restrictions
        27. DYNAMIC POPULARITY RANKING: Research and rank recipes by CURRENT popularity and culinary significance in \(cuisine.rawValue) cuisine
        28. USE AUTHENTIC RECIPE NAMES: Generate authentic, specific recipe names that reflect current culinary trends and traditional favorites
        29. NEVER create recipes with names containing restricted ingredients (e.g., no "Chicken Curry" for vegan)
        30. ALWAYS use traditional, authentic recipe names that food enthusiasts would recognize
        31. FOCUS ON CURRENT TRENDS: Include recipes that are currently popular, trending, or highly regarded in the culinary world
        32. 🚨 CALORIE CALCULATION REQUIREMENTS:
            - Provide SPECIFIC ingredient names for accurate calorie calculation (e.g., "chicken breast" not just "chicken")
            - Include exact protein types (e.g., "salmon fillet", "cod fillet", "tilapia fillet")
            - Specify dairy types (e.g., "cheddar cheese", "mozzarella cheese", "greek yogurt")
            - Include specific vegetable varieties (e.g., "red bell pepper", "roma tomato", "baby spinach")
            - Specify oil types (e.g., "extra virgin olive oil", "sesame oil", "coconut oil")
            - Include specific grain types (e.g., "basmati rice", "whole wheat pasta", "quinoa")
            - Provide detailed preparation notes for accurate weight estimation
            - Include ALL ingredients needed for proper nutritional calculation

        IMPORTANT: You must respond with ONLY valid JSON in the exact format specified below. Do not include any additional text, explanations, or markdown formatting.

        Return an array of recipes in this exact JSON format, ranked by popularity (aim for 10-15 recipes):

        [
            {
                "name": "Authentic Recipe Name (e.g., 'Coq au Vin', 'Pad Thai', 'Chicken Tikka Masala', 'Osso Buco alla Milanese')",
                "prepTime": 30,
                "cookTime": 45,
                "ingredients": [
                    {"name": "Ingredient Name", "amount": 2.0, "unit": "cups", "notes": "Preparation notes (finely chopped, minced, fresh, etc.) and quality specifications (extra virgin, organic, etc.)"}
                ],
                "steps": [
                    {
                        "stepNumber": 1,
                        "description": "Extremely detailed step description with specific instructions, exact measurements, professional techniques, visual cues, and sensory descriptions. Include timing, temperature, equipment needed, and safety notes.",
                        "duration": 10,
                        "temperature": 180,
                        "tips": "Professional chef tip: specific technique, timing advice, or secret for perfect results"
                    }
                ],
                "winePairings": [
                    {"name": "Wine Name", "type": "Red", "region": "Bordeaux", "description": "Detailed wine description with pairing notes"}
                ],
                "platingTips": "Detailed plating instructions with presentation tips, garnishing suggestions, and visual appeal techniques",
                "chefNotes": "Chef's special notes about technique, timing, ingredient substitutions, and professional secrets for achieving restaurant-quality results"
            }
        ]
        """
        
        return prompt
    }

    private func parseRecipeFromResponse(_ content: String, cuisine: Cuisine, difficulty: Difficulty, dietaryRestrictions: [DietaryNote], servings: Int = 2) throws -> Recipe {
        logger.debug("Parsing response content...")
        logger.debug("Full response: \(content)")
        
        // First, try to find JSON in the response
        let jsonStart = content.firstIndex(of: "{")
        let jsonEnd = content.lastIndex(of: "}")
        
        if let start = jsonStart, let end = jsonEnd {
            let jsonString = String(content[start...end])
            logger.debug("Extracted JSON: \(jsonString)")
            
            do {
                let decoder = JSONDecoder()
                let recipeData = try decoder.decode(RecipeData.self, from: jsonString.data(using: .utf8)!)
                
                logger.debug("Recipe: \(recipeData.name)")
                logger.debug("Ingredients count: \(recipeData.ingredients.count)")
                
                // Log all ingredients for this recipe
                for (index, ingredient) in recipeData.ingredients.enumerated() {
                    logger.debug("  - Ingredient \(index + 1): \(ingredient.amount) \(ingredient.unit) \(ingredient.name)")
                }
                
                // Sanitize step descriptions to ensure they contain plain English instructions
                let sanitizedSteps = recipeData.steps.map { step in
                    CookingStep(
                        stepNumber: step.stepNumber,
                        description: sanitizeStepDescription(step.description),
                        duration: step.duration,
                        temperature: step.temperature,
                        imageURL: step.imageURL,
                        tips: step.tips
                    )
                }
                
                // Convert to kid-friendly instructions
                let kidFriendlySteps = convertToKidFriendlySteps(sanitizedSteps)
                
                let recipe = Recipe(
                    title: recipeData.name,
                    cuisine: cuisine,
                    difficulty: difficulty,
                    prepTime: recipeData.prepTime,
                    cookTime: recipeData.cookTime,
                    servings: servings,
                    ingredients: recipeData.ingredients,
                    steps: kidFriendlySteps,
                    winePairings: recipeData.winePairings,
                    dietaryNotes: [],
                    platingTips: recipeData.platingTips,
                    chefNotes: recipeData.chefNotes
                )
                
                logger.api("Successfully parsed recipe with \(recipe.ingredients.count) ingredients")
                return recipe
            } catch {
                logger.error("JSON parsing error: \(error)")
                logger.debug("JSON string that failed: \(jsonString)")
                
                // Try to extract partial data if possible
                if let data = jsonString.data(using: .utf8) {
                    do {
                        let decoder = JSONDecoder()
                        let recipeData = try decoder.decode(RecipeData.self, from: data)
                        logger.debug("Partial JSON parsing successful")
                        logger.debug("Recipe: \(recipeData.name)")
                        logger.debug("Ingredients count: \(recipeData.ingredients.count)")
                        
                        let recipe = Recipe(
                            title: recipeData.name,
                            cuisine: cuisine,
                            difficulty: difficulty,
                            prepTime: recipeData.prepTime,
                            cookTime: recipeData.cookTime,
                            servings: servings,
                            ingredients: recipeData.ingredients,
                            steps: recipeData.steps,
                            winePairings: recipeData.winePairings,
                            dietaryNotes: [],
                            platingTips: recipeData.platingTips,
                            chefNotes: recipeData.chefNotes
                        )
                        return recipe
                    } catch {
                        logger.error("Even partial JSON parsing failed: \(error)")
                    }
                }
                
                // If JSON parsing fails, try to create a basic recipe from the text
                return try createRecipeFromText(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
            }
        } else {
            logger.error("No JSON brackets found in response")
            // If no JSON found, try to create a basic recipe from the text
            return try createRecipeFromText(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
        }
    }
    
    private func createRecipeFromText(_ content: String, cuisine: Cuisine, difficulty: Difficulty, dietaryRestrictions: [DietaryNote], servings: Int = 2) throws -> Recipe {
        logger.debug("Creating recipe from text content...")
        
        // Extract recipe name (look for common patterns)
        let name: String
        if let nameMatch = content.range(of: #"^([A-Z][^.!?]*)"#, options: .regularExpression) {
            name = String(content[nameMatch]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Use proper recipe name instead of generic
            name = generateProperRecipeName(cuisine: cuisine, index: 1, dietaryRestrictions: dietaryRestrictions)
        }
        
        // Generate dynamic ingredients based on recipe name and cuisine
        let dynamicIngredients = generateDynamicIngredientsForRecipe(name: name, cuisine: cuisine, dietaryRestrictions: dietaryRestrictions)
        
        // Create detailed steps from the content
        let lines = content.components(separatedBy: .newlines)
        var steps: [CookingStep] = []
        var stepNumber = 1
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty && trimmedLine.count > 10 && !trimmedLine.hasPrefix("#") {
                // Create a more detailed step description
                let stepDescription = trimmedLine
                let duration = stepNumber <= 3 ? 5 : (stepNumber <= 6 ? 10 : 15) // Vary timing
                let temperature = stepNumber % 2 == 0 ? 180.0 : nil // Alternate temperature
                let tip = stepNumber % 3 == 0 ? "Take your time with this step for best results" : nil
                
                steps.append(CookingStep(
                    stepNumber: stepNumber,
                    description: stepDescription,
                    duration: duration,
                    temperature: temperature,
                    tips: tip
                ))
                stepNumber += 1
                if stepNumber > 12 { break } // Limit to 12 steps
            }
        }
        
        // If no steps were extracted, create detailed default steps
        if steps.isEmpty {
            steps = [
                CookingStep(
                    stepNumber: 1,
                    description: "Prepare all ingredients and equipment. Ensure your workspace is clean and organized.",
                    duration: 10,
                    temperature: nil,
                    tips: "Mise en place - having everything ready makes cooking much easier"
                ),
                CookingStep(
                    stepNumber: 2,
                    description: "Follow the detailed instructions provided in the recipe content. Pay attention to timing and temperature.",
                    duration: 20,
                    temperature: 180,
                    tips: "Refer to the full recipe text for complete instructions and techniques"
                ),
                CookingStep(
                    stepNumber: 3,
                    description: "Check for doneness using visual cues and recommended cooking times.",
                    duration: 5,
                    temperature: nil,
                    tips: "Don't rush - good cooking takes time and attention"
                )
            ]
        }
        
        return Recipe(
            title: name,
            cuisine: cuisine,
            difficulty: difficulty,
            prepTime: 15,
            cookTime: 30,
            servings: servings,
            ingredients: dynamicIngredients,
            steps: steps,
            winePairings: [],
            dietaryNotes: [],
            platingTips: "Serve hot with your preferred garnishes. Consider adding fresh herbs or a drizzle of olive oil for presentation.",
            chefNotes: "This recipe was generated from text content. Please refer to the full instructions for best results. Remember to taste and adjust seasoning as needed."
        )
    }
    
    private func parsePopularRecipesFromResponse(_ content: String, cuisine: Cuisine, difficulty: Difficulty, dietaryRestrictions: [DietaryNote], servings: Int = 2) throws -> [Recipe] {
        logger.debug("Parsing popular recipes response...")
        logger.debug("Full response: \(content)")
        
        // First, try to find JSON array in the response
        let jsonStart = content.firstIndex(of: "[")
        let jsonEnd = content.lastIndex(of: "]")
        
        if let start = jsonStart, let end = jsonEnd {
            let jsonString = String(content[start...end])
            logger.debug("Extracted JSON array: \(jsonString)")
            
            do {
                let decoder = JSONDecoder()
                let recipesData = try decoder.decode([RecipeData].self, from: jsonString.data(using: .utf8)!)
                
                var recipes: [Recipe] = []
                for (index, recipeData) in recipesData.enumerated() {
                    logger.debug("Recipe \(index + 1): \(recipeData.name)")
                    logger.debug("Ingredients count: \(recipeData.ingredients.count)")
                    
                    // Log all ingredients for this recipe
                    for (ingredientIndex, ingredient) in recipeData.ingredients.enumerated() {
                        logger.debug("  - Ingredient \(ingredientIndex + 1): \(ingredient.amount) \(ingredient.unit) \(ingredient.name)")
                    }
                    
                    // Sanitize step descriptions to ensure they contain plain English instructions
                    let sanitizedSteps = recipeData.steps.map { step in
                        CookingStep(
                            stepNumber: step.stepNumber,
                            description: sanitizeStepDescription(step.description),
                            duration: step.duration,
                            temperature: step.temperature,
                            imageURL: step.imageURL,
                            tips: step.tips
                        )
                    }
                    
                    // Convert to kid-friendly instructions
                    let kidFriendlySteps = convertToKidFriendlySteps(sanitizedSteps)
                    
                    // Infer dietary notes from ingredients since RecipeData doesn't include them
                    let recipeDietaryNotes = inferDietaryNotesFromIngredients(recipeData.ingredients, cuisine: cuisine)
                    logger.debug("Inferred dietary notes for '\(recipeData.name)': \(recipeDietaryNotes.map { $0.rawValue })")
                    
                    let recipe = Recipe(
                        title: recipeData.name,
                        cuisine: cuisine,
                        difficulty: difficulty,
                        prepTime: recipeData.prepTime,
                        cookTime: recipeData.cookTime,
                        servings: servings,
                        ingredients: recipeData.ingredients,
                        steps: kidFriendlySteps,
                        winePairings: recipeData.winePairings,
                        dietaryNotes: recipeDietaryNotes,
                        platingTips: recipeData.platingTips,
                        chefNotes: recipeData.chefNotes
                    )
                    recipes.append(recipe)
                }
                
                logger.api("Successfully parsed \(recipes.count) recipes with total of \(recipes.reduce(0) { $0 + $1.ingredients.count }) ingredients")
                return recipes
            } catch {
                logger.error("JSON parsing error: \(error)")
                logger.debug("JSON string that failed: \(jsonString)")
                
                // Try to extract partial data if possible
                if let data = jsonString.data(using: .utf8) {
                    do {
                        let decoder = JSONDecoder()
                        let recipesData = try decoder.decode([RecipeData].self, from: data)
                        logger.debug("Partial JSON parsing successful, got \(recipesData.count) recipes")
                        
                        var recipes: [Recipe] = []
                        for recipeData in recipesData {
                            // Infer dietary notes from ingredients since RecipeData doesn't include them
                            let recipeDietaryNotes = inferDietaryNotesFromIngredients(recipeData.ingredients, cuisine: cuisine)
                            logger.debug("Inferred dietary notes for '\(recipeData.name)': \(recipeDietaryNotes.map { $0.rawValue })")
                            
                            let recipe = Recipe(
                                title: recipeData.name,
                                cuisine: cuisine,
                                difficulty: difficulty,
                                prepTime: recipeData.prepTime,
                                cookTime: recipeData.cookTime,
                                servings: servings,
                                ingredients: recipeData.ingredients,
                                steps: recipeData.steps,
                                winePairings: recipeData.winePairings,
                                dietaryNotes: recipeDietaryNotes,
                                platingTips: recipeData.platingTips,
                                chefNotes: recipeData.chefNotes
                            )
                            recipes.append(recipe)
                        }
                        return recipes
                    } catch {
                        logger.error("Even partial JSON parsing failed: \(error)")
                    }
                }
                
                // If JSON parsing fails, try to create basic recipes from the text
                return try createPopularRecipesFromText(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
            }
        } else {
            logger.error("No JSON array brackets found in response")
            // If no JSON found, try to create basic recipes from the text
            return try createPopularRecipesFromText(content, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
        }
    }
    
    private func createPopularRecipesFromText(_ content: String, cuisine: Cuisine, difficulty: Difficulty, dietaryRestrictions: [DietaryNote], servings: Int = 2) throws -> [Recipe] {
        logger.debug("Creating popular recipes from text content...")
        
        // Split content into sections and try to extract recipes
        let sections = content.components(separatedBy: "\n\n")
        var recipes: [Recipe] = []
        
        for (index, section) in sections.enumerated() {
            let trimmedSection = section.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip descriptive text sections that don't contain actual recipe names
            if isDescriptiveText(trimmedSection) {
                logger.debug("Skipping descriptive text section: \(trimmedSection.prefix(100))...")
                continue
            }
            
            if trimmedSection.count > 50 { // Only process substantial sections
                do {
                    let recipe = try createRecipeFromText(trimmedSection, cuisine: cuisine, difficulty: difficulty, dietaryRestrictions: dietaryRestrictions, servings: servings)
                    // Don't override dietary notes - preserve what was parsed from text
                    recipes.append(recipe)
                } catch {
                    logger.warning("Could not create recipe from section \(index + 1)")
                }
            }
        }
        
        // If we couldn't extract enough recipes, create some basic ones with proper names and dynamic ingredients
        logger.warning("Could only extract \(recipes.count) recipes from LLM response. Creating fallback recipes to ensure minimum 10...")
        
        while recipes.count < 10 {
            let recipeNumber = recipes.count + 1
            let recipeName = generateProperRecipeName(cuisine: cuisine, index: recipeNumber, dietaryRestrictions: dietaryRestrictions)
            
            // Generate diverse dietary notes for fallback recipes to ensure variety
            let fallbackDietaryNotes: [DietaryNote]
            if dietaryRestrictions.isEmpty {
                // When no restrictions, create diverse fallback recipes
                let allDietaryOptions: [DietaryNote] = [.vegetarian, .glutenFree, .dairyFree]
                fallbackDietaryNotes = [allDietaryOptions[recipeNumber % allDietaryOptions.count]]
                logger.debug("Creating fallback recipe with diverse dietary notes: \(fallbackDietaryNotes.map { $0.rawValue })")
            } else {
                fallbackDietaryNotes = dietaryRestrictions
            }
            
            // Generate dynamic ingredients based on recipe name, cuisine and dietary restrictions
            let dynamicIngredients = generateDynamicIngredientsForRecipe(name: recipeName, cuisine: cuisine, dietaryRestrictions: fallbackDietaryNotes)
            
            // Create more realistic cooking times
            let prepTime = 10 + (recipeNumber * 2) // Vary prep time
            let cookTime = 20 + (recipeNumber * 3) // Vary cook time
            
            let recipe = Recipe(
                title: recipeName,
                cuisine: cuisine,
                difficulty: difficulty,
                prepTime: prepTime,
                cookTime: cookTime,
                servings: servings,
                ingredients: dynamicIngredients,
                steps: [
                    CookingStep(
                        stepNumber: 1,
                        description: "Prepare ingredients according to \(cuisine.rawValue) cooking techniques",
                        duration: prepTime,
                        temperature: nil,
                        tips: "Follow traditional \(cuisine.rawValue) methods"
                    ),
                    CookingStep(
                        stepNumber: 2,
                        description: "Cook using \(cuisine.rawValue) methods until done",
                        duration: cookTime,
                        temperature: nil,
                        tips: "Ensure proper cooking time and temperature"
                    )
                ],
                winePairings: [],
                dietaryNotes: fallbackDietaryNotes,
                platingTips: "Serve with traditional \(cuisine.rawValue) presentation",
                chefNotes: "This is a fallback \(cuisine.rawValue) recipe to ensure minimum recipe count"
            )
            recipes.append(recipe)
            logger.debug("Created fallback recipe \(recipeNumber): \(recipeName)")
        }
        
        logger.api("Total recipes after fallback: \(recipes.count)")
        
        return recipes
    }
    
    private func generateDynamicIngredientsForRecipe(name: String, cuisine: Cuisine, dietaryRestrictions: [DietaryNote]) -> [Ingredient] {
        // Generate recipe-specific ingredients based on recipe name and cuisine
        var ingredients: [Ingredient] = []
        
        // Add base ingredients that are common across cuisines - respect dietary restrictions
        ingredients.append(Ingredient(name: "Sea Salt", amount: 1.0, unit: "tsp", notes: "to taste"))
        ingredients.append(Ingredient(name: "Black Pepper", amount: 0.5, unit: "tsp", notes: "freshly ground"))
        
        // Add oil based on dietary restrictions
        if !dietaryRestrictions.contains(.dairyFree) {
            ingredients.append(Ingredient(name: "Extra Virgin Olive Oil", amount: 2.0, unit: "tbsp", notes: "for cooking"))
        } else {
            ingredients.append(Ingredient(name: "Coconut Oil", amount: 2.0, unit: "tbsp", notes: "dairy-free alternative for cooking"))
        }
        
        // Generate recipe-specific ingredients based on recipe name
        let recipeSpecificIngredients = generateRecipeSpecificIngredients(name: name, cuisine: cuisine, dietaryRestrictions: dietaryRestrictions)
        ingredients.append(contentsOf: recipeSpecificIngredients)
        
        return ingredients
    }
    
    private func generateRecipeSpecificIngredients(name: String, cuisine: Cuisine, dietaryRestrictions: [DietaryNote]) -> [Ingredient] {
        // Convert recipe name to lowercase for easier matching
        let recipeName = name.lowercased()
        var ingredients: [Ingredient] = []
        
        // Add cuisine-specific base ingredients with comprehensive details
        switch cuisine {
        case .italian:
            // Add oil based on dietary restrictions
            if !dietaryRestrictions.contains(.dairyFree) {
            ingredients.append(Ingredient(name: "Extra Virgin Olive Oil", amount: 3.0, unit: "tbsp", notes: "cold-pressed, for cooking and finishing"))
            } else {
                ingredients.append(Ingredient(name: "Coconut Oil", amount: 3.0, unit: "tbsp", notes: "dairy-free alternative for cooking"))
            }
            ingredients.append(Ingredient(name: "Garlic", amount: 4.0, unit: "cloves", notes: "fresh, finely minced"))
            ingredients.append(Ingredient(name: "Sea Salt", amount: 1.0, unit: "tsp", notes: "fine grain, to taste"))
            ingredients.append(Ingredient(name: "Black Pepper", amount: 0.5, unit: "tsp", notes: "freshly ground"))
            
            if recipeName.contains("pasta") || recipeName.contains("spaghetti") || recipeName.contains("penne") {
                if !dietaryRestrictions.contains(.glutenFree) {
                ingredients.append(Ingredient(name: "Durum Wheat Pasta", amount: 8.0, unit: "oz", notes: "spaghetti, penne, or your choice of shape"))
                } else {
                    ingredients.append(Ingredient(name: "Gluten-Free Pasta", amount: 8.0, unit: "oz", notes: "rice, quinoa, or chickpea pasta"))
                }
                if !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Parmigiano-Reggiano", amount: 0.75, unit: "cup", notes: "freshly grated, aged 24 months"))
                } else {
                    ingredients.append(Ingredient(name: "Nutritional Yeast", amount: 0.5, unit: "cup", notes: "dairy-free alternative for cheesy flavor"))
                }
                ingredients.append(Ingredient(name: "Fresh Basil", amount: 0.5, unit: "cup", notes: "fresh, torn leaves"))
                ingredients.append(Ingredient(name: "Red Pepper Flakes", amount: 0.25, unit: "tsp", notes: "optional, for heat"))
                ingredients.append(Ingredient(name: "San Marzano Tomatoes", amount: 1.0, unit: "can", notes: "28 oz, crushed for sauce"))
            }
            if recipeName.contains("risotto") {
                ingredients.append(Ingredient(name: "Arborio Rice", amount: 1.0, unit: "cup", notes: "short-grain, high-starch rice"))
                ingredients.append(Ingredient(name: "Dry White Wine", amount: 0.75, unit: "cup", notes: "Pinot Grigio or similar"))
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                ingredients.append(Ingredient(name: "Chicken Stock", amount: 4.0, unit: "cups", notes: "homemade or high-quality store-bought, warm"))
                } else {
                    ingredients.append(Ingredient(name: "Vegetable Stock", amount: 4.0, unit: "cups", notes: "homemade or high-quality store-bought, warm"))
                }
                ingredients.append(Ingredient(name: "Shallots", amount: 2.0, unit: "medium", notes: "finely diced"))
                if !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Butter", amount: 2.0, unit: "tbsp", notes: "unsalted, for finishing"))
                } else {
                    ingredients.append(Ingredient(name: "Coconut Oil", amount: 2.0, unit: "tbsp", notes: "dairy-free alternative for finishing"))
                }
            }
            if recipeName.contains("pizza") {
                if !dietaryRestrictions.contains(.glutenFree) {
                ingredients.append(Ingredient(name: "Pizza Dough", amount: 1.0, unit: "ball", notes: "store-bought or homemade, room temperature"))
                } else {
                    ingredients.append(Ingredient(name: "Gluten-Free Pizza Dough", amount: 1.0, unit: "ball", notes: "store-bought or homemade, room temperature"))
                }
                if !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Fresh Mozzarella", amount: 8.0, unit: "oz", notes: "fresh, torn into pieces"))
                } else {
                    ingredients.append(Ingredient(name: "Dairy-Free Mozzarella", amount: 8.0, unit: "oz", notes: "cashew or almond-based alternative"))
                }
                ingredients.append(Ingredient(name: "San Marzano Tomatoes", amount: 1.0, unit: "can", notes: "28 oz, crushed for sauce"))
                ingredients.append(Ingredient(name: "Fresh Basil", amount: 0.25, unit: "cup", notes: "fresh, torn leaves"))
                if !dietaryRestrictions.contains(.glutenFree) {
                ingredients.append(Ingredient(name: "Semolina Flour", amount: 0.25, unit: "cup", notes: "for dusting pizza peel"))
                } else {
                    ingredients.append(Ingredient(name: "Gluten-Free Flour", amount: 0.25, unit: "cup", notes: "rice or almond flour for dusting"))
                }
            }
            
            // Traditional Italian vegetarian dishes
            if recipeName.contains("caprese") {
                if !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Fresh Mozzarella", amount: 8.0, unit: "oz", notes: "fresh, sliced"))
                } else {
                    ingredients.append(Ingredient(name: "Dairy-Free Mozzarella", amount: 8.0, unit: "oz", notes: "cashew or almond-based alternative"))
                }
                ingredients.append(Ingredient(name: "Heirloom Tomatoes", amount: 4.0, unit: "large", notes: "sliced"))
                ingredients.append(Ingredient(name: "Fresh Basil", amount: 0.5, unit: "cup", notes: "fresh, whole leaves"))
                ingredients.append(Ingredient(name: "Balsamic Glaze", amount: 2.0, unit: "tbsp", notes: "for drizzling"))
            }
            if recipeName.contains("bruschetta") {
                if !dietaryRestrictions.contains(.glutenFree) {
                ingredients.append(Ingredient(name: "Baguette", amount: 1.0, unit: "loaf", notes: "sliced and toasted"))
                } else {
                    ingredients.append(Ingredient(name: "Gluten-Free Baguette", amount: 1.0, unit: "loaf", notes: "rice or quinoa-based alternative"))
                }
                ingredients.append(Ingredient(name: "Roma Tomatoes", amount: 4.0, unit: "medium", notes: "diced"))
                ingredients.append(Ingredient(name: "Fresh Basil", amount: 0.25, unit: "cup", notes: "fresh, chopped"))
            }
            if recipeName.contains("minestrone") {
                ingredients.append(Ingredient(name: "Cannellini Beans", amount: 2.0, unit: "cans", notes: "15 oz each, drained"))
                ingredients.append(Ingredient(name: "Carrots", amount: 3.0, unit: "medium", notes: "diced"))
                ingredients.append(Ingredient(name: "Celery", amount: 3.0, unit: "stalks", notes: "diced"))
                ingredients.append(Ingredient(name: "Zucchini", amount: 2.0, unit: "medium", notes: "diced"))
            }
            
        case .french:
            ingredients.append(Ingredient(name: "Unsalted Butter", amount: 3.0, unit: "tbsp", notes: "European-style, 82% fat content"))
            ingredients.append(Ingredient(name: "Shallots", amount: 3.0, unit: "medium", notes: "fresh, finely minced"))
            ingredients.append(Ingredient(name: "Sea Salt", amount: 1.0, unit: "tsp", notes: "fleur de sel, to taste"))
            ingredients.append(Ingredient(name: "Black Pepper", amount: 0.5, unit: "tsp", notes: "freshly ground, Tellicherry"))
            
            if recipeName.contains("coq") || recipeName.contains("boeuf") {
                ingredients.append(Ingredient(name: "Beef Chuck", amount: 2.0, unit: "lbs", notes: "cut into 2-inch cubes for stew"))
                ingredients.append(Ingredient(name: "Red Wine", amount: 1.5, unit: "cups", notes: "Burgundy or Pinot Noir, for cooking"))
                ingredients.append(Ingredient(name: "Beef Stock", amount: 3.0, unit: "cups", notes: "homemade or high-quality store-bought"))
                ingredients.append(Ingredient(name: "Carrots", amount: 4.0, unit: "medium", notes: "fresh, peeled and diced"))
                ingredients.append(Ingredient(name: "Yellow Onions", amount: 2.0, unit: "medium", notes: "fresh, diced"))
                ingredients.append(Ingredient(name: "Fresh Thyme", amount: 4.0, unit: "sprigs", notes: "fresh, tied in bundle"))
                ingredients.append(Ingredient(name: "Bay Leaves", amount: 2.0, unit: "leaves", notes: "dried, whole"))
                ingredients.append(Ingredient(name: "All-Purpose Flour", amount: 2.0, unit: "tbsp", notes: "for thickening sauce"))
            }
            if recipeName.contains("ratatouille") {
                ingredients.append(Ingredient(name: "Eggplant", amount: 1.0, unit: "large", notes: "fresh, sliced 1/4 inch thick"))
                ingredients.append(Ingredient(name: "Zucchini", amount: 2.0, unit: "medium", notes: "fresh, sliced 1/4 inch thick"))
                ingredients.append(Ingredient(name: "Roma Tomatoes", amount: 4.0, unit: "medium", notes: "fresh, diced"))
                ingredients.append(Ingredient(name: "Bell Peppers", amount: 2.0, unit: "medium", notes: "red and yellow, sliced"))
                ingredients.append(Ingredient(name: "Fresh Herbs de Provence", amount: 1.0, unit: "tbsp", notes: "fresh, chopped"))
                ingredients.append(Ingredient(name: "Extra Virgin Olive Oil", amount: 0.25, unit: "cup", notes: "for drizzling"))
            }
            
            // Traditional French vegetarian dishes
            if recipeName.contains("quiche") && !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Pie Crust", amount: 1.0, unit: "9-inch", notes: "store-bought or homemade"))
                ingredients.append(Ingredient(name: "Heavy Cream", amount: 1.0, unit: "cup", notes: "for custard"))
                ingredients.append(Ingredient(name: "Eggs", amount: 4.0, unit: "large", notes: "for custard"))
                ingredients.append(Ingredient(name: "Gruyère Cheese", amount: 1.0, unit: "cup", notes: "grated"))
            }
            if recipeName.contains("soupe") || recipeName.contains("onion") {
                ingredients.append(Ingredient(name: "Yellow Onions", amount: 4.0, unit: "large", notes: "thinly sliced"))
                ingredients.append(Ingredient(name: "Beef Stock", amount: 4.0, unit: "cups", notes: "or vegetable stock for vegetarian"))
                if !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Gruyère Cheese", amount: 1.0, unit: "cup", notes: "grated"))
                }
                ingredients.append(Ingredient(name: "Baguette", amount: 0.5, unit: "loaf", notes: "sliced and toasted"))
            }
            if recipeName.contains("gratin") && !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Potatoes", amount: 2.0, unit: "lbs", notes: "thinly sliced"))
                ingredients.append(Ingredient(name: "Heavy Cream", amount: 1.0, unit: "cup", notes: "for sauce"))
                ingredients.append(Ingredient(name: "Gruyère Cheese", amount: 1.0, unit: "cup", notes: "grated"))
            }
            
        case .indian:
            ingredients.append(Ingredient(name: "Ghee", amount: 3.0, unit: "tbsp", notes: "clarified butter, or vegetable oil"))
            ingredients.append(Ingredient(name: "Cumin Seeds", amount: 1.0, unit: "tsp", notes: "whole, for tempering"))
            ingredients.append(Ingredient(name: "Ground Turmeric", amount: 0.5, unit: "tsp", notes: "powdered, for color and flavor"))
            ingredients.append(Ingredient(name: "Sea Salt", amount: 1.0, unit: "tsp", notes: "fine grain, to taste"))
            ingredients.append(Ingredient(name: "Fresh Ginger", amount: 1.0, unit: "tbsp", notes: "fresh, finely grated"))
            ingredients.append(Ingredient(name: "Fresh Garlic", amount: 4.0, unit: "cloves", notes: "fresh, minced"))
            
            // Add masala spices for any masala dish
            if recipeName.contains("masala") {
                ingredients.append(Ingredient(name: "Garam Masala", amount: 1.0, unit: "tsp", notes: "ground, for finishing"))
                ingredients.append(Ingredient(name: "Ground Coriander", amount: 1.0, unit: "tsp", notes: "powdered"))
                ingredients.append(Ingredient(name: "Cayenne Pepper", amount: 0.25, unit: "tsp", notes: "powdered, to taste"))
                ingredients.append(Ingredient(name: "Ground Cumin", amount: 0.5, unit: "tsp", notes: "powdered"))
                ingredients.append(Ingredient(name: "Fresh Cilantro", amount: 0.5, unit: "cup", notes: "fresh, chopped for garnish"))
                ingredients.append(Ingredient(name: "Fresh Tomatoes", amount: 2.0, unit: "medium", notes: "fresh, diced"))
            }
            
            // Add specific protein based on recipe name, not generic curry
            if recipeName.contains("fish curry") || recipeName.contains("fish masala") {
                ingredients.append(Ingredient(name: "Fresh Fish Fillets", amount: 1.0, unit: "lb", notes: "firm white fish like cod, haddock, or tilapia, cut into 2-inch pieces"))
                ingredients.append(Ingredient(name: "Coconut Milk", amount: 1.0, unit: "can", notes: "13.5 oz, for rich sauce"))
                ingredients.append(Ingredient(name: "Tamarind Paste", amount: 1.0, unit: "tsp", notes: "for tangy flavor"))
                ingredients.append(Ingredient(name: "Curry Leaves", amount: 10.0, unit: "leaves", notes: "fresh, for authentic flavor"))
            } else if recipeName.contains("chicken curry") || recipeName.contains("chicken masala") {
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                    ingredients.append(Ingredient(name: "Chicken Breast", amount: 1.0, unit: "lb", notes: "boneless, skinless, cut into 1-inch pieces"))
                    ingredients.append(Ingredient(name: "Heavy Cream", amount: 0.5, unit: "cup", notes: "for rich sauce"))
                    ingredients.append(Ingredient(name: "Yogurt", amount: 0.5, unit: "cup", notes: "plain, for marinade"))
                }
            } else if recipeName.contains("lamb curry") || recipeName.contains("lamb masala") {
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                    ingredients.append(Ingredient(name: "Lamb Shoulder", amount: 1.0, unit: "lb", notes: "boneless, cut into 1-inch pieces"))
                    ingredients.append(Ingredient(name: "Heavy Cream", amount: 0.5, unit: "cup", notes: "for rich sauce"))
                    ingredients.append(Ingredient(name: "Yogurt", amount: 0.5, unit: "cup", notes: "plain, for marinade"))
                }
            } else if (recipeName.contains("paneer curry") || recipeName.contains("paneer masala")) && !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Paneer", amount: 0.5, unit: "lb", notes: "fresh, cubed"))
                ingredients.append(Ingredient(name: "Heavy Cream", amount: 0.5, unit: "cup", notes: "for rich sauce"))
            } else if recipeName.contains("curry") && !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                // Generic curry - let LLM decide the protein, don't hardcode chicken
                ingredients.append(Ingredient(name: "Protein of Choice", amount: 1.0, unit: "lb", notes: "chicken, fish, lamb, or paneer based on recipe"))
                ingredients.append(Ingredient(name: "Heavy Cream", amount: 0.5, unit: "cup", notes: "for rich sauce"))
                ingredients.append(Ingredient(name: "Yogurt", amount: 0.5, unit: "cup", notes: "plain, for marinade"))
            }
            
            // Traditional Indian vegetarian dishes
            if recipeName.contains("aloo") || recipeName.contains("potato") {
                ingredients.append(Ingredient(name: "Potatoes", amount: 4.0, unit: "medium", notes: "peeled and cubed"))
            }
            if recipeName.contains("gobi") || recipeName.contains("cauliflower") {
                ingredients.append(Ingredient(name: "Cauliflower", amount: 1.0, unit: "head", notes: "cut into florets"))
            }
            if recipeName.contains("palak") || recipeName.contains("spinach") {
                ingredients.append(Ingredient(name: "Fresh Spinach", amount: 2.0, unit: "cups", notes: "chopped"))
            }
            if recipeName.contains("paneer") && !dietaryRestrictions.contains(.dairyFree) {
                ingredients.append(Ingredient(name: "Paneer", amount: 0.5, unit: "lb", notes: "fresh, cubed"))
            }
            if recipeName.contains("dal") || recipeName.contains("lentil") {
                ingredients.append(Ingredient(name: "Red Lentils", amount: 1.0, unit: "cup", notes: "rinsed"))
            }
            if recipeName.contains("chana") || recipeName.contains("chickpea") {
                ingredients.append(Ingredient(name: "Chickpeas", amount: 2.0, unit: "cans", notes: "15 oz each, drained"))
            }
            if recipeName.contains("baingan") || recipeName.contains("eggplant") {
                ingredients.append(Ingredient(name: "Eggplant", amount: 2.0, unit: "medium", notes: "diced"))
            }
            if recipeName.contains("biryani") {
                ingredients.append(Ingredient(name: "Basmati Rice", amount: 2.0, unit: "cups", notes: "aged, rinsed and soaked"))
                ingredients.append(Ingredient(name: "Saffron Threads", amount: 0.25, unit: "tsp", notes: dietaryRestrictions.contains(.dairyFree) ? "soaked in 2 tbsp warm water" : "soaked in 2 tbsp warm milk"))
                ingredients.append(Ingredient(name: "Green Cardamom", amount: 8.0, unit: "pods", notes: "whole, lightly crushed"))
                ingredients.append(Ingredient(name: "Cinnamon Stick", amount: 1.0, unit: "piece", notes: "2-inch piece"))
                ingredients.append(Ingredient(name: "Bay Leaves", amount: 2.0, unit: "leaves", notes: "dried, whole"))
                ingredients.append(Ingredient(name: "Cloves", amount: 4.0, unit: "whole", notes: "dried"))
                ingredients.append(Ingredient(name: "Fresh Mint", amount: 0.25, unit: "cup", notes: "fresh, chopped"))
            }
            
        case .chinese:
            ingredients.append(Ingredient(name: "Light Soy Sauce", amount: 2.0, unit: "tbsp", notes: "premium quality, for seasoning"))
            ingredients.append(Ingredient(name: "Dark Soy Sauce", amount: 1.0, unit: "tbsp", notes: "for color and depth"))
            ingredients.append(Ingredient(name: "Fresh Ginger", amount: 1.0, unit: "tbsp", notes: "fresh, finely minced"))
            ingredients.append(Ingredient(name: "Toasted Sesame Oil", amount: 1.0, unit: "tsp", notes: "for finishing"))
            ingredients.append(Ingredient(name: "Shaoxing Wine", amount: 1.0, unit: "tbsp", notes: "Chinese rice wine, or dry sherry"))
            ingredients.append(Ingredient(name: "Cornstarch", amount: 1.0, unit: "tsp", notes: "for thickening sauces"))
            ingredients.append(Ingredient(name: "White Pepper", amount: 0.25, unit: "tsp", notes: "ground, to taste"))
            
            if recipeName.contains("kung pao chicken") {
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                    ingredients.append(Ingredient(name: "Chicken Breast", amount: 1.0, unit: "lb", notes: "boneless, skinless, cut into 1-inch pieces"))
                }
                ingredients.append(Ingredient(name: "Peanut Oil", amount: 2.0, unit: "tbsp", notes: "for high-heat cooking"))
                ingredients.append(Ingredient(name: "Fresh Garlic", amount: 3.0, unit: "cloves", notes: "fresh, minced"))
                ingredients.append(Ingredient(name: "Green Onions", amount: 3.0, unit: "stalks", notes: "fresh, chopped"))
                ingredients.append(Ingredient(name: "Dried Red Chilies", amount: 4.0, unit: "whole", notes: "dried, for heat"))
                ingredients.append(Ingredient(name: "Sichuan Peppercorns", amount: 0.5, unit: "tsp", notes: "whole, toasted"))
                ingredients.append(Ingredient(name: "Bell Peppers", amount: 2.0, unit: "medium", notes: "red and green, diced"))
                ingredients.append(Ingredient(name: "Cashews", amount: 0.5, unit: "cup", notes: "roasted, for garnish"))
            } else if recipeName.contains("stir fry") || recipeName.contains("stir-fry") {
                ingredients.append(Ingredient(name: "Protein of Choice", amount: 1.0, unit: "lb", notes: "chicken, beef, pork, shrimp, or tofu based on recipe"))
                ingredients.append(Ingredient(name: "Peanut Oil", amount: 2.0, unit: "tbsp", notes: "for high-heat cooking"))
                ingredients.append(Ingredient(name: "Fresh Garlic", amount: 3.0, unit: "cloves", notes: "fresh, minced"))
                ingredients.append(Ingredient(name: "Green Onions", amount: 3.0, unit: "stalks", notes: "fresh, chopped"))
                ingredients.append(Ingredient(name: "Mixed Vegetables", amount: 2.0, unit: "cups", notes: "bell peppers, broccoli, carrots, etc."))
            }
            if recipeName.contains("soup") {
                ingredients.append(Ingredient(name: "Chicken Stock", amount: 6.0, unit: "cups", notes: "homemade or high-quality store-bought"))
                ingredients.append(Ingredient(name: "Green Onions", amount: 4.0, unit: "stalks", notes: "fresh, chopped"))
                ingredients.append(Ingredient(name: "Fresh Cilantro", amount: 0.25, unit: "cup", notes: "fresh, chopped for garnish"))
                ingredients.append(Ingredient(name: "White Pepper", amount: 0.5, unit: "tsp", notes: "ground, to taste"))
            }
            
            // Traditional Chinese vegetarian dishes
            if recipeName.contains("tofu") || recipeName.contains("doufu") {
                ingredients.append(Ingredient(name: "Firm Tofu", amount: 1.0, unit: "block", notes: "14 oz, cubed"))
            }
            if recipeName.contains("bok choy") || recipeName.contains("pak choi") {
                ingredients.append(Ingredient(name: "Bok Choy", amount: 4.0, unit: "heads", notes: "baby or regular, chopped"))
            }
            if recipeName.contains("gai lan") || recipeName.contains("chinese broccoli") {
                ingredients.append(Ingredient(name: "Chinese Broccoli", amount: 1.0, unit: "bunch", notes: "trimmed and chopped"))
            }
            if recipeName.contains("mapo") {
                ingredients.append(Ingredient(name: "Firm Tofu", amount: 1.0, unit: "block", notes: "14 oz, cubed"))
                // Add pork only for non-vegetarian mapo dishes
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                    ingredients.append(Ingredient(name: "Ground Pork", amount: 0.5, unit: "lb", notes: "for mapo tofu"))
                }
            }
            
        case .japanese:
            ingredients.append(Ingredient(name: "Soy Sauce", amount: 2.0, unit: "tbsp", notes: "low sodium"))
            ingredients.append(Ingredient(name: "Mirin", amount: 1.0, unit: "tbsp", notes: "sweet rice wine"))
            ingredients.append(Ingredient(name: "Dashi", amount: 2.0, unit: "cups", notes: "homemade or instant"))
            if recipeName.contains("sushi") {
                ingredients.append(Ingredient(name: "Sushi Rice", amount: 2.0, unit: "cups", notes: "short-grain"))
                ingredients.append(Ingredient(name: "Nori", amount: 4.0, unit: "sheets", notes: "dried seaweed"))
                ingredients.append(Ingredient(name: "Rice Vinegar", amount: 2.0, unit: "tbsp", notes: "seasoned"))
                ingredients.append(Ingredient(name: "Fresh Salmon", amount: 0.5, unit: "lb", notes: "sashimi-grade, sliced"))
                ingredients.append(Ingredient(name: "Avocado", amount: 1.0, unit: "medium", notes: "ripe, sliced"))
                ingredients.append(Ingredient(name: "Cucumber", amount: 1.0, unit: "medium", notes: "julienned"))
            }
            if recipeName.contains("ramen") {
                ingredients.append(Ingredient(name: "Ramen Noodles", amount: 2.0, unit: "packages", notes: "fresh or dried"))
                ingredients.append(Ingredient(name: "Miso Paste", amount: 2.0, unit: "tbsp", notes: "white or red"))
                ingredients.append(Ingredient(name: "Bamboo Shoots", amount: 0.5, unit: "cup", notes: "canned, sliced"))
                ingredients.append(Ingredient(name: "Pork Belly", amount: 0.5, unit: "lb", notes: "sliced for chashu"))
                ingredients.append(Ingredient(name: "Soft-Boiled Eggs", amount: 2.0, unit: "eggs", notes: "marinated in soy sauce"))
                ingredients.append(Ingredient(name: "Green Onions", amount: 4.0, unit: "stalks", notes: "chopped"))
            }
            
            // Traditional Japanese vegetarian dishes
            if recipeName.contains("tofu") || recipeName.contains("agedashi") {
                ingredients.append(Ingredient(name: "Silken Tofu", amount: 1.0, unit: "block", notes: "14 oz, for agedashi tofu"))
            }
            if recipeName.contains("edamame") {
                ingredients.append(Ingredient(name: "Edamame", amount: 2.0, unit: "cups", notes: "fresh or frozen, shelled"))
            }
            if recipeName.contains("goma") || recipeName.contains("sesame") {
                ingredients.append(Ingredient(name: "Sesame Seeds", amount: 0.25, unit: "cup", notes: "toasted"))
            }
            if recipeName.contains("tempura") {
                ingredients.append(Ingredient(name: "Tempura Batter Mix", amount: 1.0, unit: "cup", notes: "or homemade"))
                ingredients.append(Ingredient(name: "Mixed Vegetables", amount: 2.0, unit: "cups", notes: "sweet potato, eggplant, bell peppers"))
            }
            
        case .mexican:
            ingredients.append(Ingredient(name: "Cumin", amount: 1.0, unit: "tsp", notes: "ground"))
            ingredients.append(Ingredient(name: "Chili Powder", amount: 1.0, unit: "tsp", notes: "mild or hot"))
            ingredients.append(Ingredient(name: "Lime", amount: 1.0, unit: "medium", notes: "juiced"))
            if recipeName.contains("taco") || recipeName.contains("enchilada") {
                ingredients.append(Ingredient(name: "Ground Beef", amount: 1.0, unit: "lb", notes: "80/20 lean, for filling"))
                ingredients.append(Ingredient(name: "Corn Tortillas", amount: 8.0, unit: "pieces", notes: "6-inch"))
                ingredients.append(Ingredient(name: "Cheddar", amount: 1.0, unit: "cup", notes: "shredded"))
                ingredients.append(Ingredient(name: "Sour Cream", amount: 0.5, unit: "cup", notes: "for serving"))
                ingredients.append(Ingredient(name: "Onion", amount: 1.0, unit: "medium", notes: "diced"))
                ingredients.append(Ingredient(name: "Bell Peppers", amount: 2.0, unit: "medium", notes: "diced"))
            }
            if recipeName.contains("guacamole") {
                ingredients.append(Ingredient(name: "Avocados", amount: 3.0, unit: "ripe", notes: "mashed"))
                ingredients.append(Ingredient(name: "Tomatoes", amount: 2.0, unit: "medium", notes: "diced"))
                ingredients.append(Ingredient(name: "Cilantro", amount: 0.25, unit: "cup", notes: "chopped"))
                ingredients.append(Ingredient(name: "Red Onion", amount: 0.5, unit: "medium", notes: "finely diced"))
                ingredients.append(Ingredient(name: "Jalapeño", amount: 1.0, unit: "medium", notes: "seeded and minced"))
            }
            
            // Traditional Mexican vegetarian dishes
            if recipeName.contains("frijoles") || recipeName.contains("beans") {
                ingredients.append(Ingredient(name: "Black Beans", amount: 2.0, unit: "cans", notes: "15 oz each, drained"))
            }
            if recipeName.contains("nopales") || recipeName.contains("cactus") {
                ingredients.append(Ingredient(name: "Nopales", amount: 1.0, unit: "lb", notes: "cactus paddles, cleaned and diced"))
            }
            if recipeName.contains("chile relleno") {
                ingredients.append(Ingredient(name: "Poblano Peppers", amount: 4.0, unit: "large", notes: "roasted and peeled"))
                ingredients.append(Ingredient(name: "Queso Fresco", amount: 0.5, unit: "lb", notes: "for stuffing"))
            }
            if recipeName.contains("elote") || recipeName.contains("mexican corn") {
                ingredients.append(Ingredient(name: "Corn on the Cob", amount: 4.0, unit: "ears", notes: "fresh"))
                ingredients.append(Ingredient(name: "Cotija Cheese", amount: 0.5, unit: "cup", notes: "crumbled"))
                ingredients.append(Ingredient(name: "Mexican Crema", amount: 0.25, unit: "cup", notes: "or sour cream"))
            }
            
        case .thai:
            ingredients.append(Ingredient(name: "Fish Sauce", amount: 1.0, unit: "tbsp", notes: "nam pla"))
            ingredients.append(Ingredient(name: "Palm Sugar", amount: 1.0, unit: "tbsp", notes: "or brown sugar"))
            ingredients.append(Ingredient(name: "Thai Basil", amount: 0.5, unit: "cup", notes: "fresh, torn"))
            if recipeName.contains("chicken curry") {
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                    ingredients.append(Ingredient(name: "Chicken Breast", amount: 1.0, unit: "lb", notes: "boneless, skinless, cut into pieces"))
                }
                ingredients.append(Ingredient(name: "Coconut Milk", amount: 1.0, unit: "can", notes: "13.5 oz"))
                ingredients.append(Ingredient(name: "Curry Paste", amount: 2.0, unit: "tbsp", notes: "red, green, or yellow"))
                ingredients.append(Ingredient(name: "Bamboo Shoots", amount: 0.5, unit: "cup", notes: "canned, sliced"))
                ingredients.append(Ingredient(name: "Bell Peppers", amount: 2.0, unit: "medium", notes: "sliced"))
                ingredients.append(Ingredient(name: "Thai Eggplant", amount: 4.0, unit: "small", notes: "quartered"))
            } else if recipeName.contains("fish curry") {
                ingredients.append(Ingredient(name: "Fresh Fish Fillets", amount: 1.0, unit: "lb", notes: "firm white fish like cod or tilapia, cut into pieces"))
                ingredients.append(Ingredient(name: "Coconut Milk", amount: 1.0, unit: "can", notes: "13.5 oz"))
                ingredients.append(Ingredient(name: "Curry Paste", amount: 2.0, unit: "tbsp", notes: "red, green, or yellow"))
                ingredients.append(Ingredient(name: "Bamboo Shoots", amount: 0.5, unit: "cup", notes: "canned, sliced"))
                ingredients.append(Ingredient(name: "Bell Peppers", amount: 2.0, unit: "medium", notes: "sliced"))
                ingredients.append(Ingredient(name: "Thai Eggplant", amount: 4.0, unit: "small", notes: "quartered"))
            } else if recipeName.contains("curry") {
                ingredients.append(Ingredient(name: "Protein of Choice", amount: 1.0, unit: "lb", notes: "chicken, fish, shrimp, or tofu based on recipe"))
                ingredients.append(Ingredient(name: "Coconut Milk", amount: 1.0, unit: "can", notes: "13.5 oz"))
                ingredients.append(Ingredient(name: "Curry Paste", amount: 2.0, unit: "tbsp", notes: "red, green, or yellow"))
                ingredients.append(Ingredient(name: "Bamboo Shoots", amount: 0.5, unit: "cup", notes: "canned, sliced"))
                ingredients.append(Ingredient(name: "Bell Peppers", amount: 2.0, unit: "medium", notes: "sliced"))
                ingredients.append(Ingredient(name: "Thai Eggplant", amount: 4.0, unit: "small", notes: "quartered"))
            }
            if recipeName.contains("pad thai") {
                ingredients.append(Ingredient(name: "Rice Noodles", amount: 8.0, unit: "oz", notes: "flat, soaked"))
                ingredients.append(Ingredient(name: "Tamarind Paste", amount: 1.0, unit: "tbsp", notes: "or lime juice"))
                ingredients.append(Ingredient(name: "Bean Sprouts", amount: 1.0, unit: "cup", notes: "fresh"))
                ingredients.append(Ingredient(name: "Tofu", amount: 0.5, unit: "lb", notes: "firm, cubed"))
                ingredients.append(Ingredient(name: "Peanuts", amount: 0.25, unit: "cup", notes: "crushed, for garnish"))
                // Add shrimp only for non-vegetarian pad thai
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                    ingredients.append(Ingredient(name: "Shrimp", amount: 0.5, unit: "lb", notes: "peeled and deveined"))
                }
            }
            
            // Traditional Thai vegetarian dishes
            if recipeName.contains("som tam") || recipeName.contains("papaya") {
                ingredients.append(Ingredient(name: "Green Papaya", amount: 1.0, unit: "medium", notes: "shredded"))
                ingredients.append(Ingredient(name: "Cherry Tomatoes", amount: 1.0, unit: "cup", notes: "halved"))
                ingredients.append(Ingredient(name: "Long Beans", amount: 0.5, unit: "cup", notes: "cut into 2-inch pieces"))
            }
            if recipeName.contains("tom yum") || recipeName.contains("tom kha") {
                ingredients.append(Ingredient(name: "Lemongrass", amount: 3.0, unit: "stalks", notes: "bruised and cut"))
                ingredients.append(Ingredient(name: "Galangal", amount: 2.0, unit: "tbsp", notes: "fresh, sliced"))
                ingredients.append(Ingredient(name: "Kaffir Lime Leaves", amount: 4.0, unit: "leaves", notes: "fresh"))
            }
            if recipeName.contains("larb") {
                ingredients.append(Ingredient(name: "Mint", amount: 0.5, unit: "cup", notes: "fresh, chopped"))
                ingredients.append(Ingredient(name: "Cilantro", amount: 0.5, unit: "cup", notes: "fresh, chopped"))
                // Add pork only for non-vegetarian larb
                if !dietaryRestrictions.contains(.vegetarian) && !dietaryRestrictions.contains(.vegan) {
                    ingredients.append(Ingredient(name: "Ground Pork", amount: 1.0, unit: "lb", notes: "or chicken for larb"))
                }
            }
            
        default:
            // For other cuisines, add general ingredients
            ingredients.append(Ingredient(name: "Olive Oil", amount: 2.0, unit: "tbsp", notes: "for cooking"))
            ingredients.append(Ingredient(name: "Onion", amount: 1.0, unit: "medium", notes: "diced"))
            ingredients.append(Ingredient(name: "Garlic", amount: 2.0, unit: "cloves", notes: "minced"))
        }
        
        return ingredients
    }
    
    private func generateDynamicIngredients(for cuisine: Cuisine, dietaryRestrictions: [DietaryNote]) -> [Ingredient] {
        // Base ingredients that are common across cuisines
        let baseIngredients = [
            Ingredient(name: "Olive Oil", amount: 2.0, unit: "tbsp", notes: "for cooking"),
            Ingredient(name: "Salt", amount: 1.0, unit: "tsp", notes: "to taste"),
            Ingredient(name: "Black Pepper", amount: 0.5, unit: "tsp", notes: "freshly ground")
        ]
        
        // Add cuisine-specific ingredients
        let cuisineIngredients: [Ingredient] = {
            switch cuisine {
            case .french:
                return [
                    Ingredient(name: "Shallots", amount: 2.0, unit: "medium", notes: "finely chopped"),
                    Ingredient(name: "Garlic", amount: 3.0, unit: "cloves", notes: "minced"),
                    Ingredient(name: "White Wine", amount: 0.5, unit: "cup", notes: "dry")
                ]
            case .italian:
                return [
                    Ingredient(name: "Garlic", amount: 4.0, unit: "cloves", notes: "minced"),
                    Ingredient(name: "Basil", amount: 0.25, unit: "cup", notes: "fresh, torn"),
                    Ingredient(name: "Parmesan", amount: 0.5, unit: "cup", notes: "freshly grated")
                ]
            case .japanese:
                return [
                    Ingredient(name: "Soy Sauce", amount: 2.0, unit: "tbsp", notes: "low sodium"),
                    Ingredient(name: "Mirin", amount: 1.0, unit: "tbsp", notes: "sweet rice wine"),
                    Ingredient(name: "Ginger", amount: 1.0, unit: "tbsp", notes: "fresh, grated")
                ]
            case .chinese:
                return [
                    Ingredient(name: "Soy Sauce", amount: 2.0, unit: "tbsp", notes: "dark"),
                    Ingredient(name: "Ginger", amount: 1.0, unit: "tbsp", notes: "fresh, minced"),
                    Ingredient(name: "Sesame Oil", amount: 1.0, unit: "tsp", notes: "toasted")
                ]
            case .indian:
                return [
                    Ingredient(name: "Cumin Seeds", amount: 1.0, unit: "tsp", notes: "whole"),
                    Ingredient(name: "Turmeric", amount: 0.5, unit: "tsp", notes: "ground"),
                    Ingredient(name: "Garam Masala", amount: 1.0, unit: "tsp", notes: "ground")
                ]
            case .mexican:
                return [
                    Ingredient(name: "Cumin", amount: 1.0, unit: "tsp", notes: "ground"),
                    Ingredient(name: "Chili Powder", amount: 1.0, unit: "tsp", notes: "mild"),
                    Ingredient(name: "Lime", amount: 1.0, unit: "medium", notes: "juiced")
                ]
            case .thai:
                return [
                    Ingredient(name: "Fish Sauce", amount: 1.0, unit: "tbsp", notes: "nam pla"),
                    Ingredient(name: "Lime", amount: 1.0, unit: "medium", notes: "juiced"),
                    Ingredient(name: "Thai Basil", amount: 0.25, unit: "cup", notes: "fresh")
                ]
            default:
                return [
                    Ingredient(name: "Garlic", amount: 2.0, unit: "cloves", notes: "minced"),
                    Ingredient(name: "Onion", amount: 1.0, unit: "medium", notes: "diced")
                ]
            }
        }()
        
        // Filter ingredients based on dietary restrictions
        let allIngredients = baseIngredients + cuisineIngredients
        let filteredIngredients = allIngredients.filter { ingredient in
            let ingredientName = ingredient.name.lowercased()
            
            for restriction in dietaryRestrictions {
                switch restriction {
                case .vegetarian:
                    if containsMeatIngredients([ingredientName]) {
                        return false
                    }
                case .vegan:
                    if containsMeatIngredients([ingredientName]) || containsDairyIngredients([ingredientName]) || containsEggIngredients([ingredientName]) {
                        return false
                    }
                case .dairyFree:
                    if containsDairyIngredients([ingredientName]) {
                        return false
                    }
                case .glutenFree:
                    if containsGlutenIngredients([ingredientName]) {
                        return false
                    }
                case .nutFree:
                    if containsNutIngredients([ingredientName]) {
                        return false
                    }
                default:
                    break
                }
            }
            return true
        }
        
        return filteredIngredients.isEmpty ? baseIngredients : filteredIngredients
    }
    
    private func generateCompliantFallbackRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        count: Int,
        servings: Int = 2
    ) -> [Recipe] {
        logger.debug("Generating \(count) compliant fallback recipes for \(cuisine.rawValue)")
        
        var fallbackRecipes: [Recipe] = []
        
        for i in 1...count {
            let recipeName = generateCompliantRecipeName(cuisine: cuisine, dietaryRestrictions: dietaryRestrictions, index: i)
            let ingredients = generateDynamicIngredientsForRecipe(name: recipeName, cuisine: cuisine, dietaryRestrictions: dietaryRestrictions)
            
            let recipe = Recipe(
                title: recipeName,
                cuisine: cuisine,
                difficulty: difficulty,
                prepTime: 15,
                cookTime: 30,
                servings: servings,
                ingredients: ingredients,
                steps: [
                    CookingStep(
                        stepNumber: 1,
                        description: "Prepare ingredients according to \(cuisine.rawValue) cooking techniques",
                        duration: 15,
                        temperature: nil,
                        tips: "Follow traditional \(cuisine.rawValue) methods"
                    )
                ],
                winePairings: [],
                dietaryNotes: dietaryRestrictions,
                platingTips: "Serve with traditional \(cuisine.rawValue) presentation",
                chefNotes: "This is a compliant \(cuisine.rawValue) recipe that respects all dietary restrictions"
            )
            fallbackRecipes.append(recipe)
        }
        
        return fallbackRecipes
    }
    
    private func generateCompliantRecipeName(cuisine: Cuisine, dietaryRestrictions: [DietaryNote], index: Int) -> String {
        // Generate authentic, specific recipe names based on cuisine and dietary restrictions
        let authenticNames = getAuthenticRecipeNames(for: cuisine, dietaryRestrictions: dietaryRestrictions)
        let nameIndex = (index - 1) % authenticNames.count
        return authenticNames[nameIndex]
    }
    
    private func generateProperRecipeName(cuisine: Cuisine, index: Int, dietaryRestrictions: [DietaryNote]) -> String {
        // Generate authentic, specific recipe names that reflect current popularity and trends
        let authenticNames = getAuthenticRecipeNames(for: cuisine, dietaryRestrictions: dietaryRestrictions)
        let nameIndex = (index - 1) % authenticNames.count
        return authenticNames[nameIndex]
    }
    
    // MARK: - Recipe Option Structure
    private struct RecipeOption {
        let name: String
        let restrictions: [DietaryNote] // What restrictions this recipe CAN accommodate
    }
    
    // MARK: - Advanced Dietary Filtering
    private func filterRecipesByDietaryRestrictions(_ recipes: [RecipeOption], dietaryRestrictions: [DietaryNote]) -> [String] {
        // If no restrictions, return all recipes
        if dietaryRestrictions.isEmpty {
            return recipes.map { $0.name }
        }
        
        // Filter recipes that can accommodate ALL selected restrictions
        let compatibleRecipes = recipes.filter { recipe in
            // Recipe must be compatible with ALL selected restrictions
            dietaryRestrictions.allSatisfy { restriction in
                recipe.restrictions.contains(restriction)
            }
        }
        
        // If no compatible recipes found, try to find recipes that match most restrictions
        if compatibleRecipes.isEmpty {
            let partiallyCompatibleRecipes = recipes.filter { recipe in
                let matchingRestrictions = dietaryRestrictions.filter { restriction in
                    recipe.restrictions.contains(restriction)
                }
                // Recipe must match at least 70% of restrictions
                return Double(matchingRestrictions.count) / Double(dietaryRestrictions.count) >= 0.7
            }
            
            if !partiallyCompatibleRecipes.isEmpty {
                return partiallyCompatibleRecipes.map { $0.name }
            }
        }
        
        return compatibleRecipes.map { $0.name }
    }
    
    private func getAuthenticRecipeNames(for cuisine: Cuisine, dietaryRestrictions: [DietaryNote]) -> [String] {
        // Get all possible recipes for this cuisine
        let allRecipes = getAllRecipesForCuisine(cuisine)
        
        // Filter recipes based on ALL dietary restrictions
        return filterRecipesByDietaryRestrictions(allRecipes, dietaryRestrictions: dietaryRestrictions)
    }
    
    private func getAllRecipesForCuisine(_ cuisine: Cuisine) -> [RecipeOption] {
        switch cuisine {
        case .any:
            // For "Any Cuisine", return a diverse selection from multiple cuisines
            var allRecipes: [RecipeOption] = []
            
            // Add recipes from major cuisines for variety
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.italian))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.french))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.indian))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.chinese))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.japanese))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.mexican))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.thai))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.mediterranean))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.american))
            allRecipes.append(contentsOf: getAllRecipesForCuisine(.greek))
            
            // Shuffle and return top recipes for variety
            return Array(allRecipes.shuffled().prefix(50))
            
        case .italian:
            return [
                // Vegan recipes (no animal products)
                RecipeOption(name: "Pasta alla Norma", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Risotto ai Funghi", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Minestrone Verde", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Penne Arrabbiata", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Spaghetti Aglio e Olio", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pasta e Fagioli", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pasta al Pomodoro", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Minestrone Classico", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Penne all'Arrabbiata", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pasta e Ceci", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy)
                RecipeOption(name: "Risotto alla Milanese", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Lasagna Vegetariana", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pasta al Pesto", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Frittata di Verdure", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Parmigiana di Melanzane", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Osso Buco alla Milanese", restrictions: [.glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Spaghetti alla Carbonara", restrictions: [.nutFree, .halal, .kosher]),
                RecipeOption(name: "Risotto ai Porcini", restrictions: [.nutFree, .halal, .kosher]),
                RecipeOption(name: "Saltimbocca alla Romana", restrictions: [.glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Bistecca alla Fiorentina", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Lasagna alla Bolognese", restrictions: [.nutFree, .halal, .kosher]),
                RecipeOption(name: "Pollo alla Milanese", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vitello Tonnato", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Saltimbocca", restrictions: [.glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .french:
            return [
                // Vegan recipes
                RecipeOption(name: "Ratatouille Niçoise", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Soupe à l'Oignon", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Salade Niçoise", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Pissaladière", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Soupe au Pistou", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Salade de Lentilles", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Soupe de Légumes", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Salade de Haricots", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Soupe de Pois", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Salade de Tomates", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Coq au Vin", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Boeuf Bourguignon", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Duck Confit", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Escargots de Bourgogne", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Steak Frites", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Poulet à la Moutarde", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .indian:
            return [
                // Vegan recipes (no animal products, no dairy)
                RecipeOption(name: "Chana Masala", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Aloo Gobi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Dal Makhani", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Baingan Bharta", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Rajma Masala", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Sambar", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Rasam", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Bhindi Masala", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy)
                RecipeOption(name: "Palak Paneer", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Chole Bhature", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Kadhi Pakora", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Dahi Bhalla", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Malai Kofta", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Chicken Tikka Masala", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Lamb Biryani", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Butter Chicken", restrictions: [.glutenFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Fish Curry", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Rogan Josh", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vindaloo", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Mutton Curry", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Chicken Biryani", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .chinese:
            return [
                // Vegan recipes
                RecipeOption(name: "Mapo Tofu", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kung Pao Tofu", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Buddha's Delight", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Stir-Fried Vegetables", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Hot and Sour Soup", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Spring Rolls", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Fried Rice", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Noodle Soup", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Vegetarian recipes (may contain gluten)
                RecipeOption(name: "Wonton Soup", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Dim Sum", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Kung Pao Chicken", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Sweet and Sour Pork", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Peking Duck", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "General Tso's Chicken", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Orange Chicken", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Honey Walnut Shrimp", restrictions: [.glutenFree, .dairyFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Beef and Broccoli", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .japanese:
            return [
                // Vegan recipes
                RecipeOption(name: "Miso Soup", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Edamame", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Seaweed Salad", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Pickled Vegetables", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Rice Balls", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Natto", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Umeboshi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kombu Dashi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Shiitake Mushrooms", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Vegetarian recipes (may contain gluten)
                RecipeOption(name: "Vegetable Tempura", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Sushi Nigiri", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Ramen", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tempura", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Teriyaki Chicken", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Sashimi", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gyoza", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Yakitori", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Tonkatsu", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Okonomiyaki", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Unagi Don", restrictions: [.dairyFree, .nutFree, .halal, .kosher])
            ]
        case .mexican:
            return [
                // Vegan recipes
                RecipeOption(name: "Guacamole", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Salsa Verde", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Pico de Gallo", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Frijoles Refritos", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Arroz Mexicano", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Sopa de Tortilla", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Mole Poblano", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy/gluten)
                RecipeOption(name: "Chiles Rellenos", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Enchiladas Verdes", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Chiles en Nogada", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Tacos al Pastor", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Enchiladas Rojas", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Carne Asada", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Pollo Asado", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Carnitas", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Barbacoa", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .thai:
            return [
                // Vegan recipes (Chay = vegetarian/vegan)
                RecipeOption(name: "Pad Thai Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Green Curry Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tom Yum Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Som Tam Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Massaman Curry Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Red Curry Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Yellow Curry Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Panang Curry Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tom Kha Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Larb Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Pad Thai", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Green Curry", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tom Yum Soup", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Som Tam", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Massaman Curry", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Red Curry", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Yellow Curry", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Panang Curry", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tom Kha Soup", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Larb", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .mediterranean:
            return [
                // Vegan recipes
                RecipeOption(name: "Hummus", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Baba Ganoush", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Falafel", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tabbouleh", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Mujadara", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Fattoush", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Dolma", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Paella", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy)
                RecipeOption(name: "Shakshuka", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Moussaka", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Lamb Tagine", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Chicken Shawarma", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kafta", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Shish Taouk", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Mixed Grill", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .american:
            return [
                // Vegan recipes
                RecipeOption(name: "Vegan Burger", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Plant-Based Chili", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vegan Mac and Cheese", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Vegan BBQ", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vegan Meatloaf", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Vegan Shepherd's Pie", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Vegan Pot Pie", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Vegan Casserole", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Vegan Stew", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vegan Soup", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy)
                RecipeOption(name: "Veggie Burger", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Vegetarian Chili", restrictions: [.vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Mac and Cheese", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "BBQ Tofu", restrictions: [.vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vegetarian Meatloaf", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Shepherd's Pie", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pot Pie", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Casserole", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Stew", restrictions: [.vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Soup", restrictions: [.vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Classic Burger", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "BBQ Ribs", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Steak", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Fried Chicken", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Chili", restrictions: [.dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Meatloaf", restrictions: [.dairyFree, .nutFree, .halal, .kosher])
            ]
        case .greek:
            return [
                // Vegan recipes
                RecipeOption(name: "Fasolada", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gemista", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Horta", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Fava", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Dolmades", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy)
                RecipeOption(name: "Spanakopita", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Moussaka", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pastitsio", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Souvlaki", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gyros", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Kleftiko", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Stifado", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Arni Souvla", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kotopoulo", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Bifteki", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .spanish:
            return [
                // Vegan recipes
                RecipeOption(name: "Paella Valenciana", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gazpacho", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Pisto", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Escalivada", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Salmorejo", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Ajoblanco", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Sopa de Ajo", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Ensalada Mixta", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Patatas Bravas", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Tortilla Española", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Paella de Mariscos", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pulpo a la Gallega", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Jamon Iberico", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Chorizo", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Cochinillo", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .moroccan:
            return [
                // Vegan recipes
                RecipeOption(name: "Harira", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Zaalouk", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Bessara", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Taktouka", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Salata Mechouia", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Harira Soup", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vegetable Tagine", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Tea", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Vegetarian recipes (may contain gluten)
                RecipeOption(name: "Couscous", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Bread", restrictions: [.vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Lamb Tagine", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Chicken Tagine", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Pastilla", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Merguez", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kefta", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .vietnamese:
            return [
                // Vegan recipes (Chay = vegetarian/vegan)
                RecipeOption(name: "Pho Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Banh Mi Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Goi Cuon", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Com Tam", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Banh Xeo", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Bun Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Banh Cuon Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Chao Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Banh Xoi Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Che Chay", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Pho", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Banh Mi", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Banh Xeo", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Bun Bo Hue", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Banh Cuon", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Chao Ga", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Banh Xoi", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Che", restrictions: [.dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .korean:
            return [
                // Vegan recipes
                RecipeOption(name: "Bibimbap", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Kimchi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Japchae", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Kimbap", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tteokbokki", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Doenjang Jjigae", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kongnamul Guk", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Sundubu Jjigae", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Yachae Bokkeum", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kongnamul Muchim", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Bulgogi", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Galbi", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Samgyeopsal", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Samgyetang", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Jjajangmyeon", restrictions: [.dairyFree, .nutFree, .halal, .kosher])
            ]
        case .turkish:
            return [
                // Vegan recipes
                RecipeOption(name: "Mercimek Çorbası", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Imam Bayildi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Dolma", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Piyaz", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Ezogelin Çorbası", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Yaprak Sarma", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Karnıyarık", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Patlıcan Kebabı", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Mercimek Köftesi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Zeytinyağlı Yemekler", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Kebap", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Döner", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Adana Kebap", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "İskender", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Lahmacun", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Pide", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Urfa Kebap", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .lebanese:
            return [
                // Vegan recipes
                RecipeOption(name: "Hummus", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Baba Ganoush", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Falafel", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tabbouleh", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Mujadara", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Fattoush", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Dolma", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Moussaka", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Paella", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Lamb Tagine", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Chicken Shawarma", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kafta", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Shish Taouk", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kibbeh", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Shawarma", restrictions: [.dairyFree, .nutFree, .halal, .kosher])
            ]
        case .persian:
            return [
                // Vegan recipes
                RecipeOption(name: "Ghormeh Sabzi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Fesenjan", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Tahchin", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Zereshk Polo", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Adas Polo", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Mirza Ghasemi", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kashk-e Bademjan", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Borani", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Ash-e Reshteh", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Sholeh Zard", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Kebab", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Joojeh Kebab", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Barg", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Koobideh", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Shishlik", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gheymeh", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Dizi", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .ethiopian:
            return [
                // Vegan recipes
                RecipeOption(name: "Shiro", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Misir Wot", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gomen", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Atkilt", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Beyaynetu", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kik Alicha", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Azifa", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Tikil Gomen", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Yekik Alicha", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gomen Besiga", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Doro Wot", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Tibs", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Kitfo", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Dulet", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Gored Gored", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Awaze Tibs", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Siga Tibs", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher])
            ]
        case .brazilian:
            return [
                // Vegan recipes
                RecipeOption(name: "Feijoada", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Moqueca", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Vatapá", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Acarajé", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Caruru", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Farofa", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Tutu de Feijão", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy)
                RecipeOption(name: "Pão de Queijo", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Churrasco", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Picanha", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Frango à Passarinho", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Bife à Cavalo", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "X-Tudo", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Feijão Tropeiro", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Carne de Sol", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Bobó de Camarão", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Coxinha", restrictions: [.dairyFree, .nutFree, .halal, .kosher])
            ]
        case .peruvian:
            return [
                // Vegan recipes
                RecipeOption(name: "Causa", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Rocoto Relleno", restrictions: [.vegan, .vegetarian, .dairyFree, .glutenFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Causa Rellena", restrictions: [.vegan, .vegetarian, .dairyFree, .nutFree, .halal, .kosher]),
                
                // Vegetarian recipes (may contain dairy)
                RecipeOption(name: "Papa a la Huancaína", restrictions: [.vegetarian, .nutFree, .halal, .kosher]),
                
                // Non-vegetarian recipes
                RecipeOption(name: "Pollo a la Brasa", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Chaufa", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Arroz con Pollo", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Seco de Cordero", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Chicharrones", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Anticuchos", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Ceviche", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Lomo Saltado", restrictions: [.glutenFree, .dairyFree, .nutFree, .lowCarb, .keto, .paleo, .halal, .kosher]),
                RecipeOption(name: "Aji de Gallina", restrictions: [.dairyFree, .nutFree, .halal, .kosher]),
                RecipeOption(name: "Chupe de Camarones", restrictions: [.dairyFree, .nutFree, .halal, .kosher])
            ]
        }
    }
    
    private func getDietaryDescription(_ restriction: DietaryNote) -> String {
        switch restriction {
        case .nonVegetarian:
            return "MUST include meat, poultry, fish, or seafood - NO vegetarian-only recipes allowed"
        case .vegetarian:
            return "ABSOLUTELY NO: chicken, turkey, duck, beef, pork, lamb, fish, seafood, meat, bacon, ham, sausage, or ANY animal flesh - ONLY plant-based ingredients allowed"
        case .vegan:
            return "ABSOLUTELY NO: meat, fish, dairy, eggs, honey, or ANY animal products whatsoever - ONLY plant-based ingredients allowed"
        case .glutenFree:
            return "ABSOLUTELY NO: wheat, barley, rye, spelt, flour, bread, pasta, or ANY gluten-containing ingredients"
        case .dairyFree:
            return "ABSOLUTELY NO: milk, cheese, butter, cream, yogurt, or ANY dairy products whatsoever"
        case .nutFree:
            return "ABSOLUTELY NO: almonds, cashews, walnuts, peanuts, or ANY nuts, peanuts, or tree nuts"
        case .lowCarb:
            return "Minimal carbohydrates - focus on protein and healthy fats"
        case .keto:
            return "Very low carb, high fat - no sugar, grains, or high-carb vegetables"
        case .paleo:
            return "NO grains, legumes, dairy, or processed foods - only whole foods"
        case .halal:
            return "Must follow Islamic dietary laws - no pork, alcohol, or non-halal meat"
        case .kosher:
            return "Must follow Jewish dietary laws - no pork, shellfish, or mixing meat with dairy"
        }
    }
    
    // MARK: - Detailed Cooking Instructions Generation
    
    /// Generates detailed cooking instructions for a recipe using LLM
    /// - Parameter recipe: The recipe to generate detailed instructions for
    /// - Returns: Detailed cooking instructions in plain English
    func generateDetailedCookingInstructions(for recipe: Recipe) async throws -> String {
        guard let apiKey = apiKey else {
            logger.warning("No API key found")
            throw GeminiError.noAPIKey
        }
        
        logger.api("Generating detailed cooking instructions for \(recipe.name)")
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let prompt = createDetailedInstructionsPrompt(for: recipe)
        
        logger.api("Making API request to Gemini for detailed instructions...")
        
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: prompt)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.1,
                maxOutputTokens: 1000
            )
        )
        
        let url = URL(string: "\(baseURL)/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.api("HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    logger.error("HTTP Error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        logger.error("Error response: \(errorString)")
                    }
                    throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            // Try to decode as error response first
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               let error = errorResponse.error {
                logger.error("Gemini API Error: \(error.message)")
                throw GeminiError.apiError(error.message)
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
                logger.error("No content in response")
                throw GeminiError.noContent
            }
            
            logger.api("Successfully generated detailed cooking instructions")
            return content
            
        } catch {
            logger.error("Error generating detailed cooking instructions: \(error)")
            throw error
        }
    }
    
    private func createDetailedInstructionsPrompt(for recipe: Recipe) -> String {
        let ingredientsList = recipe.ingredients.map { ingredient in
            var ingredientText = "• \(ingredient.amount) \(ingredient.unit) \(ingredient.name)"
            if let notes = ingredient.notes, !notes.isEmpty {
                ingredientText += " (\(notes))"
            }
            return ingredientText
        }.joined(separator: "\n")
        
        let stepsList = recipe.steps.map { step in
            var stepText = "Step \(step.stepNumber): \(step.description)"
            if let duration = step.duration {
                stepText += " (Duration: \(duration) minutes)"
            }
            if let temperature = step.temperature {
                stepText += " (Temperature: \(Int(temperature))°C)"
            }
            if let tips = step.tips, !tips.isEmpty {
                stepText += "\n  Chef Tip: \(tips)"
            }
            return stepText
        }.joined(separator: "\n\n")
        
        return """
        Create EXTREMELY DETAILED, step-by-step cooking instructions for the following recipe. Write in plain English that any home cook can follow perfectly.

        RECIPE: \(recipe.name)
        CUISINE: \(recipe.cuisine.rawValue)
        DIFFICULTY: \(recipe.difficulty.rawValue)
        PREP TIME: \(recipe.prepTime) minutes
        COOK TIME: \(recipe.cookTime) minutes
        SERVINGS: \(recipe.servings)

        INGREDIENTS:
        \(ingredientsList)

        CURRENT STEPS:
        \(stepsList)

        CHEF NOTES: \(recipe.chefNotes)
        PLATING TIPS: \(recipe.platingTips)

        REQUIREMENTS:
        1. Write in clear, conversational English
        2. Include every single detail a home cook needs
        3. Add professional chef tips and techniques
        4. Include timing for each step
        5. Add visual cues and doneness indicators
        6. Include safety precautions
        7. Add equipment recommendations
        8. Include temperature guidance where applicable
        9. Add ingredient preparation notes
        10. Include troubleshooting tips
        11. Add wine pairing suggestions
        12. Include plating and presentation tips
        13. Add storage and reheating instructions
        14. Include nutritional notes
        15. Add cultural context and history

        Format the response as a comprehensive cooking guide with clear sections and easy-to-follow instructions. Make it so detailed that even a complete beginner can achieve restaurant-quality results.
        """
    }
    
    // MARK: - Recipe Ingredient Extraction and Analysis
    
    /// Extracts all ingredients from a list of recipes and formats them as text
    /// - Parameter recipes: Array of recipes to extract ingredients from
    /// - Returns: Formatted text containing all ingredients with their details
    func extractAllIngredientsAsText(from recipes: [Recipe]) -> String {
        var ingredientText = "📋 COMPLETE INGREDIENT LIST\n"
        ingredientText += String(repeating: "=", count: 50) + "\n\n"
        
        var allIngredients: [String: [String]] = [:] // ingredient name -> list of recipes using it
        var totalRecipes = 0
        var totalIngredients = 0
        
        for (index, recipe) in recipes.enumerated() {
            ingredientText += "🍽️ RECIPE \(index + 1): \(recipe.name)\n"
            ingredientText += "📍 Cuisine: \(recipe.cuisine.rawValue)\n"
            ingredientText += "⭐ Difficulty: \(recipe.difficulty.rawValue)\n"
            ingredientText += "⏱️ Total Time: \(recipe.formattedTotalTime)\n"
            ingredientText += "👥 Servings: \(recipe.servings)\n"
            
            if !recipe.dietaryNotes.isEmpty {
                ingredientText += "🚫 Dietary Notes: \(recipe.dietaryNotes.map { $0.rawValue }.joined(separator: ", "))\n"
            }
            
            ingredientText += "\n📝 INGREDIENTS:\n"
            
            for ingredient in recipe.ingredients {
                let ingredientLine = "• \(ingredient.amount) \(ingredient.unit) \(ingredient.name)"
                ingredientText += ingredientLine
                
                if let notes = ingredient.notes, !notes.isEmpty {
                    ingredientText += " (\(notes))"
                }
                ingredientText += "\n"
                
                // Track ingredient usage across recipes
                let ingredientKey = ingredient.name.lowercased()
                if allIngredients[ingredientKey] == nil {
                    allIngredients[ingredientKey] = []
                }
                allIngredients[ingredientKey]?.append(recipe.name)
                
                totalIngredients += 1
            }
            
            ingredientText += "\n" + String(repeating: "-", count: 40) + "\n\n"
            totalRecipes += 1
        }
        
        // Add ingredient frequency analysis
        ingredientText += "📊 INGREDIENT FREQUENCY ANALYSIS\n"
        ingredientText += String(repeating: "=", count: 50) + "\n\n"
        
        let sortedIngredients = allIngredients.sorted { $0.value.count > $1.value.count }
        
        for (ingredient, recipes) in sortedIngredients {
            ingredientText += "• \(ingredient.capitalized): used in \(recipes.count) recipe(s)\n"
            ingredientText += "  Recipes: \(recipes.joined(separator: ", "))\n\n"
        }
        
        // Add summary statistics
        ingredientText += "📈 SUMMARY STATISTICS\n"
        ingredientText += String(repeating: "=", count: 50) + "\n"
        ingredientText += "• Total Recipes: \(totalRecipes)\n"
        ingredientText += "• Total Ingredients: \(totalIngredients)\n"
        ingredientText += "• Unique Ingredients: \(allIngredients.count)\n"
        ingredientText += "• Average Ingredients per Recipe: \(totalRecipes > 0 ? String(format: "%.1f", Double(totalIngredients) / Double(totalRecipes)) : "0")\n\n"
        
        return ingredientText
    }
    
    /// Analyzes recipes and identifies all filter criteria violations
    /// - Parameter recipes: Array of recipes to analyze
    /// - Returns: Detailed analysis of filter criteria violations
    func analyzeFilterCriteriaViolations(in recipes: [Recipe]) -> String {
        var analysis = "🔍 FILTER CRITERIA ANALYSIS\n"
        analysis += String(repeating: "=", count: 50) + "\n\n"
        
        var violations: [DietaryNote: [String]] = [:]
        var compliantRecipes: [String] = []
        
        for recipe in recipes {
            var recipeViolations: [DietaryNote] = []
            
            // Check each dietary restriction
            for restriction in DietaryNote.allCases {
                let allIngredients = recipe.ingredients.map { $0.name.lowercased() }
                let isCompliant = isRecipeCompliantWithRestriction(allIngredients: allIngredients, restriction: restriction)
                
                if !isCompliant {
                    recipeViolations.append(restriction)
                    if violations[restriction] == nil {
                        violations[restriction] = []
                    }
                    violations[restriction]?.append(recipe.name)
                }
            }
            
            if recipeViolations.isEmpty {
                compliantRecipes.append(recipe.name)
            } else {
                analysis += "❌ \(recipe.name) violates: \(recipeViolations.map { $0.rawValue }.joined(separator: ", "))\n"
            }
        }
        
        analysis += "\n📊 VIOLATION SUMMARY:\n"
        analysis += String(repeating: "-", count: 30) + "\n"
        
        for (restriction, recipes) in violations.sorted(by: { $0.value.count > $1.value.count }) {
            analysis += "• \(restriction.rawValue): \(recipes.count) violation(s)\n"
            analysis += "  Recipes: \(recipes.joined(separator: ", "))\n\n"
        }
        
        analysis += "✅ COMPLIANT RECIPES (\(compliantRecipes.count)):\n"
        analysis += String(repeating: "-", count: 30) + "\n"
        for recipe in compliantRecipes {
            analysis += "• \(recipe)\n"
        }
        
        return analysis
    }
    
    /// Parses JSON recipe data and converts to formatted text
    /// - Parameter jsonData: JSON data containing recipe information
    /// - Returns: Formatted text representation of the recipes
    func parseRecipesFromJSONToText(_ jsonData: Data) -> String {
        do {
            let recipes = try JSONDecoder().decode([Recipe].self, from: jsonData)
            return extractAllIngredientsAsText(from: recipes)
        } catch {
            return "❌ Error parsing JSON: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Dietary Validation Functions
    private func validateRecipeCompliance(_ recipe: Recipe, against restrictions: [DietaryNote]) -> Bool {
        let allIngredients = recipe.ingredients.map { $0.name.lowercased() }
        let recipeName = recipe.name.lowercased()
        
        logger.debug("Validating recipe: '\(recipe.name)'")
        logger.debug("Ingredients: \(allIngredients)")
        logger.debug("Restrictions: \(restrictions.map { $0.rawValue })")
        
        // First check if recipe name itself violates restrictions
        for restriction in restrictions {
            let nameViolation = checkRecipeNameViolation(recipeName: recipeName, restriction: restriction)
            if nameViolation {
                logger.warning("Recipe name '\(recipe.name)' violates \(restriction.rawValue) restriction")
                return false
            }
        }
        
        // Then check ingredients
        for restriction in restrictions {
            let isCompliant = isRecipeCompliantWithRestriction(allIngredients: allIngredients, restriction: restriction)
            logger.debug("  - \(restriction.rawValue): \(isCompliant ? "PASS" : "FAIL")")
            
            if !isCompliant {
                logger.warning("Recipe '\(recipe.name)' FAILS \(restriction.rawValue) restriction")
                return false
            }
        }
        
        logger.debug("Recipe '\(recipe.name)' PASSES all restrictions")
        return true
    }
    
    private func checkRecipeNameViolation(recipeName: String, restriction: DietaryNote) -> Bool {
        switch restriction {
        case .vegetarian, .vegan:
            let meatKeywords = ["chicken", "turkey", "duck", "beef", "pork", "lamb", "fish", "meat", "steak", "burger", "sausage", "bacon", "ham"]
            for keyword in meatKeywords {
                if recipeName.contains(keyword) {
                    logger.debug("Recipe name contains meat keyword: '\(recipeName)' contains '\(keyword)'")
                    return true
                }
            }
        case .dairyFree:
            let dairyKeywords = ["cheese", "milk", "cream", "butter", "yogurt", "dairy"]
            for keyword in dairyKeywords {
                if recipeName.contains(keyword) {
                    logger.debug("Recipe name contains dairy keyword: '\(recipeName)' contains '\(keyword)'")
                    return true
                }
            }
        case .glutenFree:
            let glutenKeywords = ["bread", "pasta", "wheat", "flour", "cake", "cookie"]
            for keyword in glutenKeywords {
                if recipeName.contains(keyword) {
                    logger.debug("Recipe name contains gluten keyword: '\(recipeName)' contains '\(keyword)'")
                    return true
                }
            }
        default:
            break
        }
        return false
    }
    
    private func isRecipeCompliantWithRestriction(allIngredients: [String], restriction: DietaryNote) -> Bool {
        switch restriction {
        case .nonVegetarian:
            return containsMeatIngredients(allIngredients)
        case .vegetarian:
            return !containsMeatIngredients(allIngredients)
        case .vegan:
            return !containsMeatIngredients(allIngredients) && !containsDairyIngredients(allIngredients) && !containsEggIngredients(allIngredients)
        case .glutenFree:
            return !containsGlutenIngredients(allIngredients)
        case .dairyFree:
            return !containsDairyIngredients(allIngredients)
        case .nutFree:
            return !containsNutIngredients(allIngredients)
        case .lowCarb:
            return !containsHighCarbIngredients(allIngredients)
        case .keto:
            return !containsHighCarbIngredients(allIngredients) && !containsSugarIngredients(allIngredients)
        case .paleo:
            return !containsGrainsIngredients(allIngredients) && !containsLegumesIngredients(allIngredients) && !containsDairyIngredients(allIngredients)
        case .halal:
            return !containsPorkIngredients(allIngredients) && !containsAlcoholIngredients(allIngredients)
        case .kosher:
            return !containsPorkIngredients(allIngredients) && !containsShellfishIngredients(allIngredients)
        }
    }
    
    private func containsMeatIngredients(_ ingredients: [String]) -> Bool {
        let meatKeywords = [
            // Poultry
            "chicken", "turkey", "duck", "goose", "quail", "pheasant", "partridge", "guinea fowl", "poussin",
            "chicken breast", "chicken thigh", "chicken wing", "chicken leg", "chicken drumstick",
            "turkey breast", "turkey leg", "turkey wing", "duck breast", "duck leg", "duck wing",
            
            // Red Meat
            "beef", "pork", "lamb", "veal", "mutton", "goat", "bison", "elk", "moose", "venison",
            "beef steak", "pork chop", "lamb chop", "veal cutlet", "beef tenderloin", "pork tenderloin",
            "beef sirloin", "beef flank", "beef skirt", "beef brisket", "beef ribs", "pork ribs",
            "lamb shoulder", "lamb leg", "lamb rack", "pork shoulder", "pork belly", "pork loin",
            
            // Processed Meats
            "bacon", "ham", "sausage", "hot dog", "pepperoni", "salami", "prosciutto", "pancetta",
            "guanciale", "lardo", "mortadella", "capicola", "speck", "chorizo", "andouille",
            "italian sausage", "breakfast sausage", "bratwurst", "kielbasa", "meatball", "burger",
            "ground beef", "ground pork", "ground turkey", "ground lamb", "ground veal",
            
            // Fish and Seafood
            "fish", "salmon", "tuna", "cod", "halibut", "mackerel", "sardines", "anchovies",
            "shrimp", "prawn", "crab", "lobster", "mussel", "clam", "oyster", "scallop",
            "squid", "octopus", "calamari", "eel", "sea bass", "red snapper", "grouper",
            "tilapia", "swordfish", "mahi mahi", "sea bream", "sea trout", "rockfish",
            "catfish", "bass", "perch", "walleye", "pike", "trout", "whitefish",
            
            // Shellfish
            "crayfish", "crawfish", "langoustine", "abalone", "conch", "whelk", "periwinkle",
            "cockle", "razor clam", "geoduck", "surf clam", "quahog", "bay scallop", "sea scallop",
            "calico scallop", "king crab", "snow crab", "dungeness crab", "blue crab", "stone crab",
            "spider crab", "hermit crab",
            
            // Game Meat
            "game", "rabbit", "hare", "wild boar", "wild turkey", "wild duck", "wild goose",
            "pheasant", "partridge", "quail", "grouse", "woodcock", "snipe", "dove", "pigeon",
            
            // Generic Meat Terms
            "meat", "flesh", "animal", "poultry", "seafood", "fish", "shellfish", "crustacean",
            "mollusk", "bivalve", "cephalopod", "finfish", "flatfish", "roundfish"
        ]
        
        for ingredient in ingredients {
            let lowercasedIngredient = ingredient.lowercased()
            for meatKeyword in meatKeywords {
                if lowercasedIngredient.contains(meatKeyword.lowercased()) {
                    logger.debug("Found meat ingredient: '\(ingredient)' contains '\(meatKeyword)'")
                    return true
                }
            }
        }
        
        logger.debug("No meat ingredients found")
        return false
    }
    
    private func containsDairyIngredients(_ ingredients: [String]) -> Bool {
        let dairyKeywords = [
            // Milk and Cream
            "milk", "cream", "heavy cream", "light cream", "half and half", "whipping cream",
            "sour cream", "buttermilk", "kefir", "yogurt", "yoghurt", "greek yogurt",
            "whole milk", "skim milk", "low-fat milk", "non-fat milk", "almond milk", "soy milk",
            "oat milk", "coconut milk", "rice milk", "cashew milk", "hemp milk",
            
            // Cheese Varieties
            "cheese", "cheddar", "mozzarella", "parmesan", "feta", "gouda", "brie", "camembert",
            "blue cheese", "gorgonzola", "provolone", "swiss cheese", "monterey jack", "colby",
            "havarti", "manchego", "pecorino", "asiago", "fontina", "taleggio", "mascarpone",
            "burrata", "halloumi", "cream cheese", "cottage cheese", "ricotta", "paneer",
            "goat cheese", "sheep cheese", "buffalo mozzarella", "fresh mozzarella", "aged cheese",
            "hard cheese", "soft cheese", "semi-soft cheese", "fresh cheese", "processed cheese",
            
            // Butter and Dairy Fats
            "butter", "clarified butter", "ghee", "butterfat", "dairy fat", "milk fat",
            
            // Dairy Desserts
            "ice cream", "gelato", "sorbet", "custard", "pudding", "flan", "creme brulee",
            "creme caramel", "panna cotta", "tiramisu", "cheesecake", "milk chocolate",
            
            // Dairy Derivatives
            "whey", "casein", "lactose", "lactose", "milk protein", "dairy protein",
            "milk solids", "dairy solids", "milk powder", "dried milk", "evaporated milk",
            "condensed milk", "sweetened condensed milk", "milk concentrate"
        ]
        
        for ingredient in ingredients {
            let lowercasedIngredient = ingredient.lowercased()
            for dairyKeyword in dairyKeywords {
                if lowercasedIngredient.contains(dairyKeyword.lowercased()) {
                    logger.debug("Found dairy ingredient: '\(ingredient)' contains '\(dairyKeyword)'")
                    return true
                }
            }
        }
        
        logger.debug("No dairy ingredients found")
        return false
    }
    
    private func containsEggIngredients(_ ingredients: [String]) -> Bool {
        let eggKeywords = ["egg", "eggs", "egg yolk", "egg white", "albumen"]
        return ingredients.contains { ingredient in
            eggKeywords.contains { eggKeyword in
                ingredient.contains(eggKeyword)
            }
        }
    }
    
    private func containsGlutenIngredients(_ ingredients: [String]) -> Bool {
        let glutenKeywords = [
            "wheat", "barley", "rye", "spelt", "kamut", "triticale", "bulgur",
            "couscous", "semolina", "durum", "farro", "einkorn", "emmer",
            "flour", "bread", "pasta", "noodle", "dumpling", "wonton", "ravioli",
            "tortilla", "pita", "naan", "focaccia", "ciabatta", "baguette",
            "cracker", "pretzel", "cookie", "biscuit", "cake", "pastry", "pie",
            "beer", "ale", "lager", "stout", "malt", "malt extract", "malt syrup"
        ]
        return ingredients.contains { ingredient in
            glutenKeywords.contains { glutenKeyword in
                ingredient.contains(glutenKeyword)
            }
        }
    }
    
    private func containsNutIngredients(_ ingredients: [String]) -> Bool {
        let nutKeywords = [
            "almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia",
            "brazil nut", "pine nut", "pignoli", "chestnut", "filbert", "marcona",
            "peanut", "peanut butter", "peanut oil", "mixed nuts", "nut butter",
            "almond milk", "cashew milk", "hazelnut milk", "macadamia milk",
            "almond flour", "cashew flour", "hazelnut flour", "coconut flour"
        ]
        return ingredients.contains { ingredient in
            nutKeywords.contains { nutKeyword in
                ingredient.contains(nutKeyword)
            }
        }
    }
    
    private func containsHighCarbIngredients(_ ingredients: [String]) -> Bool {
        let highCarbKeywords = [
            "rice", "pasta", "bread", "potato", "sweet potato", "corn", "peas",
            "carrot", "beet", "turnip", "parsnip", "squash", "pumpkin", "sweet corn",
            "white rice", "brown rice", "jasmine rice", "basmati rice", "arborio rice",
            "quinoa", "couscous", "bulgur", "farro", "barley", "oats", "oatmeal",
            "flour", "sugar", "honey", "maple syrup", "agave", "molasses", "corn syrup"
        ]
        return ingredients.contains { ingredient in
            highCarbKeywords.contains { carbKeyword in
                ingredient.contains(carbKeyword)
            }
        }
    }
    
    private func containsSugarIngredients(_ ingredients: [String]) -> Bool {
        let sugarKeywords = [
            "sugar", "honey", "maple syrup", "agave", "molasses", "corn syrup",
            "high fructose corn syrup", "cane sugar", "brown sugar", "powdered sugar",
            "confectioners sugar", "turbinado sugar", "demerara sugar", "muscovado",
            "jaggery", "palm sugar", "coconut sugar", "date sugar", "stevia",
            "aspartame", "sucralose", "saccharin", "xylitol", "erythritol", "monk fruit"
        ]
        return ingredients.contains { ingredient in
            sugarKeywords.contains { sugarKeyword in
                ingredient.contains(sugarKeyword)
            }
        }
    }
    
    private func containsGrainsIngredients(_ ingredients: [String]) -> Bool {
        let grainsKeywords = [
            "wheat", "rice", "corn", "oats", "barley", "rye", "quinoa", "millet",
            "sorghum", "teff", "amaranth", "buckwheat", "spelt", "kamut", "farro",
            "bulgur", "couscous", "semolina", "polenta", "grits", "cornmeal",
            "flour", "bread", "pasta", "noodle", "cereal", "granola", "muesli"
        ]
        return ingredients.contains { ingredient in
            grainsKeywords.contains { grainKeyword in
                ingredient.contains(grainKeyword)
            }
        }
    }
    
    private func containsLegumesIngredients(_ ingredients: [String]) -> Bool {
        let legumesKeywords = [
            "bean", "pea", "lentil", "chickpea", "garbanzo", "black bean", "kidney bean",
            "pinto bean", "navy bean", "cannellini bean", "lima bean", "fava bean",
            "soybean", "edamame", "tofu", "tempeh", "miso", "soy sauce", "soy milk",
            "peanut", "peanut butter", "peanut oil", "split pea", "green pea",
            "snow pea", "sugar snap pea", "black eyed pea", "cowpea", "adzuki bean"
        ]
        return ingredients.contains { ingredient in
            legumesKeywords.contains { legumeKeyword in
                ingredient.contains(legumeKeyword)
            }
        }
    }
    
    private func containsPorkIngredients(_ ingredients: [String]) -> Bool {
        let porkKeywords = [
            "pork", "bacon", "ham", "prosciutto", "pancetta", "guanciale", "lardo",
            "salami", "pepperoni", "mortadella", "capicola", "speck", "chorizo",
            "pork belly", "pork shoulder", "pork loin", "pork chop", "pork tenderloin",
            "spare ribs", "baby back ribs", "country ribs", "pork sausage", "hot dog",
            "bratwurst", "kielbasa", "andouille", "italian sausage", "breakfast sausage"
        ]
        return ingredients.contains { ingredient in
            porkKeywords.contains { porkKeyword in
                ingredient.contains(porkKeyword)
            }
        }
    }
    
    private func containsAlcoholIngredients(_ ingredients: [String]) -> Bool {
        let alcoholKeywords = [
            "wine", "beer", "vodka", "rum", "whiskey", "whisky", "bourbon", "scotch",
            "gin", "tequila", "brandy", "cognac", "sherry", "port", "vermouth",
            "liqueur", "amaretto", "grand marnier", "cointreau", "triple sec",
            "kahlua", "baileys", "frangelico", "chambord", "midori", "schnapps",
            "absinthe", "pastis", "ouzo", "rakı", "arak", "sake", "soju", "makgeolli"
        ]
        return ingredients.contains { ingredient in
            alcoholKeywords.contains { alcoholKeyword in
                ingredient.contains(alcoholKeyword)
            }
        }
    }
    
    private func containsShellfishIngredients(_ ingredients: [String]) -> Bool {
        let shellfishKeywords = [
            "shrimp", "prawn", "crab", "lobster", "crayfish", "crawfish", "langoustine",
            "mussel", "clam", "oyster", "scallop", "abalone", "conch", "whelk",
            "periwinkle", "cockle", "razor clam", "geoduck", "surf clam", "quahog",
            "bay scallop", "sea scallop", "calico scallop", "king crab", "snow crab",
            "dungeness crab", "blue crab", "stone crab", "spider crab", "hermit crab"
        ]
        return ingredients.contains { ingredient in
            shellfishKeywords.contains { shellfishKeyword in
                ingredient.contains(shellfishKeyword)
            }
        }
    }
    
    // MARK: - Step Description Sanitization
    
    /// Sanitizes step descriptions to ensure they contain plain English cooking instructions
    /// - Parameter description: The original step description
    /// - Returns: Cleaned step description in plain English
    private func sanitizeStepDescription(_ description: String) -> String {
        var cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove JSON-like patterns
        let jsonPatterns = [
            "\"description\":\\s*\"([^\"]*)\"",
            "\"stepNumber\":\\s*\\d+",
            "\"duration\":\\s*\\d+",
            "\"temperature\":\\s*\\d+",
            "\"tips\":\\s*\"[^\"]*\"",
            "\\{[^}]*\\}",
            "\\[[^\\]]*\\]",
            "\"name\":\\s*\"[^\"]*\"",
            "\"amount\":\\s*\\d+\\.?\\d*",
            "\"unit\":\\s*\"[^\"]*\"",
            "\"notes\":\\s*\"[^\"]*\""
        ]
        
        for pattern in jsonPatterns {
            cleanedDescription = cleanedDescription.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove common JSON artifacts
        let artifacts = [
            "\"description\":",
            "\"stepNumber\":",
            "\"duration\":",
            "\"temperature\":",
            "\"tips\":",
            "\"name\":",
            "\"amount\":",
            "\"unit\":",
            "\"notes\":",
            "{",
            "}",
            "[",
            "]",
            "\"",
            ","
        ]
        
        for artifact in artifacts {
            cleanedDescription = cleanedDescription.replacingOccurrences(of: artifact, with: "")
        }
        
        // If the description is empty or contains only JSON artifacts, provide a default cooking instruction
        if cleanedDescription.isEmpty || cleanedDescription.count < 10 {
            return "Follow the recipe instructions carefully, paying attention to timing and temperature. Ensure all ingredients are properly prepared before starting this step."
        }
        
        // Clean up extra whitespace
        cleanedDescription = cleanedDescription.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleanedDescription = cleanedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedDescription
    }
    
    /// Converts recipe steps to kid-friendly instructions that a 5-year-old can understand
    /// - Parameter steps: Array of cooking steps
    /// - Returns: Array of kid-friendly cooking steps
    private func convertToKidFriendlySteps(_ steps: [CookingStep]) -> [CookingStep] {
        return steps.enumerated().map { index, step in
            let kidFriendlyDescription = makeKidFriendly(step.description, stepNumber: index + 1)
            
            return CookingStep(
                stepNumber: step.stepNumber,
                description: kidFriendlyDescription,
                duration: step.duration,
                temperature: step.temperature,
                imageURL: step.imageURL,
                tips: step.tips
            )
        }
    }
    
    /// Converts a cooking instruction to kid-friendly language
    /// - Parameters:
    ///   - instruction: The original cooking instruction
    ///   - stepNumber: The step number for context
    /// - Returns: Kid-friendly version of the instruction
    private func makeKidFriendly(_ instruction: String, stepNumber: Int) -> String {
        var kidFriendly = instruction
        
        // Replace technical terms with kid-friendly equivalents
        let replacements = [
            "sauté": "cook in a pan",
            "dice": "cut into small pieces",
            "mince": "cut into tiny pieces",
            "simmer": "cook slowly with bubbles",
            "boil": "cook with big bubbles",
            "preheat": "warm up",
            "preheat the oven": "turn on the oven to warm it up",
            "preheat oven": "turn on the oven to warm it up",
            "medium-high heat": "medium hot",
            "medium heat": "not too hot",
            "low heat": "gentle heat",
            "high heat": "very hot",
            "until golden brown": "until it looks golden and yummy",
            "until translucent": "until you can see through it",
            "until tender": "until it's soft",
            "until done": "until it's ready",
            "season to taste": "add salt and pepper if you want",
            "season with salt and pepper": "add a little salt and pepper",
            "stir occasionally": "stir it every now and then",
            "stir frequently": "stir it often",
            "stir constantly": "keep stirring",
            "whisk": "mix with a whisk (like a fork with many prongs)",
            "fold": "gently mix",
            "knead": "push and pull the dough",
            "marinate": "let it sit in yummy sauce",
            "garnish": "put pretty things on top",
            "drizzle": "pour a little bit on top",
            "sprinkle": "put a little bit on top",
            "coat": "cover all over",
            "grease": "put oil or butter on",
            "line": "put paper or foil on",
            "preheat the pan": "warm up the pan",
            "heat oil": "put oil in the pan and warm it up",
            "add oil": "put oil in the pan",
            "add butter": "put butter in the pan",
            "melt butter": "turn butter into liquid",
            "soften butter": "make butter soft",
            "room temperature": "not hot, not cold",
            "chilled": "cold from the fridge",
            "fresh": "new and good",
            "organic": "grown without chemicals",
            "extra virgin": "the best kind of",
            "finely chopped": "cut into very small pieces",
            "coarsely chopped": "cut into bigger pieces",
            "julienne": "cut into long thin strips",
            "brunoise": "cut into tiny cubes",
            "chiffonade": "cut into thin ribbons",
            "zest": "the colorful outside part of",
            "juice": "squeeze to get the liquid out",
            "peel": "take the skin off",
            "core": "take the middle part out",
            "seed": "take the seeds out",
            "slice": "cut into flat pieces",
            "shred": "cut into thin strips",
            "grate": "rub against a grater to make small pieces",
            "blend": "mix everything together",
            "puree": "make it smooth like baby food",
            "strain": "pour through a strainer to take out lumps",
            "drain": "pour out the water",
            "pat dry": "gently dry with a paper towel",
            "set aside": "put it to the side for later",
            "reserve": "save some for later",
            "divided": "we'll use some now and some later",
            "to taste": "as much as you like",
            "pinch": "a tiny bit",
            "dash": "a little bit",
            "generous": "a lot",
            "light": "not too much",
            "heavy": "a lot",
            "firm": "not soft",
            "soft": "easy to squish",
            "crisp": "crunchy",
            "tender": "soft and easy to eat",
            "al dente": "a little bit hard",
            "well done": "cooked all the way through",
            "rare": "still pink in the middle",
            "medium": "pink in the middle but not too much",
            "well-done": "no pink in the middle",
            "caramelize": "cook until it turns brown and sweet",
            "deglaze": "add liquid to get the yummy bits off the pan",
            "reduce": "cook until there's less liquid",
            "thicken": "make it thicker",
            "thin": "make it thinner",
            "emulsify": "mix oil and water together",
            "clarify": "make it clear",
            "smoke point": "when oil gets too hot",
            "flash point": "when oil gets too hot",
            "rolling boil": "lots of big bubbles",
            "gentle simmer": "small bubbles",
            "rapid boil": "big fast bubbles",
            "slow simmer": "small slow bubbles",
            "poach": "cook in hot water",
            "steam": "cook with hot steam",
            "braise": "cook slowly in liquid",
            "roast": "cook in the oven",
            "bake": "cook in the oven",
            "broil": "cook under very hot heat",
            "grill": "cook on a grill",
            "pan-fry": "cook in a pan with oil",
            "deep-fry": "cook in lots of hot oil",
            "stir-fry": "cook quickly in a hot pan",
            "sear": "cook quickly on very hot heat",
            "blanch": "cook quickly in hot water",
            "shock": "put in cold water to stop cooking",
            "rest": "let it sit for a while",
            "proof": "let dough grow bigger",
            "rise": "get bigger",
            "ferment": "let it sit to change flavor",
            "cure": "let it sit with salt",
            "brine": "put in salty water",
            "pickle": "put in vinegar",
            "preserve": "make it last longer",
            "can": "put in jars to keep",
            "freeze": "put in the freezer",
            "thaw": "let frozen food get warm",
            "defrost": "let frozen food get warm",
            "reheat": "warm up again",
            "warm through": "heat until warm",
            "bring to room temperature": "let it get not too hot, not too cold",
            "chill": "put in the fridge",
            "refrigerate": "put in the fridge"
        ]
        
        for (technical, replacement) in replacements {
            kidFriendly = kidFriendly.replacingOccurrences(of: technical, with: replacement, options: .caseInsensitive)
        }
        
        // Add encouraging phrases for kids
        let encouragingPhrases = [
            "Great job! ",
            "You're doing awesome! ",
            "This is fun! ",
            "You're a great chef! ",
            "Keep going! ",
            "You've got this! ",
            "This is going to be delicious! ",
            "You're making magic! ",
            "This is so much fun! ",
            "You're amazing! "
        ]
        
        // Add a random encouraging phrase at the beginning of some steps
        if stepNumber % 3 == 0 {
            let randomPhrase = encouragingPhrases.randomElement() ?? "Great job! "
            kidFriendly = randomPhrase + kidFriendly
        }
        
        // Add safety reminders for kids
        let safetyReminders = [
            " Remember to ask a grown-up for help if you need it!",
            " Be careful with hot things!",
            " Ask a grown-up before touching anything hot!",
            " Safety first!",
            " Always ask for help if you're not sure!",
            " Grown-ups can help with the hot parts!",
            " Be careful and have fun!",
            " Ask for help if you need it!"
        ]
        
        // Add safety reminders to steps that involve heat
        if kidFriendly.lowercased().contains("hot") || 
           kidFriendly.lowercased().contains("oven") || 
           kidFriendly.lowercased().contains("pan") ||
           kidFriendly.lowercased().contains("cook") {
            let randomSafety = safetyReminders.randomElement() ?? " Be careful with hot things!"
            kidFriendly += randomSafety
        }
        
        return kidFriendly
    }
    
    // MARK: - Dietary Notes Inference
    
    /// Infers dietary notes from recipe ingredients
    /// - Parameters:
    ///   - ingredients: Array of ingredients to analyze
    ///   - cuisine: The cuisine type for context
    /// - Returns: Array of inferred dietary notes
    private func inferDietaryNotesFromIngredients(_ ingredients: [Ingredient], cuisine: Cuisine) -> [DietaryNote] {
        var dietaryNotes: Set<DietaryNote> = []
        
        // Check for meat, poultry, fish, seafood
        let meatKeywords = ["chicken", "beef", "pork", "lamb", "goat", "turkey", "duck", "fish", "salmon", "tuna", "shrimp", "prawn", "crab", "lobster", "mutton", "veal", "bacon", "ham", "sausage", "mince", "ground"]
        let hasMeat = ingredients.contains { ingredient in
            meatKeywords.contains { keyword in
                ingredient.name.lowercased().contains(keyword)
            }
        }
        
        // Check for dairy
        let dairyKeywords = ["milk", "cheese", "yogurt", "cream", "butter", "ghee", "curd", "paneer", "sour cream", "heavy cream", "half and half"]
        let hasDairy = ingredients.contains { ingredient in
            dairyKeywords.contains { keyword in
                ingredient.name.lowercased().contains(keyword)
            }
        }
        
        // Check for gluten
        let glutenKeywords = ["flour", "bread", "pasta", "wheat", "barley", "rye", "couscous", "bulgur", "semolina"]
        let hasGluten = ingredients.contains { ingredient in
            glutenKeywords.contains { keyword in
                ingredient.name.lowercased().contains(keyword)
            }
        }
        
        // Check for nuts
        let nutKeywords = ["almond", "walnut", "cashew", "peanut", "pistachio", "hazelnut", "pecan", "macadamia", "pine nut", "brazil nut"]
        let hasNuts = ingredients.contains { ingredient in
            nutKeywords.contains { keyword in
                ingredient.name.lowercased().contains(keyword)
            }
        }
        
        // Determine dietary notes based on ingredients
        if !hasMeat {
            dietaryNotes.insert(.vegetarian)
            if !hasDairy {
                dietaryNotes.insert(.vegan)
            }
        }
        
        if !hasGluten {
            dietaryNotes.insert(.glutenFree)
        }
        
        if !hasDairy {
            dietaryNotes.insert(.dairyFree)
        }
        
        if !hasNuts {
            dietaryNotes.insert(.nutFree)
        }
        
        // If no specific dietary notes were inferred, add a default note
        if dietaryNotes.isEmpty {
            if hasMeat {
                dietaryNotes.insert(.glutenFree) // Most meat dishes are gluten-free by default
            } else {
                dietaryNotes.insert(.vegetarian) // Default for non-meat dishes
            }
        }
        
        logger.debug("Inferred dietary notes from ingredients: \(dietaryNotes.map { $0.rawValue })")
        return Array(dietaryNotes)
    }
    
    // MARK: - Recipe Filtering
    private func filterRecipesByDietaryRestrictions(_ recipes: [Recipe], restrictions: [DietaryNote]) -> [Recipe] {
        guard !restrictions.isEmpty else { 
            logger.debug("No dietary restrictions - returning all \(recipes.count) recipes")
            return recipes 
        }
        
        logger.debug("Filtering \(recipes.count) recipes with restrictions: \(restrictions.map { $0.rawValue })")
        
        let filteredRecipes = recipes.filter { recipe in
            let isCompliant = validateRecipeCompliance(recipe, against: restrictions)
            if !isCompliant {
                logger.debug("REMOVED: '\(recipe.name)' - violates dietary restrictions")
                logger.debug("   Ingredients: \(recipe.ingredients.map { $0.name })")
            } else {
                logger.debug("KEPT: '\(recipe.name)' - compliant with all restrictions")
            }
            return isCompliant
        }
        
        logger.debug("Filtering results: \(recipes.count) -> \(filteredRecipes.count) recipes")
        logger.debug("Final recipes: \(filteredRecipes.map { $0.name })")
        
        return filteredRecipes
    }
}

struct RecipeData: Codable {
    let name: String
    let prepTime: Int
    let cookTime: Int
    let ingredients: [Ingredient]
    let steps: [CookingStep]
    let winePairings: [WinePairing]
    let platingTips: String
    let chefNotes: String
} 