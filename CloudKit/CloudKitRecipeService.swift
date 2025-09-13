import Foundation
import CloudKit
import os.log

// MARK: - CloudKit Recipe Service
// Handles all CloudKit operations for recipes with efficient querying and caching

@MainActor
class CloudKitRecipeService: ObservableObject {
    static let shared = CloudKitRecipeService()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "CloudKitRecipeService")
    private let container: CKContainer
    private let database: CKDatabase
    
    // Cache for frequently accessed recipes
    private var recipeCache: [String: CloudKitRecipe] = [:]
    private var lastCacheUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    @Published var isLoading = false
    @Published var lastError: Error?
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.cheffy.app")
        self.database = container.privateCloudDatabase
    }
    
    // MARK: - Public API
    
    /// Fetches recipes with advanced filtering
    func fetchRecipes(
        cuisine: String? = nil,
        mealType: String? = nil,
        dietaryTags: [String] = [],
        maxCookingTime: Int? = nil,
        minServings: Int? = nil,
        difficulty: String? = nil,
        limit: Int = 50
    ) async throws -> [CloudKitRecipe] {
        
        logger.info("🔍 Fetching recipes with filters: cuisine=\(cuisine ?? "any"), mealType=\(mealType ?? "any")")
        
        // Check cache first
        if let cachedRecipes = getCachedRecipes(
            cuisine: cuisine,
            mealType: mealType,
            dietaryTags: dietaryTags,
            maxCookingTime: maxCookingTime,
            minServings: minServings,
            difficulty: difficulty
        ) {
            logger.info("📦 Returning \(cachedRecipes.count) cached recipes")
            return cachedRecipes
        }
        
        // Build CloudKit query
        let query = buildQuery(
            cuisine: cuisine,
            mealType: mealType,
            dietaryTags: dietaryTags,
            maxCookingTime: maxCookingTime,
            minServings: minServings,
            difficulty: difficulty,
            limit: limit
        )
        
        // Execute query
        let records = try await executeQuery(query)
        
        // Convert to CloudKitRecipe objects
        let recipes = records.compactMap { CloudKitRecipe.fromCKRecord($0) }
        
        // Update cache
        updateCache(with: recipes)
        
        logger.info("✅ Fetched \(recipes.count) recipes from CloudKit")
        return recipes
    }
    
    /// Fetches a specific recipe by ID
    func fetchRecipe(id: String) async throws -> CloudKitRecipe? {
        logger.info("🔍 Fetching recipe with ID: \(id)")
        
        // Check cache first
        if let cachedRecipe = recipeCache[id] {
            logger.info("📦 Returning cached recipe")
            return cachedRecipe
        }
        
        let recordID = CKRecord.ID(recordName: id)
        let record = try await database.record(for: recordID)
        
        guard let recipe = CloudKitRecipe.fromCKRecord(record) else {
            logger.error("❌ Failed to convert record to CloudKitRecipe")
            return nil
        }
        
        // Update cache
        recipeCache[id] = recipe
        
        logger.info("✅ Fetched recipe from CloudKit")
        return recipe
    }
    
    /// Searches recipes by text query
    func searchRecipes(query: String, limit: Int = 20) async throws -> [CloudKitRecipe] {
        logger.info("🔍 Searching recipes with query: \(query)")
        
        // CloudKit doesn't support full-text search directly, so we'll use a workaround
        // by querying all recipes and filtering client-side (not ideal for large datasets)
        let allRecipes = try await fetchRecipes(limit: 1000)
        
        let searchResults = allRecipes.filter { recipe in
            recipe.name.localizedCaseInsensitiveContains(query) ||
            recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(query) } ||
            recipe.steps.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        
        logger.info("✅ Found \(searchResults.count) recipes matching query")
        return Array(searchResults.prefix(limit))
    }
    
    /// Uploads a new recipe to CloudKit
    func uploadRecipe(_ recipe: CloudKitRecipe) async throws {
        logger.info("📤 Uploading recipe: \(recipe.name)")
        
        let record = recipe.toCKRecord()
        let savedRecord = try await database.save(record)
        
        // Update cache
        if let updatedRecipe = CloudKitRecipe.fromCKRecord(savedRecord) {
            recipeCache[updatedRecipe.id] = updatedRecipe
        }
        
        logger.info("✅ Recipe uploaded successfully")
    }
    
    /// Updates an existing recipe
    func updateRecipe(_ recipe: CloudKitRecipe) async throws {
        logger.info("📝 Updating recipe: \(recipe.name)")
        
        let record = recipe.toCKRecord()
        record["updatedAt"] = Date()
        
        let savedRecord = try await database.save(record)
        
        // Update cache
        if let updatedRecipe = CloudKitRecipe.fromCKRecord(savedRecord) {
            recipeCache[updatedRecipe.id] = updatedRecipe
        }
        
        logger.info("✅ Recipe updated successfully")
    }
    
    /// Deletes a recipe
    func deleteRecipe(id: String) async throws {
        logger.info("🗑️ Deleting recipe with ID: \(id)")
        
        let recordID = CKRecord.ID(recordName: id)
        try await database.deleteRecord(withID: recordID)
        
        // Remove from cache
        recipeCache.removeValue(forKey: id)
        
        logger.info("✅ Recipe deleted successfully")
    }
    
    // MARK: - Private Methods
    
    private func buildQuery(
        cuisine: String?,
        mealType: String?,
        dietaryTags: [String],
        maxCookingTime: Int?,
        minServings: Int?,
        difficulty: String?,
        limit: Int
    ) -> CKQuery {
        
        var predicates: [NSPredicate] = []
        
        // Cuisine filter
        if let cuisine = cuisine {
            predicates.append(NSPredicate(format: "cuisine == %@", cuisine))
        }
        
        // Meal type filter
        if let mealType = mealType {
            predicates.append(NSPredicate(format: "mealType == %@", mealType))
        }
        
        // Dietary tags filter (contains any of the specified tags)
        if !dietaryTags.isEmpty {
            let dietaryPredicate = NSPredicate(format: "ANY dietaryTags IN %@", dietaryTags)
            predicates.append(dietaryPredicate)
        }
        
        // Cooking time filter
        if let maxCookingTime = maxCookingTime {
            predicates.append(NSPredicate(format: "cookingTimeMinutes <= %d", maxCookingTime))
        }
        
        // Servings filter
        if let minServings = minServings {
            predicates.append(NSPredicate(format: "servings >= %d", minServings))
        }
        
        // Difficulty filter
        if let difficulty = difficulty {
            predicates.append(NSPredicate(format: "difficulty == %@", difficulty))
        }
        
        // Combine all predicates
        let compoundPredicate = predicates.isEmpty ? NSPredicate(value: true) : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        let query = CKQuery(recordType: "Recipe", predicate: compoundPredicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        return query
    }
    
    private func executeQuery(_ query: CKQuery) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        
        repeat {
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            operation.resultsLimit = 100 // CloudKit limit
            
            let (records, newCursor) = try await database.records(matching: operation)
            allRecords.append(contentsOf: records)
            cursor = newCursor
            
        } while cursor != nil
        
        return allRecords
    }
    
    private func getCachedRecipes(
        cuisine: String?,
        mealType: String?,
        dietaryTags: [String],
        maxCookingTime: Int?,
        minServings: Int?,
        difficulty: String?
    ) -> [CloudKitRecipe]? {
        
        // Check if cache is still valid
        guard let lastUpdate = lastCacheUpdate,
              Date().timeIntervalSince(lastUpdate) < cacheValidityDuration else {
            return nil
        }
        
        // Filter cached recipes based on criteria
        let filteredRecipes = recipeCache.values.filter { recipe in
            // Cuisine filter
            if let cuisine = cuisine, recipe.cuisine != cuisine {
                return false
            }
            
            // Meal type filter
            if let mealType = mealType, recipe.mealType != mealType {
                return false
            }
            
            // Dietary tags filter
            if !dietaryTags.isEmpty {
                let hasMatchingTag = dietaryTags.contains { tag in
                    recipe.dietaryTags.contains { $0.localizedCaseInsensitiveContains(tag) }
                }
                if !hasMatchingTag {
                    return false
                }
            }
            
            // Cooking time filter
            if let maxCookingTime = maxCookingTime, recipe.cookingTimeMinutes > maxCookingTime {
                return false
            }
            
            // Servings filter
            if let minServings = minServings, recipe.servings < minServings {
                return false
            }
            
            // Difficulty filter
            if let difficulty = difficulty, recipe.difficulty != difficulty {
                return false
            }
            
            return true
        }
        
        return Array(filteredRecipes)
    }
    
    private func updateCache(with recipes: [CloudKitRecipe]) {
        for recipe in recipes {
            recipeCache[recipe.id] = recipe
        }
        lastCacheUpdate = Date()
    }
    
    /// Clears the cache
    func clearCache() {
        recipeCache.removeAll()
        lastCacheUpdate = nil
        logger.info("🗑️ Recipe cache cleared")
    }
}

// MARK: - Migration Helper
extension CloudKitRecipeService {
    /// Migrates recipes from local JSON files to CloudKit
    func migrateFromJSONFiles() async throws {
        logger.info("🚀 Starting migration from JSON files to CloudKit")
        
        // This would integrate with the Node.js migration script
        // or implement the migration logic directly in Swift
        
        // For now, we'll just log the migration start
        logger.info("📋 Migration process initiated - use migrate-recipes.js for full migration")
    }
}

// MARK: - Error Handling
extension CloudKitRecipeService {
    enum CloudKitError: LocalizedError {
        case recordNotFound
        case invalidRecord
        case networkError
        case quotaExceeded
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .recordNotFound:
                return "Recipe not found"
            case .invalidRecord:
                return "Invalid recipe data"
            case .networkError:
                return "Network connection error"
            case .quotaExceeded:
                return "CloudKit quota exceeded"
            case .unknown(let error):
                return "Unknown error: \(error.localizedDescription)"
            }
        }
    }
}
