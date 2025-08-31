import Foundation
import os.log

// MARK: - Dietary Restriction Manager
class DietaryRestrictionManager: ObservableObject {
    static let shared = DietaryRestrictionManager()
    
    private let logger = os.Logger(subsystem: "com.cheffy.app", category: "DietaryRestrictionManager")
    
    // MARK: - Dietary Restriction Groups
    enum DietaryGroup: String, CaseIterable {
        case protein = "Protein"
        case dairy = "Dairy"
        case grains = "Grains"
        case allergens = "Allergens"
        case lifestyle = "Lifestyle"
    }
    
    // MARK: - Mutual Exclusivity Rules
    private let mutuallyExclusiveRestrictions: [Set<DietaryNote>] = [
        [.vegetarian, .nonVegetarian],
        [.vegan, .nonVegetarian],
        [.vegan, .dairyFree], // Vegan implies dairy-free
        [.vegetarian, .nonVegetarian],
        [.keto, .lowCarb], // Keto is a subset of low-carb
        [.paleo, .glutenFree] // Paleo implies gluten-free
    ]
    
    // MARK: - Required Restrictions (when one is selected, others are automatically added)
    private let requiredRestrictions: [DietaryNote: Set<DietaryNote>] = [
        .vegan: [.vegetarian, .dairyFree],
        .paleo: [.glutenFree, .dairyFree],
        .keto: [.lowCarb]
    ]
    
    // MARK: - Validation Methods
    func validateDietaryRestrictions(_ restrictions: Set<DietaryNote>) -> (isValid: Bool, conflicts: [String], autoAdded: Set<DietaryNote>) {
        var autoAdded: Set<DietaryNote> = []
        var conflicts: [String] = []
        
        // Check for mutual exclusivity conflicts
        for exclusiveSet in mutuallyExclusiveRestrictions {
            let intersection = restrictions.intersection(exclusiveSet)
            if intersection.count > 1 {
                let restrictionNames = intersection.map { $0.rawValue }.joined(separator: " and ")
                conflicts.append("\(restrictionNames) cannot be selected together")
            }
        }
        
        // Auto-add required restrictions
        for restriction in restrictions {
            if let required = requiredRestrictions[restriction] {
                autoAdded.formUnion(required)
            }
        }
        
        let isValid = conflicts.isEmpty
        return (isValid, conflicts, autoAdded)
    }
    
    func getValidatedRestrictions(_ restrictions: Set<DietaryNote>) -> Set<DietaryNote> {
        var validated = restrictions
        
        // Auto-add required restrictions
        for restriction in restrictions {
            if let required = requiredRestrictions[restriction] {
                validated.formUnion(required)
            }
        }
        
        return validated
    }
    
    // MARK: - Recipe Validation
    func validateRecipeCompliance(_ recipe: Recipe, against restrictions: Set<DietaryNote>) -> (isCompliant: Bool, violations: [String]) {
        guard !restrictions.isEmpty else { return (true, []) }
        
        var violations: [String] = []
        let allIngredients = recipe.ingredients.map { $0.name.lowercased() }
        let recipeName = recipe.name.lowercased()
        
        logger.debug("Validating recipe '\(recipe.name)' against restrictions: \(restrictions.map { $0.rawValue })")
        
        for restriction in restrictions {
            let (isCompliant, violationReason) = validateSingleRestriction(
                recipeName: recipeName,
                ingredients: allIngredients,
                restriction: restriction
            )
            
            if !isCompliant {
                violations.append("\(restriction.rawValue): \(violationReason)")
            }
        }
        
        let isCompliant = violations.isEmpty
        logger.debug("Recipe validation result: \(isCompliant ? "PASS" : "FAIL")")
        if !isCompliant {
            logger.warning("Recipe '\(recipe.name)' violates restrictions: \(violations)")
        }
        
        return (isCompliant, violations)
    }
    
