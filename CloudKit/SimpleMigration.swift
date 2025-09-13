#!/usr/bin/env swift

import Foundation
import CloudKit

// Simple CloudKit Migration Script
// Run this to upload all JSON recipes to CloudKit

class SimpleCloudKitMigration {
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.cheffy.app")
        self.database = container.privateCloudDatabase
    }
    
    func migrateAllRecipes() async {
        print("🚀 Starting CloudKit Migration")
        print("=============================")
        
        do {
            // Load all recipes from JSON files
            let allRecipes = try await loadAllRecipesFromJSON()
            print("📊 Loaded \(allRecipes.count) recipes from JSON files")
            
            // Upload recipes in batches
            try await uploadRecipesInBatches(allRecipes)
            
            print("✅ Migration completed successfully!")
            
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    private func loadAllRecipesFromJSON() async throws -> [CloudKitRecipe] {
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
            print("📁 Loading \(fileName)...")
            let recipes = try await loadRecipesFromFile(fileName)
            allRecipes.append(contentsOf: recipes)
            print("   ✅ Loaded \(recipes.count) recipes")
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
                    print("   ⚠️ Failed to convert recipe: \(error)")
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
        
        print("📤 Uploading \(recipes.count) recipes in \(totalBatches) batches")
        
        var successfulUploads = 0
        var failedUploads = 0
        
        for i in stride(from: 0, to: recipes.count, by: batchSize) {
            let endIndex = min(i + batchSize, recipes.count)
            let batch = Array(recipes[i..<endIndex])
            let batchNumber = (i / batchSize) + 1
            
            print("   📦 Uploading batch \(batchNumber)/\(totalBatches) (\(batch.count) recipes)...")
            
            do {
                try await uploadBatch(batch)
                successfulUploads += batch.count
                print("   ✅ Batch \(batchNumber) uploaded successfully")
            } catch {
                failedUploads += batch.count
                print("   ❌ Batch \(batchNumber) failed: \(error)")
                // Continue with next batch instead of failing completely
            }
            
            // Add small delay to avoid rate limiting
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        print("\n📊 Migration Summary:")
        print("   ✅ Successful: \(successfulUploads)")
        print("   ❌ Failed: \(failedUploads)")
        print("   📈 Success Rate: \(String(format: "%.1f", Double(successfulUploads) / Double(recipes.count) * 100))%")
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

// MARK: - CloudKit Recipe Model

struct CloudKitRecipe {
    let id: String
    let name: String
    let cuisine: String
    let mealType: String
    let dietaryTags: [String]
    let dietType: String
    let calories: Int?
    let cookingTimeMinutes: Int
    let servings: Int
    let difficulty: String
    let region: String?
    let ingredients: [String]
    let utensils: [String]?
    let steps: [String]
    let chefTips: String?
    let lunchboxPresentation: String?
    let createdAt: Date
    let updatedAt: Date
    let schemaVersion: Int
    let coverImage: CKAsset?
    let stepMedia: [CKAsset]?
    let videoDemo: CKAsset?
    let originalRecipeName: String?
    let originalCookingTimeCategory: String?
    let originalProteins: [String]?
    let originalDietaryRestrictions: [String]?
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Recipe", recordID: CKRecord.ID(recordName: id))
        
        // Core fields
        record["name"] = name
        record["cuisine"] = cuisine
        record["mealType"] = mealType
        record["dietaryTags"] = dietaryTags
        record["dietType"] = dietType
        record["calories"] = calories
        record["cookingTimeMinutes"] = cookingTimeMinutes
        record["servings"] = servings
        record["difficulty"] = difficulty
        record["region"] = region
        record["ingredients"] = ingredients
        record["utensils"] = utensils
        record["steps"] = steps
        record["chefTips"] = chefTips
        record["lunchboxPresentation"] = lunchboxPresentation
        record["createdAt"] = createdAt
        record["updatedAt"] = updatedAt
        record["schemaVersion"] = schemaVersion
        
        // Media fields (optional)
        record["coverImage"] = coverImage
        record["stepMedia"] = stepMedia
        record["videoDemo"] = videoDemo
        
        // Legacy fields
        record["originalRecipeName"] = originalRecipeName
        record["originalCookingTimeCategory"] = originalCookingTimeCategory
        record["originalProteins"] = originalProteins
        record["originalDietaryRestrictions"] = originalDietaryRestrictions
        
        return record
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

// MARK: - Main Execution

@main
struct CloudKitMigrationApp {
    static func main() async {
        let migration = SimpleCloudKitMigration()
        await migration.migrateAllRecipes()
    }
}
