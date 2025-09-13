import Foundation
import CloudKit

// MARK: - CloudKit Recipe Schema Design
// Future-proof schema for scalable recipe management

struct CloudKitRecipe {
    // MARK: - Core Identity Fields
    let id: String                    // UUID or slug (unique identifier)
    let name: String                  // Recipe name (required)
    let cuisine: String               // Cuisine type (indexed for filtering)
    let mealType: String              // "Kids" or "Regular" (indexed)
    
    // MARK: - Dietary & Nutrition Fields
    let dietaryTags: [String]         // ["Vegan", "Gluten-Free", etc.] (indexed)
    let dietType: String              // "vegetarian", "vegan", "non-vegetarian"
    let calories: Int?                // Optional calories per serving
    
    // MARK: - Cooking Details
    let cookingTimeMinutes: Int       // Converted from cooking_time_category
    let servings: Int                 // Number of servings
    let difficulty: String            // "Easy", "Medium", "Hard"
    let region: String?               // Regional origin (e.g., "North Indian")
    
    // MARK: - Recipe Content
    let ingredients: [String]         // List of ingredients
    let utensils: [String]?           // Required utensils (optional)
    let steps: [String]               // Cooking instructions as steps
    let chefTips: String?             // Chef tips and notes
    let lunchboxPresentation: String? // Kids-specific presentation tips
    
    // MARK: - Metadata
    let createdAt: Date               // Auto-generated creation date
    let updatedAt: Date               // Auto-generated update date
    let schemaVersion: Int            // For future migrations (start with 1)
    
    // MARK: - Future-Proof Media Fields (Optional)
    let coverImage: CKAsset?          // Recipe thumbnail image
    let stepMedia: [CKAsset]?         // Images/videos for each step
    let videoDemo: CKAsset?           // Full cooking video
    
    // MARK: - Legacy Fields (for migration compatibility)
    let originalRecipeName: String?   // Original recipe_name from JSON
    let originalCookingTimeCategory: String? // Original time category
    let originalProteins: [String]?   // Original proteins list
    let originalDietaryRestrictions: [String]? // Original restrictions
}

// MARK: - CloudKit Record Conversion
extension CloudKitRecipe {
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
    
    static func fromCKRecord(_ record: CKRecord) -> CloudKitRecipe? {
        guard let name = record["name"] as? String,
              let cuisine = record["cuisine"] as? String,
              let mealType = record["mealType"] as? String,
              let dietaryTags = record["dietaryTags"] as? [String],
              let dietType = record["dietType"] as? String,
              let cookingTimeMinutes = record["cookingTimeMinutes"] as? Int,
              let servings = record["servings"] as? Int,
              let difficulty = record["difficulty"] as? String,
              let ingredients = record["ingredients"] as? [String],
              let steps = record["steps"] as? [String],
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let schemaVersion = record["schemaVersion"] as? Int else {
            return nil
        }
        
        return CloudKitRecipe(
            id: record.recordID.recordName,
            name: name,
            cuisine: cuisine,
            mealType: mealType,
            dietaryTags: dietaryTags,
            dietType: dietType,
            calories: record["calories"] as? Int,
            cookingTimeMinutes: cookingTimeMinutes,
            servings: servings,
            difficulty: difficulty,
            region: record["region"] as? String,
            ingredients: ingredients,
            utensils: record["utensils"] as? [String],
            steps: steps,
            chefTips: record["chefTips"] as? String,
            lunchboxPresentation: record["lunchboxPresentation"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt,
            schemaVersion: schemaVersion,
            coverImage: record["coverImage"] as? CKAsset,
            stepMedia: record["stepMedia"] as? [CKAsset],
            videoDemo: record["videoDemo"] as? CKAsset,
            originalRecipeName: record["originalRecipeName"] as? String,
            originalCookingTimeCategory: record["originalCookingTimeCategory"] as? String,
            originalProteins: record["originalProteins"] as? [String],
            originalDietaryRestrictions: record["originalDietaryRestrictions"] as? [String]
        )
    }
}

// MARK: - CloudKit Schema Definition
struct CloudKitSchema {
    static let recipeRecordType = "Recipe"
    
    // Indexed fields for efficient querying
    static let indexedFields = [
        "cuisine",
        "mealType", 
        "dietaryTags",
        "cookingTimeMinutes",
        "servings",
        "difficulty",
        "createdAt"
    ]
    
    // Required fields for validation
    static let requiredFields = [
        "name",
        "cuisine", 
        "mealType",
        "dietaryTags",
        "dietType",
        "cookingTimeMinutes",
        "servings",
        "difficulty",
        "ingredients",
        "steps",
        "schemaVersion"
    ]
}

// MARK: - Migration Utilities
struct RecipeMigrationUtils {
    /// Converts cooking time category to minutes
    static func convertCookingTime(_ category: String) -> Int {
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
        default: return 45 // Default fallback
        }
    }
    
    /// Converts dietary restrictions to standardized tags
    static func convertDietaryTags(dietType: String, restrictions: [String]) -> [String] {
        var tags: [String] = []
        
        // Add diet type tags
        switch dietType.lowercased() {
        case "vegetarian":
            tags.append("Vegetarian")
        case "vegan":
            tags.append("Vegan")
            tags.append("Vegetarian") // Vegan implies vegetarian
        case "non-vegetarian":
            tags.append("Non-Vegetarian")
        default:
            break
        }
        
        // Add restriction tags
        for restriction in restrictions {
            switch restriction.lowercased() {
            case "contains_dairy":
                tags.append("Dairy-Free")
            case "contains_nuts":
                tags.append("Nut-Free")
            case "contains_gluten":
                tags.append("Gluten-Free")
            case "contains_eggs":
                tags.append("Egg-Free")
            case "contains_soy":
                tags.append("Soy-Free")
            default:
                tags.append(restriction.capitalized)
            }
        }
        
        return Array(Set(tags)) // Remove duplicates
    }
    
    /// Validates recipe data before migration
    static func validateRecipe(_ recipe: [String: Any]) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        // Check required fields
        let requiredFields = ["recipe_name", "cuisine", "meal_type", "ingredients", "cooking_instructions"]
        for field in requiredFields {
            if recipe[field] == nil {
                errors.append("Missing required field: \(field)")
            }
        }
        
        // Validate ingredients
        if let ingredients = recipe["ingredients"] as? [String], ingredients.isEmpty {
            errors.append("Ingredients list is empty")
        }
        
        // Validate steps
        if let instructions = recipe["cooking_instructions"] as? String, instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Cooking instructions are empty")
        }
        
        return (errors.isEmpty, errors)
    }
}
