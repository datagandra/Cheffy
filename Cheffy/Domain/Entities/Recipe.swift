import Foundation
import CoreData

// MARK: - Recipe Entity
struct Recipe: Identifiable, Codable {
    let id: UUID
    let title: String
    let name: String // Keep for backward compatibility
    let cuisine: Cuisine
    let difficulty: Difficulty
    let prepTime: Int // minutes
    let cookTime: Int // minutes
    let servings: Int
    let ingredients: [Ingredient]
    let steps: [CookingStep]
    let winePairings: [WinePairing]
    var dietaryNotes: [DietaryNote]
    let platingTips: String
    let chefNotes: String
    let imageURL: URL?
    let stepImages: [URL]
    let createdAt: Date
    var isFavorite: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        name: String? = nil,
        cuisine: Cuisine,
        difficulty: Difficulty,
        prepTime: Int,
        cookTime: Int,
        servings: Int,
        ingredients: [Ingredient],
        steps: [CookingStep],
        winePairings: [WinePairing] = [],
        dietaryNotes: [DietaryNote] = [],
        platingTips: String = "",
        chefNotes: String = "",
        imageURL: URL? = nil,
        stepImages: [URL] = [],
        createdAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.name = name ?? title // Use title as name if not provided
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.ingredients = ingredients
        self.steps = steps
        self.winePairings = winePairings
        self.dietaryNotes = dietaryNotes
        self.platingTips = platingTips
        self.chefNotes = chefNotes
        self.imageURL = imageURL
        self.stepImages = stepImages
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }
}

// MARK: - Enums
enum Cuisine: String, CaseIterable, Codable {
    case french = "French"
    case italian = "Italian"
    case japanese = "Japanese"
    case chinese = "Chinese"
    case indian = "Indian"
    case mexican = "Mexican"
    case thai = "Thai"
    case mediterranean = "Mediterranean"
    case american = "American"
    case greek = "Greek"
    case spanish = "Spanish"
    case moroccan = "Moroccan"
    case vietnamese = "Vietnamese"
    case korean = "Korean"
    case turkish = "Turkish"
    case lebanese = "Lebanese"
    case persian = "Persian"
    case ethiopian = "Ethiopian"
    case brazilian = "Brazilian"
    case peruvian = "Peruvian"
}

enum Difficulty: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case expert = "Expert"
}

// MARK: - Supporting Models
struct Ingredient: Identifiable, Codable {
    let id: UUID
    let name: String
    let amount: Double
    let unit: String
    let notes: String?
    
    init(id: UUID = UUID(), name: String, amount: Double, unit: String, notes: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.notes = notes
    }
}

struct CookingStep: Identifiable, Codable {
    let id: UUID
    let stepNumber: Int
    let description: String
    let duration: Int? // minutes
    let temperature: Double? // celsius
    let imageURL: URL?
    let tips: String?
    
    init(id: UUID = UUID(), stepNumber: Int, description: String, duration: Int? = nil, temperature: Double? = nil, imageURL: URL? = nil, tips: String? = nil) {
        self.id = id
        self.stepNumber = stepNumber
        self.description = description
        self.duration = duration
        self.temperature = temperature
        self.imageURL = imageURL
        self.tips = tips
    }
}

struct WinePairing: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: WineType
    let region: String
    let description: String
    let priceRange: String?
    
    init(id: UUID = UUID(), name: String, type: WineType, region: String, description: String, priceRange: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.region = region
        self.description = description
        self.priceRange = priceRange
    }
}

enum WineType: String, CaseIterable, Codable {
    case red = "Red"
    case white = "White"
    case rose = "Rosé"
    case sparkling = "Sparkling"
    case dessert = "Dessert"
}

enum DietaryNote: String, CaseIterable, Codable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case nutFree = "Nut-Free"
    case lowCarb = "Low-Carb"
    case keto = "Keto"
    case paleo = "Paleo"
    case halal = "Halal"
    case kosher = "Kosher"
}

// MARK: - Recipe Extensions
extension Recipe {
    var totalTime: Int {
        prepTime + cookTime
    }
    
