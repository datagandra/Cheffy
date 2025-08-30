import Foundation
import SwiftUI

// MARK: - Shopping Cart Item
struct ShoppingCartItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let amount: Double
    let unit: String
    let notes: String?
    let category: IngredientCategory
    var isChecked: Bool
    let addedFromRecipe: String?
    let addedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        unit: String,
        notes: String? = nil,
        category: IngredientCategory = .other,
        isChecked: Bool = false,
        addedFromRecipe: String? = nil,
        addedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.notes = notes
        self.category = category
        self.isChecked = isChecked
        self.addedFromRecipe = addedFromRecipe
        self.addedDate = addedDate
    }
}

// MARK: - Ingredient Categories
enum IngredientCategory: String, CaseIterable, Codable {
    case proteins = "Proteins"
    case vegetables = "Vegetables"
    case fruits = "Fruits"
    case grains = "Grains"
    case dairy = "Dairy"
    case spices = "Spices & Herbs"
    case oils = "Oils & Fats"
    case nuts = "Nuts & Seeds"
    case beverages = "Beverages"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .proteins: return "fish"
        case .vegetables: return "leaf"
        case .fruits: return "applelogo"
        case .grains: return "grain"
        case .dairy: return "drop"
        case .spices: return "sparkles"
        case .oils: return "drop.fill"
        case .nuts: return "circle.fill"
        case .beverages: return "cup.and.saucer"
        case .other: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .proteins: return .red
        case .vegetables: return .green
        case .fruits: return .orange
        case .grains: return .yellow
        case .dairy: return .blue
        case .spices: return .purple
        case .oils: return .brown
        case .nuts: return .mint
        case .beverages: return .cyan
        case .other: return .gray
        }
    }
}

// MARK: - Shopping Cart Service
@MainActor
class ShoppingCartService: ObservableObject {
    @Published var cartItems: [ShoppingCartItem] = []
    @Published var isShowingCart = false
    @Published var selectedCategory: IngredientCategory = .other
    
    private let userDefaults = UserDefaults.standard
    private let cartKey = "ShoppingCartItems"
    
    init() {
        loadCartItems()
    }
    
    // MARK: - Cart Management
    func addRecipeIngredients(_ recipe: Recipe) {
        let recipeName = recipe.title
        
        for ingredient in recipe.ingredients {
            let category = categorizeIngredient(ingredient.name)
            let cartItem = ShoppingCartItem(
                name: ingredient.name,
                amount: ingredient.amount,
                unit: ingredient.unit,
                notes: ingredient.notes,
                category: category,
                addedFromRecipe: recipeName
            )
            
            // Check if item already exists
            if let existingIndex = cartItems.firstIndex(where: { 
                $0.name.lowercased() == ingredient.name.lowercased() && 
                $0.unit.lowercased() == ingredient.unit.lowercased() 
            }) {
                // Update existing item with combined amount
                let existingItem = cartItems[existingIndex]
                let newAmount = existingItem.amount + ingredient.amount
                let updatedItem = ShoppingCartItem(
                    id: existingItem.id,
                    name: existingItem.name,
                    amount: newAmount,
                    unit: existingItem.unit,
                    notes: existingItem.notes,
                    category: existingItem.category,
                    isChecked: existingItem.isChecked,
                    addedFromRecipe: "\(existingItem.addedFromRecipe ?? ""), \(recipeName)",
                    addedDate: existingItem.addedDate
                )
                cartItems[existingIndex] = updatedItem
            } else {
                // Add new item
                cartItems.append(cartItem)
            }
        }
        
        saveCartItems()
    }
    
    func removeItem(_ item: ShoppingCartItem) {
        cartItems.removeAll { $0.id == item.id }
        saveCartItems()
    }
    
    func toggleItemChecked(_ item: ShoppingCartItem) {
        if let index = cartItems.firstIndex(where: { $0.id == item.id }) {
            cartItems[index].isChecked.toggle()
            saveCartItems()
        }
    }
    
    func clearCart() {
        cartItems.removeAll()
        saveCartItems()
    }
    
    func addItem(_ item: ShoppingCartItem) {
        cartItems.append(item)
        saveCartItems()
    }
    
    func clearCheckedItems() {
        cartItems.removeAll { $0.isChecked }
        saveCartItems()
    }
    
    // MARK: - Computed Properties
    var checkedItems: Int {
        cartItems.filter { $0.isChecked }.count
    }
    
    var totalItems: Int {
        cartItems.count
    }
    
