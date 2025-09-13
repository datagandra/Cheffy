import Foundation
import CloudKit
import os.log

// MARK: - Recipe Data Manager
// Unified interface for both local JSON and CloudKit data sources

@MainActor
class RecipeDataManager: ObservableObject {
    static let shared = RecipeDataManager()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "RecipeDataManager")
    private let cloudKitService = CloudKitRecipeService.shared
    private let localDatabaseService = RecipeDatabaseService.shared
    
    @Published var dataSource: DataSource = .local
    @Published var isLoading = false
    @Published var lastError: Error?
    
    enum DataSource {
        case local
        case cloudKit
    }
    
    private init() {
        // Check if CloudKit is available and user is signed in
        checkCloudKitAvailability()
    }
    
    // MARK: - Public API
    
    /// Fetches recipes with filtering (works with both local and CloudKit)
    func fetchRecipes(
        cuisine: Cuisine? = nil,
        mealType: MealType? = nil,
        dietaryRestrictions: [DietaryNote] = [],
        maxCookingTime: Int? = nil,
        servings: Int? = nil,
        difficulty: Difficulty? = nil,
        limit: Int = 50
    ) async throws -> [Recipe] {
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let recipes: [Recipe]
            
            switch dataSource {
            case .local:
                recipes = try await fetchFromLocal(
                    cuisine: cuisine,
                    mealType: mealType,
                    dietaryRestrictions: dietaryRestrictions,
                    maxCookingTime: maxCookingTime,
                    servings: servings,
                    difficulty: difficulty,
                    limit: limit
                )
                
            case .cloudKit:
                recipes = try await fetchFromCloudKit(
                    cuisine: cuisine,
                    mealType: mealType,
                    dietaryRestrictions: dietaryRestrictions,
                    maxCookingTime: maxCookingTime,
                    servings: servings,
                    difficulty: difficulty,
                    limit: limit
                )
            }
            
            lastError = nil
            logger.info("✅ Fetched \(recipes.count) recipes from \(dataSource)")
            return recipes
            
        } catch {
            lastError = error
            logger.error("❌ Failed to fetch recipes: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Searches recipes by text query
    func searchRecipes(query: String, limit: Int = 20) async throws -> [Recipe] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let recipes: [Recipe]
            
            switch dataSource {
            case .local:
                recipes = try await searchLocalRecipes(query: query, limit: limit)
            case .cloudKit:
                recipes = try await searchCloudKitRecipes(query: query, limit: limit)
            }
            
            lastError = nil
            logger.info("✅ Found \(recipes.count) recipes matching '\(query)'")
            return recipes
            
        } catch {
            lastError = error
            logger.error("❌ Search failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Switches between local and CloudKit data sources
    func switchDataSource(to newDataSource: DataSource) async {
        logger.info("🔄 Switching data source from \(dataSource) to \(newDataSource)")
        dataSource = newDataSource
        
        // Clear any cached data when switching
        if newDataSource == .cloudKit {
            cloudKitService.clearCache()
        }
    }
    
    /// Migrates local recipes to CloudKit
    func migrateToCloudKit() async throws {
        logger.info("🚀 Starting migration to CloudKit")
        
        do {
            try await cloudKitService.migrateFromJSONFiles()
            logger.info("✅ Migration completed successfully")
        } catch {
            logger.error("❌ Migration failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchFromLocal(
        cuisine: Cuisine?,
        mealType: MealType?,
        dietaryRestrictions: [DietaryNote],
        maxCookingTime: Int?,
        servings: Int?,
        difficulty: Difficulty?,
        limit: Int
    ) async throws -> [Recipe] {
        
        // Use existing local database service
        let allRecipes = localDatabaseService.getAllRecipes()
        
        // Apply filters
        var filteredRecipes = allRecipes
        
        if let cuisine = cuisine {
            filteredRecipes = filteredRecipes.filter { $0.cuisine == cuisine }
        }
        
        if let mealType = mealType {
            filteredRecipes = filteredRecipes.filter { $0.mealType == mealType }
        }
        
        if !dietaryRestrictions.isEmpty {
            filteredRecipes = filteredRecipes.filter { recipe in
                dietaryRestrictions.allSatisfy { restriction in
                    recipe.dietaryNotes.contains(restriction)
                }
            }
        }
        
        if let maxCookingTime = maxCookingTime {
            filteredRecipes = filteredRecipes.filter { recipe in
                (recipe.prepTime + recipe.cookTime) <= maxCookingTime
            }
        }
        
        if let servings = servings {
            filteredRecipes = filteredRecipes.filter { $0.servings >= servings }
        }
        
        if let difficulty = difficulty {
            filteredRecipes = filteredRecipes.filter { $0.difficulty == difficulty }
        }
        
        return Array(filteredRecipes.prefix(limit))
    }
    
    private func fetchFromCloudKit(
        cuisine: Cuisine?,
        mealType: MealType?,
        dietaryRestrictions: [DietaryNote],
        maxCookingTime: Int?,
        servings: Int?,
        difficulty: Difficulty?,
        limit: Int
    ) async throws -> [Recipe] {
        
        // Convert enums to strings for CloudKit query
        let cuisineString = cuisine?.rawValue
        let mealTypeString = mealType?.rawValue
        let dietaryTags = dietaryRestrictions.map { $0.rawValue }
        let difficultyString = difficulty?.rawValue
        
        // Fetch from CloudKit
        let cloudKitRecipes = try await cloudKitService.fetchRecipes(
            cuisine: cuisineString,
            mealType: mealTypeString,
            dietaryTags: dietaryTags,
            maxCookingTime: maxCookingTime,
            minServings: servings,
            difficulty: difficultyString,
            limit: limit
        )
        
        // Convert CloudKitRecipe to Recipe
        return cloudKitRecipes.compactMap { convertToRecipe($0) }
    }
    
    private func searchLocalRecipes(query: String, limit: Int) async throws -> [Recipe] {
        let allRecipes = localDatabaseService.getAllRecipes()
        
        let searchResults = allRecipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(query) ||
            recipe.ingredients.contains { ingredient in
                ingredient.name.localizedCaseInsensitiveContains(query)
            }
        }
        
        return Array(searchResults.prefix(limit))
    }
    
    private func searchCloudKitRecipes(query: String, limit: Int) async throws -> [Recipe] {
        let cloudKitRecipes = try await cloudKitService.searchRecipes(query: query, limit: limit)
        return cloudKitRecipes.compactMap { convertToRecipe($0) }
    }
    
    private func convertToRecipe(_ cloudKitRecipe: CloudKitRecipe) -> Recipe? {
        // Convert CloudKitRecipe to the existing Recipe model
        // This is a simplified conversion - you may need to adjust based on your Recipe model
        
        let cuisine = Cuisine(rawValue: cloudKitRecipe.cuisine) ?? .any
        let mealType = MealType(rawValue: cloudKitRecipe.mealType) ?? .regular
        let difficulty = Difficulty(rawValue: cloudKitRecipe.difficulty.lowercased()) ?? .medium
        
        // Convert dietary tags to dietary notes
        let dietaryNotes = cloudKitRecipe.dietaryTags.compactMap { tag in
            DietaryNote(rawValue: tag)
        }
        
        // Convert ingredients
        let ingredients = cloudKitRecipe.ingredients.map { ingredientString in
            // Parse ingredient string to extract name, amount, unit
            // This is a simplified parser - you may need a more sophisticated one
            Ingredient(
                name: ingredientString,
                amount: 1.0,
                unit: "piece"
            )
        }
        
        // Convert steps
        let steps = cloudKitRecipe.steps.enumerated().map { index, stepDescription in
            CookingStep(
                stepNumber: index + 1,
                description: stepDescription
            )
        }
        
        return Recipe(
            title: cloudKitRecipe.name,
            cuisine: cuisine,
            difficulty: difficulty,
            prepTime: max(1, cloudKitRecipe.cookingTimeMinutes / 4),
            cookTime: max(1, cloudKitRecipe.cookingTimeMinutes * 3 / 4),
            servings: cloudKitRecipe.servings,
            ingredients: ingredients,
            steps: steps,
            winePairings: [],
            dietaryNotes: dietaryNotes,
            platingTips: cloudKitRecipe.chefTips ?? "",
            chefNotes: cloudKitRecipe.chefTips ?? "",
            imageURL: nil,
            stepImages: [],
            createdAt: cloudKitRecipe.createdAt,
            isFavorite: false,
            mealType: mealType,
            lunchboxPresentation: cloudKitRecipe.lunchboxPresentation
        )
    }
    
    private func checkCloudKitAvailability() {
        // Check if CloudKit is available and user is signed in
        // This is a simplified check - you may need more sophisticated logic
        
        Task {
            do {
                // Try to fetch a small number of recipes to test CloudKit availability
                _ = try await cloudKitService.fetchRecipes(limit: 1)
                logger.info("✅ CloudKit is available")
            } catch {
                logger.info("⚠️ CloudKit not available, using local data: \(error.localizedDescription)")
                dataSource = .local
            }
        }
    }
}

// MARK: - Migration Status
extension RecipeDataManager {
    enum MigrationStatus {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
    }
    
    @Published var migrationStatus: MigrationStatus = .notStarted
    
    func startMigration() async {
        migrationStatus = .inProgress
        
        do {
            try await migrateToCloudKit()
            migrationStatus = .completed
        } catch {
            migrationStatus = .failed(error)
        }
    }
}
