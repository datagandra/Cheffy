import SwiftUI

// MARK: - BadgeView
struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// MARK: - TimeCard
struct TimeCard: View {
    let title: String
    let time: String
    let icon: String
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isHighlighted ? .blue : .secondary)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(time)
                    .font(.subheadline)
                    .fontWeight(isHighlighted ? .bold : .medium)
                    .foregroundColor(isHighlighted ? .blue : .primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SectionHeader
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: { 
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - IngredientRow
struct IngredientRow: View {
    let ingredient: Ingredient
    
    private var ingredientCategory: IngredientCategory {
        categorizeIngredient(ingredient.name)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Category icon
                Image(systemName: ingredientCategory.icon)
                    .foregroundColor(ingredientCategory.color)
                    .font(.caption)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(ingredientCategory.color.opacity(0.2))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(formatAmount(ingredient.amount)) \(ingredient.unit)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ingredientCategory.color)
                        
                        Text(ingredient.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        // Category badge
                        Text(ingredientCategory.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ingredientCategory.color.opacity(0.2))
                            )
                            .foregroundColor(ingredientCategory.color)
                    }
                    
                    if let notes = ingredient.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.1f", amount)
        }
    }
    
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
}

#Preview {
    VStack(spacing: 20) {
        BadgeView(text: "French", color: .orange)
        BadgeView(text: "Medium", color: .blue)
        TimeCard(title: "Prep", time: "30m", icon: "clock", isHighlighted: true)
        TimeCard(title: "Cook", time: "45m", icon: "timer")
    }
    .padding()
} 