    var sortedCategories: [IngredientCategory] {
        Array(Set(cartItems.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }
    
    var itemsByCategory: [IngredientCategory: [ShoppingCartItem]] {
        Dictionary(grouping: cartItems, by: { $0.category })
    }
    
    // MARK: - Persistence
    func saveCartItems() {
        if let encoded = try? JSONEncoder().encode(cartItems) {
            userDefaults.set(encoded, forKey: cartKey)
        }
    }
    
    // MARK: - Categorization
    private func categorizeIngredient(_ ingredientName: String) -> IngredientCategory {
        let name = ingredientName.lowercased()
        
        // Proteins
        let proteins = ["chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna", "shrimp", "eggs", "tofu", "tempeh", "lentils", "chickpeas", "beans", "meat", "turkey", "duck", "bacon", "ham", "sausage", "steak", "ground beef", "mince"]
        if proteins.contains(where: { name.contains($0) }) {
            return .proteins
        }
        
        // Vegetables
        let vegetables = ["onion", "garlic", "tomato", "potato", "carrot", "bell pepper", "spinach", "kale", "broccoli", "cauliflower", "mushroom", "zucchini", "eggplant", "cucumber", "lettuce", "cabbage", "celery", "pepper", "chili", "ginger", "leek", "shallot", "scallion", "green onion", "asparagus", "artichoke", "brussels sprout", "cabbage", "carrot", "cauliflower", "celery", "cucumber", "eggplant", "garlic", "ginger", "kale", "leek", "lettuce", "mushroom", "onion", "pepper", "potato", "spinach", "tomato", "zucchini"]
        if vegetables.contains(where: { name.contains($0) }) {
            return .vegetables
        }
        
        // Fruits
        let fruits = ["apple", "banana", "orange", "lemon", "lime", "mango", "strawberry", "blueberry", "raspberry", "grape", "pineapple", "peach", "pear", "plum", "cherry", "apricot", "fig", "date", "raisin", "cranberry", "pomegranate", "kiwi", "avocado", "coconut"]
        if fruits.contains(where: { name.contains($0) }) {
            return .fruits
        }
        
        // Grains
        let grains = ["rice", "pasta", "bread", "flour", "quinoa", "oats", "wheat", "barley", "corn", "millet", "sorghum", "rye", "buckwheat", "couscous", "bulgur", "farro", "spelt", "amaranth", "teff"]
        if grains.contains(where: { name.contains($0) }) {
            return .grains
        }
        
        // Dairy
        let dairy = ["milk", "cheese", "yogurt", "cream", "butter", "sour cream", "heavy cream", "half and half", "whipping cream", "cottage cheese", "ricotta", "mozzarella", "cheddar", "parmesan", "feta", "goat cheese", "blue cheese", "gouda", "brie", "camembert"]
        if dairy.contains(where: { name.contains($0) }) {
            return .dairy
        }
        
        // Spices & Herbs
        let spices = ["salt", "pepper", "cumin", "coriander", "turmeric", "ginger", "cinnamon", "paprika", "oregano", "basil", "parsley", "cilantro", "mint", "thyme", "rosemary", "sage", "bay leaf", "cardamom", "clove", "nutmeg", "allspice", "chili powder", "cayenne", "garam masala", "curry powder", "saffron", "vanilla", "dill", "tarragon", "marjoram", "chives", "scallion", "green onion"]
        if spices.contains(where: { name.contains($0) }) {
            return .spices
        }
        
        // Oils & Fats
        let oils = ["olive oil", "vegetable oil", "coconut oil", "sesame oil", "canola oil", "sunflower oil", "ghee", "lard", "shortening", "margarine", "avocado oil", "grapeseed oil", "walnut oil", "almond oil"]
        if oils.contains(where: { name.contains($0) }) {
            return .oils
        }
        
        // Nuts & Seeds
        let nuts = ["almond", "walnut", "cashew", "peanut", "sesame", "pistachio", "pecan", "hazelnut", "macadamia", "pine nut", "sunflower seed", "pumpkin seed", "chia seed", "flax seed", "hemp seed", "poppy seed"]
        if nuts.contains(where: { name.contains($0) }) {
            return .nuts
        }
        
        // Beverages
        let beverages = ["wine", "beer", "juice", "tea", "coffee", "water", "soda", "milk", "cream", "broth", "stock", "soup", "sauce", "vinegar", "soy sauce", "worcestershire sauce", "hot sauce", "ketchup", "mustard", "mayonnaise"]
        if beverages.contains(where: { name.contains($0) }) {
            return .beverages
        }
        
        return .other
    }
    

    
    private func loadCartItems() {
        if let data = userDefaults.data(forKey: cartKey),
           let decoded = try? JSONDecoder().decode([ShoppingCartItem].self, from: data) {
            cartItems = decoded
        }
    }
    

} 