    var formattedPrepTime: String {
        let hours = prepTime / 60
        let minutes = prepTime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedCookTime: String {
        let hours = cookTime / 60
        let minutes = cookTime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedTotalTime: String {
        let hours = totalTime / 60
        let minutes = totalTime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Calorie Calculation
    var caloriesPerServing: Int {
        calculateCaloriesPerServing()
    }
    
    private func calculateCaloriesPerServing() -> Int {
        var totalCalories = 0
        
        for ingredient in ingredients {
            let calories = getCaloriesForIngredient(ingredient)
            totalCalories += calories
        }
        
        // Add cooking method calories (oil, butter, etc.)
        let cookingCalories = estimateCookingMethodCalories()
        totalCalories += cookingCalories
        
        return totalCalories / servings
    }
    
    private func getCaloriesForIngredient(_ ingredient: Ingredient) -> Int {
        let ingredientName = ingredient.name.lowercased()
        let amount = ingredient.amount
        
        // Convert to grams for calculation
        let grams = convertToGrams(amount: amount, unit: ingredient.unit)
        
        // Common ingredient calorie densities (calories per 100g)
        let calorieDensities: [String: Double] = [
            // Proteins
            "chicken": 165, "beef": 250, "pork": 242, "lamb": 294, "fish": 120, "salmon": 208, "tuna": 144,
            "shrimp": 99, "eggs": 155, "tofu": 76, "tempeh": 192, "lentils": 116, "chickpeas": 164,
            
            // Grains
            "rice": 130, "pasta": 131, "bread": 265, "flour": 364, "quinoa": 120, "oats": 389,
            
            // Vegetables
            "onion": 40, "garlic": 149, "tomato": 18, "potato": 77, "carrot": 41, "bell pepper": 20,
            "spinach": 23, "kale": 49, "broccoli": 34, "cauliflower": 25, "mushroom": 22, "zucchini": 17,
            "eggplant": 25, "cucumber": 16, "lettuce": 15, "cabbage": 25, "celery": 16,
            
            // Fruits
            "apple": 52, "banana": 89, "orange": 47, "lemon": 29, "lime": 30, "mango": 60,
            
            // Dairy
            "milk": 42, "cheese": 402, "yogurt": 59, "cream": 340, "butter": 717,
            
            // Oils and Fats
            "olive oil": 884, "vegetable oil": 884, "coconut oil": 862, "sesame oil": 884,
            
            // Nuts and Seeds
            "almond": 579, "walnut": 654, "cashew": 553, "peanut": 567, "sesame": 573,
            
            // Spices and Herbs (minimal calories)
            "salt": 0, "pepper": 251, "cumin": 375, "coriander": 298, "turmeric": 354,
            "ginger": 80, "cinnamon": 247, "paprika": 282, "oregano": 265, "basil": 22,
            "parsley": 36, "cilantro": 23, "mint": 44, "thyme": 101, "rosemary": 131,
            
            // Common ingredients
            "sugar": 387, "honey": 304, "maple syrup": 260, "vinegar": 18, "soy sauce": 53,
            "tomato paste": 82, "tomato sauce": 29, "coconut milk": 230, "peanut butter": 588
        ]
        
        // Find matching ingredient
        for (key, caloriesPer100g) in calorieDensities {
            if ingredientName.contains(key) {
                return Int((grams * caloriesPer100g) / 100.0)
            }
        }
        
        // Default calorie estimate for unknown ingredients
        return Int(grams * 1.5) // Rough estimate of 1.5 calories per gram
    }
    
    private func convertToGrams(amount: Double, unit: String) -> Double {
        let unitLower = unit.lowercased()
        
        switch unitLower {
        case "g", "gram", "grams":
            return amount
        case "kg", "kilogram", "kilograms":
            return amount * 1000
        case "ml", "milliliter", "milliliters":
            return amount * 1.0 // Approximate 1g per ml for most liquids
        case "l", "liter", "liters":
            return amount * 1000
        case "cup", "cups":
            return amount * 240 // Approximate 240g per cup
        case "tbsp", "tablespoon", "tablespoons":
            return amount * 15 // Approximate 15g per tablespoon
        case "tsp", "teaspoon", "teaspoons":
            return amount * 5 // Approximate 5g per teaspoon
        case "oz", "ounce", "ounces":
            return amount * 28.35
        case "lb", "pound", "pounds":
            return amount * 453.59
        case "pinch":
            return amount * 0.36 // Approximate 0.36g per pinch
        case "dash":
            return amount * 0.62 // Approximate 0.62g per dash
        default:
            return amount * 1.0 // Default assumption
        }
    }
    
    private func estimateCookingMethodCalories() -> Int {
        // Estimate additional calories from cooking methods (oil, butter, etc.)
        var cookingCalories = 0
        
        // Check for oil/butter in ingredients
        let oilIngredients = ingredients.filter { ingredient in
            let name = ingredient.name.lowercased()
            return name.contains("oil") || name.contains("butter") || name.contains("ghee")
        }
        
        for oil in oilIngredients {
            let grams = convertToGrams(amount: oil.amount, unit: oil.unit)
            cookingCalories += Int(grams * 9) // 9 calories per gram of fat
        }
        
        // Add base cooking calories if no oil found
        if oilIngredients.isEmpty {
            cookingCalories += 50 // Base cooking calories
        }
        
        return cookingCalories
    }
} 