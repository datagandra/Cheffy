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
        
        // Comprehensive ingredient calorie densities (calories per 100g)
        let calorieDensities: [String: Double] = [
            // Proteins - Detailed breakdown
            "chicken breast": 165, "chicken thigh": 209, "chicken wing": 290, "chicken": 165,
            "beef steak": 271, "beef ground": 250, "beef chuck": 267, "beef": 250,
            "pork chop": 242, "pork loin": 242, "pork": 242,
            "lamb chop": 294, "lamb shoulder": 294, "lamb": 294,
            "fish fillet": 120, "salmon": 208, "tuna": 144, "cod": 105, "haddock": 116, "tilapia": 96,
            "shrimp": 99, "prawn": 99, "crab": 97, "lobster": 89, "mussel": 86, "oyster": 69,
            "egg": 155, "egg white": 52, "egg yolk": 322,
            "tofu": 76, "tempeh": 192, "seitan": 370,
            "lentil": 116, "chickpea": 164, "black bean": 132, "kidney bean": 127, "pinto bean": 143,
            "quinoa": 120, "brown rice": 111, "white rice": 130, "basmati rice": 130,
            
            // Grains and Starches
            "pasta": 131, "spaghetti": 131, "penne": 131, "rigatoni": 131,
            "bread": 265, "whole wheat bread": 247, "sourdough": 261,
            "flour": 364, "all-purpose flour": 364, "whole wheat flour": 340,
            "oats": 389, "oatmeal": 68, "steel cut oats": 389,
            "potato": 77, "sweet potato": 86, "yam": 118,
            
            // Vegetables - Detailed
            "onion": 40, "red onion": 40, "yellow onion": 40, "white onion": 40,
            "garlic": 149, "shallot": 72,
            "tomato": 18, "cherry tomato": 18, "roma tomato": 18,
            "carrot": 41, "baby carrot": 41,
            "bell pepper": 20, "red bell pepper": 31, "green bell pepper": 20, "yellow bell pepper": 27,
            "spinach": 23, "kale": 49, "arugula": 25, "lettuce": 15, "romaine": 17,
            "broccoli": 34, "cauliflower": 25, "brussels sprout": 43,
            "mushroom": 22, "button mushroom": 22, "portobello": 22, "shiitake": 34,
            "zucchini": 17, "yellow squash": 16, "eggplant": 25, "cucumber": 16,
            "celery": 16, "cabbage": 25, "red cabbage": 31,
            "asparagus": 20, "green bean": 31, "snap pea": 42,
            "corn": 86, "sweet corn": 86,
            "peas": 84, "green peas": 84,
            
            // Fruits
            "apple": 52, "banana": 89, "orange": 47, "lemon": 29, "lime": 30,
            "mango": 60, "pineapple": 50, "strawberry": 32, "blueberry": 57,
            "grape": 62, "peach": 39, "plum": 46, "pear": 57,
            
            // Dairy and Dairy Alternatives
            "milk": 42, "whole milk": 61, "skim milk": 42, "almond milk": 17,
            "cheese": 402, "cheddar": 403, "mozzarella": 280, "parmesan": 431,
            "yogurt": 59, "greek yogurt": 59, "plain yogurt": 59,
            "cream": 340, "heavy cream": 340, "sour cream": 198,
            "butter": 717, "margarine": 717,
            
            // Oils and Fats
            "olive oil": 884, "extra virgin olive oil": 884, "vegetable oil": 884,
            "coconut oil": 862, "sesame oil": 884, "avocado oil": 884,
            "canola oil": 884, "sunflower oil": 884,
            
            // Nuts and Seeds
            "almond": 579, "walnut": 654, "cashew": 553, "peanut": 567,
            "pistachio": 560, "pecan": 691, "macadamia": 718,
            "sesame": 573, "sunflower seed": 584, "pumpkin seed": 559,
            "chia seed": 486, "flax seed": 534,
            
            // Spices and Herbs (minimal calories)
            "salt": 0, "sea salt": 0, "kosher salt": 0,
            "pepper": 251, "black pepper": 251, "white pepper": 296,
            "cumin": 375, "coriander": 298, "turmeric": 354, "paprika": 282,
            "ginger": 80, "fresh ginger": 80, "ground ginger": 335,
            "cinnamon": 247, "nutmeg": 525, "clove": 274,
            "oregano": 265, "basil": 22, "parsley": 36, "cilantro": 23,
            "mint": 44, "thyme": 101, "rosemary": 131, "sage": 315,
            "bay leaf": 313, "cardamom": 311, "star anise": 337,
            
            // Common ingredients and condiments
            "sugar": 387, "brown sugar": 380, "honey": 304, "maple syrup": 260,
            "vinegar": 18, "balsamic vinegar": 88, "apple cider vinegar": 22,
            "soy sauce": 53, "fish sauce": 35, "oyster sauce": 51,
            "tomato paste": 82, "tomato sauce": 29, "ketchup": 102,
            "coconut milk": 230, "coconut cream": 330,
            "peanut butter": 588, "almond butter": 614, "tahini": 595,
            "mayonnaise": 680, "mustard": 66, "hot sauce": 15,
            
            // Asian ingredients
            "miso": 199, "natto": 212, "kimchi": 23,
            "rice vinegar": 18, "mirin": 43, "sake": 134,
            "curry paste": 54, "curry powder": 325,
            "lemongrass": 99, "kaffir lime": 43, "galangal": 71,
            
            // Mexican ingredients
            "jalapeño": 29, "serrano": 29, "habanero": 40,
            "tomatillo": 32, "poblano": 20, "anaheim": 20,
            "queso fresco": 299, "cotija": 366, "panela": 299,
            
            // Indian ingredients
            "paneer": 321, "ghee": 900, "dal": 116, "chana": 164,
            "asafoetida": 297, "fenugreek": 323, "amchur": 314,
            
            // Mediterranean ingredients
            "feta": 264, "halloumi": 321, "kalamata": 115,
            "artichoke": 47, "sun-dried tomato": 258,
            
            // Legumes and pulses
            "black eyed pea": 116, "navy bean": 139, "lima bean": 113,
            "fava bean": 88, "adzuki bean": 128, "mung bean": 347,
            
            // Grains and cereals
            "barley": 354, "farro": 340, "bulgur": 342, "couscous": 112,
            "polenta": 85, "grits": 71, "millet": 378, "sorghum": 329,
            
            // Seaweed and marine
            "nori": 35, "wakame": 45, "kombu": 43, "dulse": 253,
            
            // Fermented foods
            "tempeh": 192,
            "sauerkraut": 19, "pickle": 11, "olive": 115
        ]
        
        // Enhanced protein detection for better calorie calculation
        let proteinKeywords = [
            "chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna", "cod", "haddock", "tilapia",
            "shrimp", "prawn", "crab", "lobster", "mussel", "oyster", "scallop",
            "egg", "tofu", "tempeh", "seitan", "lentil", "chickpea", "bean", "pea"
        ]
        
        // Check if this is a protein ingredient
        let isProtein = proteinKeywords.contains { keyword in
            ingredientName.contains(keyword)
        }
        
        // Find matching ingredient with priority for proteins
        for (key, caloriesPer100g) in calorieDensities {
            if ingredientName.contains(key) {
                let calculatedCalories = Int((grams * caloriesPer100g) / 100.0)
                
                // If it's a protein, ensure minimum calorie calculation
                if isProtein && calculatedCalories < 50 {
                    return max(calculatedCalories, Int(grams * 1.2)) // Minimum 1.2 cal/g for proteins
                }
                
                return calculatedCalories
            }
        }
        
        // Enhanced default calorie estimate based on ingredient type
        if isProtein {
            return Int(grams * 2.0) // Higher estimate for proteins
        } else if ingredientName.contains("oil") || ingredientName.contains("butter") || ingredientName.contains("fat") {
            return Int(grams * 9.0) // 9 calories per gram for fats
        } else if ingredientName.contains("sugar") || ingredientName.contains("honey") || ingredientName.contains("syrup") {
            return Int(grams * 4.0) // 4 calories per gram for sugars
        } else {
            return Int(grams * 1.5) // Default estimate for other ingredients
        }
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
    
    /// Scale recipe to a different number of servings
    func scaledForServings(_ newServings: Int) -> Recipe {
        let scalingFactor = Double(newServings) / Double(servings)
        
        let scaledIngredients = ingredients.map { ingredient in
            Ingredient(
                id: ingredient.id,
                name: ingredient.name,
                amount: ingredient.amount * scalingFactor,
                unit: ingredient.unit,
                notes: ingredient.notes
            )
        }
        
        return Recipe(
            id: id,
            title: title,
            name: name,
            cuisine: cuisine,
            difficulty: difficulty,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: newServings,
            ingredients: scaledIngredients,
            steps: steps,
            winePairings: winePairings,
            dietaryNotes: dietaryNotes,
            platingTips: platingTips,
            chefNotes: chefNotes,
            imageURL: imageURL,
            stepImages: stepImages,
            createdAt: createdAt,
            isFavorite: isFavorite
        )
    }
} 