#!/usr/bin/env swift

import Foundation

// Swift-based schema validation for CloudKit migration
struct SchemaValidator {
    var errors: [String] = []
    var warnings: [String] = []
    var stats = ValidationStats()
    
    struct ValidationStats {
        var totalFiles = 0
        var totalRecipes = 0
        var validRecipes = 0
        var invalidRecipes = 0
    }
    
    mutating func validateAll() {
        print("🔍 Validating Recipe Schema")
        print("============================")
        
        let recipesDir = "Cheffy/Resources/recipes"
        
        guard FileManager.default.fileExists(atPath: recipesDir) else {
            print("❌ Recipes directory not found: \(recipesDir)")
            return
        }
        
        let jsonFiles = getJsonFiles(in: recipesDir)
        print("📁 Found \(jsonFiles.count) JSON files to validate")
        
        for filePath in jsonFiles {
            validateFile(at: filePath)
        }
        
        generateReport()
    }
    
    func getJsonFiles(in directory: String) -> [String] {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: directory)
            return items
                .filter { $0.hasSuffix(".json") }
                .map { "\(directory)/\($0)" }
        } catch {
            print("❌ Error reading directory: \(error)")
            return []
        }
    }
    
    mutating func validateFile(at filePath: String) {
        print("\n📄 Validating: \(URL(fileURLWithPath: filePath).lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            stats.totalFiles += 1
            
            guard let cuisines = json["cuisines"] as? [String: [[String: Any]]] else {
                addError(file: filePath, message: "Missing 'cuisines' key")
                return
            }
            
            for (cuisineName, recipes) in cuisines {
                for recipe in recipes {
                    stats.totalRecipes += 1
                    validateRecipe(recipe, filePath: filePath, cuisineName: cuisineName)
                }
            }
            
        } catch {
            addError(file: filePath, message: "JSON parse error: \(error)")
        }
    }
    
    mutating func validateRecipe(_ recipe: [String: Any], filePath: String, cuisineName: String) {
        let recipeName = recipe["recipe_name"] as? String ?? "Unknown"
        
        // Required fields validation
        let requiredFields = ["recipe_name", "cuisine", "meal_type", "ingredients", "cooking_instructions"]
        
        for field in requiredFields {
            if recipe[field] == nil {
                addError(file: filePath, message: "\(cuisineName)/\(recipeName): Missing required field '\(field)'")
                return
            }
        }
        
        // Field type validation
        validateFieldType(recipe, fieldName: "recipe_name", expectedType: "String", filePath: filePath, cuisineName: cuisineName, recipeName: recipeName)
        validateFieldType(recipe, fieldName: "cuisine", expectedType: "String", filePath: filePath, cuisineName: cuisineName, recipeName: recipeName)
        validateFieldType(recipe, fieldName: "meal_type", expectedType: "String", filePath: filePath, cuisineName: cuisineName, recipeName: recipeName)
        validateFieldType(recipe, fieldName: "ingredients", expectedType: "Array", filePath: filePath, cuisineName: cuisineName, recipeName: recipeName)
        validateFieldType(recipe, fieldName: "cooking_instructions", expectedType: "String", filePath: filePath, cuisineName: cuisineName, recipeName: recipeName)
        
        // Meal type validation
        if let mealType = recipe["meal_type"] as? String, !["Kids", "Regular"].contains(mealType) {
            addWarning(file: filePath, message: "\(cuisineName)/\(recipeName): Invalid meal_type '\(mealType)'")
        }
        
        // Ingredients validation
        if let ingredients = recipe["ingredients"] as? [String], ingredients.isEmpty {
            addError(file: filePath, message: "\(cuisineName)/\(recipeName): Empty ingredients array")
        }
        
        // Cooking instructions validation
        if let instructions = recipe["cooking_instructions"] as? String, instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addError(file: filePath, message: "\(cuisineName)/\(recipeName): Empty cooking instructions")
        }
        
        // Servings validation
        if let servings = recipe["servings"] as? Int, servings <= 0 {
            addError(file: filePath, message: "\(cuisineName)/\(recipeName): Invalid servings value")
        }
        
        // Calories validation
        if let calories = recipe["calories_per_serving"] as? Int, calories < 0 {
            addError(file: filePath, message: "\(cuisineName)/\(recipeName): Invalid calories value")
        }
        
        // Cooking time category validation
        if let timeCategory = recipe["cooking_time_category"] as? String {
            let validTimeCategories = [
                "Under 5 min", "Under 10 min", "Under 15 min", "Under 20 min",
                "Under 25 min", "Under 30 min", "Under 40 min", "Under 45 min",
                "Under 50 min", "Under 1 hour", "Under 1.5 hours", "Under 2 hours",
                "Any Time"
            ]
            
            if !validTimeCategories.contains(timeCategory) {
                addWarning(file: filePath, message: "\(cuisineName)/\(recipeName): Unknown cooking time category '\(timeCategory)'")
            }
        }
        
        // Difficulty validation
        if let difficulty = recipe["difficulty"] as? String, !["Easy", "Medium", "Hard"].contains(difficulty) {
            addWarning(file: filePath, message: "\(cuisineName)/\(recipeName): Unknown difficulty '\(difficulty)'")
        }
        
        stats.validRecipes += 1
    }
    
    mutating func validateFieldType(_ recipe: [String: Any], fieldName: String, expectedType: String, filePath: String, cuisineName: String, recipeName: String) {
        guard let value = recipe[fieldName] else { return }
        
        let actualType: String
        if value is [Any] {
            actualType = "Array"
        } else if value is String || value is NSString {
            actualType = "String"
        } else {
            actualType = String(describing: type(of: value))
        }
        
        if actualType != expectedType {
            addError(file: filePath, message: "\(cuisineName)/\(recipeName): Field '\(fieldName)' should be \(expectedType), got \(actualType)")
        }
    }
    
    mutating func addError(file: String, message: String) {
        errors.append("\(URL(fileURLWithPath: file).lastPathComponent): \(message)")
        stats.invalidRecipes += 1
    }
    
    mutating func addWarning(file: String, message: String) {
        warnings.append("\(URL(fileURLWithPath: file).lastPathComponent): \(message)")
    }
    
    func generateReport() {
        print("\n📊 Validation Report")
        print("===================")
        
        print("✅ Valid Recipes: \(stats.validRecipes)")
        print("❌ Invalid Recipes: \(stats.invalidRecipes)")
        print("⚠️  Warnings: \(warnings.count)")
        print("📁 Files Processed: \(stats.totalFiles)")
        print("📝 Total Recipes: \(stats.totalRecipes)")
        
        let successRate = stats.totalRecipes > 0 ? (Double(stats.validRecipes) / Double(stats.totalRecipes)) * 100 : 0
        print("📈 Success Rate: \(String(format: "%.1f", successRate))%")
        
        if !errors.isEmpty {
            print("\n❌ Errors:")
            for (index, error) in errors.enumerated() {
                print("\(index + 1). \(error)")
            }
        }
        
        if !warnings.isEmpty {
            print("\n⚠️  Warnings:")
            for (index, warning) in warnings.enumerated() {
                print("\(index + 1). \(warning)")
            }
        }
        
        // Save detailed report
        let report = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "stats": [
                "totalFiles": stats.totalFiles,
                "totalRecipes": stats.totalRecipes,
                "validRecipes": stats.validRecipes,
                "invalidRecipes": stats.invalidRecipes
            ],
            "errors": errors,
            "warnings": warnings
        ] as [String: Any]
        
        do {
            let reportData = try JSONSerialization.data(withJSONObject: report, options: .prettyPrinted)
            try reportData.write(to: URL(fileURLWithPath: "CloudKit/validation_report.json"))
            print("\n📄 Detailed report saved to: CloudKit/validation_report.json")
        } catch {
            print("❌ Failed to save report: \(error)")
        }
        
        // Exit with error code if there are validation errors
        if !errors.isEmpty {
            print("\n❌ Validation failed with \(errors.count) errors")
            exit(1)
        } else {
            print("\n✅ All recipes passed validation!")
        }
    }
}

// Main execution
var validator = SchemaValidator()
validator.validateAll()