    private func validateSingleRestriction(recipeName: String, ingredients: [String], restriction: DietaryNote) -> (isCompliant: Bool, violationReason: String) {
        switch restriction {
        case .nonVegetarian:
            if !containsMeatIngredients(ingredients) && !containsEggIngredients(ingredients) && !containsFishIngredients(ingredients) {
                return (false, "Recipe contains no meat, eggs, or fish")
            }
            return (true, "")
            
        case .vegetarian:
            if containsMeatIngredients(ingredients) || containsFishIngredients(ingredients) {
                return (false, "Recipe contains meat or fish")
            }
            return (true, "")
            
        case .vegan:
            if containsMeatIngredients(ingredients) || containsFishIngredients(ingredients) || containsDairyIngredients(ingredients) || containsEggIngredients(ingredients) {
                return (false, "Recipe contains animal products")
            }
            return (true, "")
            
        case .glutenFree:
            if containsGlutenIngredients(ingredients) {
                return (false, "Recipe contains gluten")
            }
            return (true, "")
            
        case .dairyFree:
            if containsDairyIngredients(ingredients) {
                return (false, "Recipe contains dairy")
            }
            return (true, "")
            
        case .nutFree:
            if containsNutIngredients(ingredients) {
                return (false, "Recipe contains nuts")
            }
            return (true, "")
            
        case .lowCarb:
            if containsHighCarbIngredients(ingredients) {
                return (false, "Recipe contains high-carb ingredients")
            }
            return (true, "")
            
        case .keto:
            if containsHighCarbIngredients(ingredients) || containsSugarIngredients(ingredients) {
                return (false, "Recipe contains carbs or sugar")
            }
            return (true, "")
            
        case .paleo:
            if containsGrainsIngredients(ingredients) || containsLegumesIngredients(ingredients) || containsDairyIngredients(ingredients) {
                return (false, "Recipe contains grains, legumes, or dairy")
            }
            return (true, "")
            
        case .halal:
            if containsPorkIngredients(ingredients) || containsAlcoholIngredients(ingredients) {
                return (false, "Recipe contains pork or alcohol")
            }
            return (true, "")
            
        case .kosher:
            if containsPorkIngredients(ingredients) || containsShellfishIngredients(ingredients) {
                return (false, "Recipe contains pork or shellfish")
            }
            return (true, "")
        }
    }
    
    // MARK: - Ingredient Detection Methods
    private func containsMeatIngredients(_ ingredients: [String]) -> Bool {
        let meatKeywords = [
            // Poultry
            "chicken", "turkey", "duck", "goose", "quail", "pheasant", "partridge", "guinea fowl", "poussin",
            "chicken breast", "chicken thigh", "chicken wing", "chicken leg", "chicken drumstick",
            "turkey breast", "turkey leg", "turkey wing", "duck breast", "duck leg", "duck wing",
            
            // Red Meat
            "beef", "steak", "burger", "ground beef", "beef chuck", "beef brisket", "beef tenderloin",
            "pork", "pork chop", "pork loin", "pork shoulder", "pork belly", "bacon", "ham", "sausage",
            "lamb", "lamb chop", "lamb shoulder", "lamb leg", "lamb rack",
            "veal", "venison", "bison", "elk", "rabbit", "goat",
            
            // Processed Meats
            "salami", "pepperoni", "prosciutto", "mortadella", "pastrami", "corned beef",
            "hot dog", "frankfurter", "bratwurst", "chorizo", "andouille", "kielbasa"
        ]
        
        return ingredients.contains { ingredient in
            meatKeywords.contains { meatKeyword in
                ingredient.contains(meatKeyword)
            }
        }
    }
    
    private func containsFishIngredients(_ ingredients: [String]) -> Bool {
        let fishKeywords = [
            "fish", "salmon", "tuna", "cod", "haddock", "tilapia", "mackerel", "sardines", "anchovies",
            "trout", "bass", "perch", "snapper", "grouper", "halibut", "flounder", "sole",
            "shrimp", "prawn", "crab", "lobster", "mussel", "oyster", "clam", "scallop",
            "caviar", "roe", "seaweed", "nori"
        ]
        
        return ingredients.contains { ingredient in
            fishKeywords.contains { fishKeyword in
                ingredient.contains(fishKeyword)
            }
        }
    }
    
    private func containsDairyIngredients(_ ingredients: [String]) -> Bool {
        let dairyKeywords = [
            "milk", "cream", "half and half", "heavy cream", "light cream", "whipping cream",
            "butter", "ghee", "margarine",
            "cheese", "cheddar", "mozzarella", "parmesan", "feta", "goat cheese", "blue cheese",
            "yogurt", "greek yogurt", "sour cream", "buttermilk", "kefir",
            "ice cream", "gelato", "custard", "pudding",
            "whey", "casein", "lactose"
        ]
        
        return ingredients.contains { ingredient in
            dairyKeywords.contains { dairyKeyword in
                ingredient.contains(dairyKeyword)
            }
        }
    }
    
    private func containsEggIngredients(_ ingredients: [String]) -> Bool {
        let eggKeywords = [
            "egg", "eggs", "egg white", "egg yolk", "egg whites", "egg yolks",
            "albumen", "ovalbumin", "ovoglobulin"
        ]
        
        return ingredients.contains { ingredient in
            eggKeywords.contains { eggKeyword in
                ingredient.contains(eggKeyword)
            }
        }
    }
    
    private func containsGlutenIngredients(_ ingredients: [String]) -> Bool {
        let glutenKeywords = [
            "wheat", "barley", "rye", "spelt", "kamut", "triticale",
            "flour", "all-purpose flour", "bread flour", "cake flour", "pastry flour",
            "bread", "toast", "sandwich", "roll", "bun", "bagel", "croissant",
            "pasta", "spaghetti", "penne", "rigatoni", "fettuccine", "lasagna",
            "cake", "cookie", "biscuit", "muffin", "donut", "pastry",
            "couscous", "bulgur", "farro", "semolina", "durum"
        ]
        
        return ingredients.contains { ingredient in
            glutenKeywords.contains { glutenKeyword in
                ingredient.contains(glutenKeyword)
            }
        }
    }
    
