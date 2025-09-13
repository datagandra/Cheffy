import Foundation
import CloudKit
import os.log

// MARK: - CloudKit Migration Manager
// Swift-based migration tool to upload all recipes to CloudKit

@MainActor
class CloudKitMigrationManager: ObservableObject {
    static let shared = CloudKitMigrationManager()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "CloudKitMigration")
    private let container: CKContainer
    private let database: CKDatabase
    
    @Published var migrationStatus: MigrationStatus = .notStarted
    @Published var progress: Double = 0.0
    @Published var currentOperation: String = ""
    @Published var totalRecipes: Int = 0
    @Published var processedRecipes: Int = 0
    @Published var successfulUploads: Int = 0
    @Published var failedUploads: Int = 0
    
    enum MigrationStatus {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
    }
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.cheffy.app")
        self.database = container.privateCloudDatabase
    }
    
    // MARK: - Migration Methods
    
    func startMigration() async {
        logger.info("🚀 Starting CloudKit migration")
        migrationStatus = .inProgress
        progress = 0.0
        processedRecipes = 0
        successfulUploads = 0
        failedUploads = 0
        
        do {
            // Load all recipes from JSON files
            let allRecipes = try await loadAllRecipesFromJSON()
            totalRecipes = allRecipes.count
            logger.info("📊 Loaded \(totalRecipes) recipes from JSON files")
            
            // Upload recipes in batches
            try await uploadRecipesInBatches(allRecipes)
            
            migrationStatus = .completed
            progress = 1.0
            logger.info("✅ Migration completed successfully")
            
        } catch {
            migrationStatus = .failed(error)
            logger.error("❌ Migration failed: \(error.localizedDescription)")
        }
    }
    
    private func loadAllRecipesFromJSON() async throws -> [CloudKitRecipe] {
        currentOperation = "Loading recipes from JSON files..."
        
        let recipeFiles = [
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
        
        var allRecipes: [CloudKitRecipe] = []
        
        for fileName in recipeFiles {
            currentOperation = "Loading \(fileName)..."
            let recipes = try await loadRecipesFromFile(fileName)
            allRecipes.append(contentsOf: recipes)
            logger.info("📁 Loaded \(recipes.count) recipes from \(fileName)")
        }
        
        return allRecipes
    }
    
    private func loadRecipesFromFile(_ fileName: String) async throws -> [CloudKitRecipe] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw MigrationError.fileNotFound(fileName)
        }
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        guard let cuisines = json["cuisines"] as? [String: [[String: Any]]] else {
            throw MigrationError.invalidJSONStructure(fileName)
        }
        
        var recipes: [CloudKitRecipe] = []
        
        for (cuisineName, cuisineRecipes) in cuisines {
            for recipeData in cuisineRecipes {
                do {
                    let recipe = try convertToCloudKitRecipe(recipeData, cuisine: cuisineName)
                    recipes.append(recipe)
                } catch {
                    logger.warning("⚠️ Failed to convert recipe in \(fileName): \(error)")
                    failedUploads += 1
                }
            }
        }
        
        return recipes
    }
    
    private func convertToCloudKitRecipe(_ recipeData: [String: Any], cuisine: String) throws -> CloudKitRecipe {
        // Validate required fields
        guard let recipeName = recipeData["recipe_name"] as? String,
              let mealType = recipeData["meal_type"] as? String,
              let ingredients = recipeData["ingredients"] as? [String],
              let cookingInstructions = recipeData["cooking_instructions"] as? String else {
            throw MigrationError.missingRequiredFields
        }
        
        // Generate unique ID
        let recipeId = generateRecipeId(recipeName: recipeName, cuisine: cuisine)
        
        // Convert cooking time
        let cookingTimeCategory = recipeData["cooking_time_category"] as? String ?? "Under 30 min"
        let cookingTimeMinutes = convertCookingTime(cookingTimeCategory)
        
        // Convert dietary tags
        let dietType = recipeData["diet_type"] as? String ?? "general"
        let dietaryRestrictions = recipeData["dietary_restrictions"] as? [String] ?? []
        let dietaryTags = convertDietaryTags(dietType: dietType, restrictions: dietaryRestrictions)
        
        // Convert cooking instructions to steps
        let steps = convertInstructionsToSteps(cookingInstructions)
        
        // Create CloudKitRecipe
        return CloudKitRecipe(
            id: recipeId,
            name: recipeName,
            cuisine: cuisine,
            mealType: mealType,
            dietaryTags: dietaryTags,
            dietType: dietType,
            calories: recipeData["calories_per_serving"] as? Int,
            cookingTimeMinutes: cookingTimeMinutes,
            servings: recipeData["servings"] as? Int ?? 4,
            difficulty: recipeData["difficulty"] as? String ?? "Medium",
            region: recipeData["regional_origin"] as? String,
            ingredients: ingredients,
            utensils: recipeData["utensils_required"] as? [String],
            steps: steps,
            chefTips: recipeData["chef_tips"] as? String,
            lunchboxPresentation: recipeData["lunchbox_presentation"] as? String,
            createdAt: Date(),
            updatedAt: Date(),
            schemaVersion: 1,
            coverImage: nil,
            stepMedia: nil,
            videoDemo: nil,
            originalRecipeName: recipeName,
            originalCookingTimeCategory: cookingTimeCategory,
            originalProteins: recipeData["proteins"] as? [String],
            originalDietaryRestrictions: dietaryRestrictions
        )
    }
    
    private func uploadRecipesInBatches(_ recipes: [CloudKitRecipe]) async throws {
        let batchSize = 50
        let totalBatches = (recipes.count + batchSize - 1) / batchSize
        
        logger.info("📤 Uploading \(recipes.count) recipes in \(totalBatches) batches")
        
        for i in stride(from: 0, to: recipes.count, by: batchSize) {
            let endIndex = min(i + batchSize, recipes.count)
            let batch = Array(recipes[i..<endIndex])
            let batchNumber = (i / batchSize) + 1
            
            currentOperation = "Uploading batch \(batchNumber)/\(totalBatches)..."
            
            do {
                try await uploadBatch(batch)
                successfulUploads += batch.count
                logger.info("✅ Batch \(batchNumber) uploaded successfully")
            } catch {
                failedUploads += batch.count
                logger.error("❌ Batch \(batchNumber) failed: \(error)")
                // Continue with next batch instead of failing completely
            }
            
            processedRecipes += batch.count
            progress = Double(processedRecipes) / Double(totalRecipes)
            
            // Add small delay to avoid rate limiting
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func uploadBatch(_ recipes: [CloudKitRecipe]) async throws {
        let records = recipes.map { $0.toCKRecord() }
        
        // CloudKit batch upload
        let operation = CKModifyRecordsOperation(recordsToSave: records)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateRecipeId(recipeName: String, cuisine: String) -> String {
        let slug = recipeName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
            .prefix(50)
        return "\(cuisine.lowercased())-\(slug)-\(Int(Date().timeIntervalSince1970))"
    }
    
    private func convertCookingTime(_ category: String) -> Int {
        switch category.lowercased() {
        case "under 5 min": return 5
        case "under 10 min": return 10
        case "under 15 min": return 15
        case "under 20 min": return 20
        case "under 25 min": return 25
        case "under 30 min": return 30
        case "under 40 min": return 40
        case "under 45 min": return 45
        case "under 50 min": return 50
        case "under 1 hour": return 60
        case "under 1.5 hours": return 90
        case "under 2 hours": return 120
        case "any time": return 180
        case "15-30 min": return 30 // Handle this common case
        default: return 45
        }
    }
    
    private func convertDietaryTags(dietType: String, restrictions: [String]) -> [String] {
        var tags: Set<String> = []
        
        // Add diet type tags
        switch dietType.lowercased() {
        case "vegetarian":
            tags.insert("Vegetarian")
        case "vegan":
            tags.insert("Vegan")
            tags.insert("Vegetarian")
        case "non-vegetarian":
            tags.insert("Non-Vegetarian")
        default:
            break
        }
        
        // Add restriction tags
        for restriction in restrictions {
            switch restriction.lowercased() {
            case "contains_dairy":
                tags.insert("Dairy-Free")
            case "contains_nuts":
                tags.insert("Nut-Free")
            case "contains_gluten":
                tags.insert("Gluten-Free")
            case "contains_eggs":
                tags.insert("Egg-Free")
            case "contains_soy":
                tags.insert("Soy-Free")
            default:
                tags.insert(restriction.capitalized)
            }
        }
        
        return Array(tags)
    }
    
    private func convertInstructionsToSteps(_ instructions: String) -> [String] {
        if instructions.isEmpty {
            return ["No cooking instructions available"]
        }
        
        // Split by common delimiters and clean up
        let steps = instructions
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
        
        return steps.isEmpty ? [instructions] : steps
    }
}

// MARK: - Migration Errors

enum MigrationError: LocalizedError {
    case fileNotFound(String)
    case invalidJSONStructure(String)
    case missingRequiredFields
    case cloudKitError(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Recipe file not found: \(fileName)"
        case .invalidJSONStructure(let fileName):
            return "Invalid JSON structure in file: \(fileName)"
        case .missingRequiredFields:
            return "Recipe is missing required fields"
        case .cloudKitError(let error):
            return "CloudKit error: \(error.localizedDescription)"
        }
    }
}