    private func containsNutIngredients(_ ingredients: [String]) -> Bool {
        let nutKeywords = [
            "almond", "walnut", "pecan", "cashew", "pistachio", "hazelnut", "macadamia",
            "peanut", "peanuts", "pine nut", "pine nuts", "brazil nut", "brazil nuts",
            "chestnut", "chestnuts", "filbert", "filberts",
            "nut butter", "almond butter", "peanut butter", "cashew butter"
        ]
        
        return ingredients.contains { ingredient in
            nutKeywords.contains { nutKeyword in
                ingredient.contains(nutKeyword)
            }
        }
    }
    
    private func containsHighCarbIngredients(_ ingredients: [String]) -> Bool {
        let highCarbKeywords = [
            "rice", "white rice", "brown rice", "basmati rice", "jasmine rice",
            "pasta", "spaghetti", "penne", "rigatoni", "fettuccine",
            "bread", "toast", "sandwich", "roll", "bun",
            "potato", "potatoes", "sweet potato", "sweet potatoes",
            "corn", "cornmeal", "polenta", "grits",
            "quinoa", "oats", "oatmeal", "barley", "farro"
        ]
        
        return ingredients.contains { ingredient in
            highCarbKeywords.contains { carbKeyword in
                ingredient.contains(carbKeyword)
            }
        }
    }
    
    private func containsSugarIngredients(_ ingredients: [String]) -> Bool {
        let sugarKeywords = [
            "sugar", "white sugar", "brown sugar", "powdered sugar", "confectioners sugar",
            "honey", "maple syrup", "agave", "molasses", "corn syrup",
            "fructose", "glucose", "sucrose", "dextrose", "maltose",
            "chocolate", "cocoa", "caramel", "toffee", "fudge"
        ]
        
        return ingredients.contains { ingredient in
            sugarKeywords.contains { sugarKeyword in
                ingredient.contains(sugarKeyword)
            }
        }
    }
    
    private func containsGrainsIngredients(_ ingredients: [String]) -> Bool {
        let grainsKeywords = [
            "wheat", "barley", "rye", "oats", "rice", "corn", "quinoa", "millet", "sorghum",
            "flour", "bread", "pasta", "cereal", "grain"
        ]
        
        return ingredients.contains { ingredient in
            grainsKeywords.contains { grainKeyword in
                ingredient.contains(grainKeyword)
            }
        }
    }
    
    private func containsLegumesIngredients(_ ingredients: [String]) -> Bool {
        let legumesKeywords = [
            "bean", "beans", "kidney bean", "black bean", "pinto bean", "navy bean",
            "lentil", "lentils", "chickpea", "chickpeas", "garbanzo", "garbanzos",
            "pea", "peas", "green pea", "split pea", "split peas",
            "soybean", "soybeans", "tofu", "tempeh", "edamame"
        ]
        
        return ingredients.contains { ingredient in
            legumesKeywords.contains { legumeKeyword in
                ingredient.contains(legumeKeyword)
            }
        }
    }
    
    private func containsPorkIngredients(_ ingredients: [String]) -> Bool {
        let porkKeywords = [
            "pork", "pork chop", "pork loin", "pork shoulder", "pork belly",
            "bacon", "ham", "sausage", "salami", "pepperoni", "prosciutto",
            "mortadella", "pancetta", "guanciale", "lard", "pork fat"
        ]
        
        return ingredients.contains { ingredient in
            porkKeywords.contains { porkKeyword in
                ingredient.contains(porkKeyword)
            }
        }
    }
    
    private func containsAlcoholIngredients(_ ingredients: [String]) -> Bool {
        let alcoholKeywords = [
            "wine", "red wine", "white wine", "sherry", "port", "vermouth",
            "beer", "ale", "lager", "stout", "porter",
            "vodka", "rum", "whiskey", "whisky", "bourbon", "scotch", "gin", "tequila",
            "brandy", "cognac", "liqueur", "amaretto", "kahlua", "baileys"
        ]
        
        return ingredients.contains { ingredient in
            alcoholKeywords.contains { alcoholKeyword in
                ingredient.contains(alcoholKeyword)
            }
        }
    }
    
    private func containsShellfishIngredients(_ ingredients: [String]) -> Bool {
        let shellfishKeywords = [
            "shrimp", "prawn", "crab", "lobster", "crayfish", "crawfish",
            "mussel", "oyster", "clam", "scallop", "abalone", "conch",
            "squid", "octopus", "cuttlefish", "snail", "escargot"
        ]
        
        return ingredients.contains { ingredient in
            shellfishKeywords.contains { shellfishKeyword in
                ingredient.contains(shellfishKeyword)
            }
        }
    }
}
