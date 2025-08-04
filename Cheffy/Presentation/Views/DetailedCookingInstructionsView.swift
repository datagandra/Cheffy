import SwiftUI

struct DetailedCookingInstructionsView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var showingIngredients = true
    @State private var showingWinePairings = false
    @State private var showingChefNotes = false
    @State private var showingPlatingTips = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Recipe Header
                    recipeHeader
                    
                    // Ingredients Section
                    ingredientsSection
                    
                    // Cooking Instructions Section
                    cookingInstructionsSection
                    
                    // Chef Notes Section
                    if !recipe.chefNotes.isEmpty {
                        chefNotesSection
                    }
                    
                    // Wine Pairings Section
                    if !recipe.winePairings.isEmpty {
                        winePairingsSection
                    }
                    
                    // Plating Tips Section
                    if !recipe.platingTips.isEmpty {
                        platingTipsSection
                    }
                    
                    // Start Cooking Mode Button
                    startCookingModeButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cooking Instructions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Recipe Header
    private var recipeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and badges
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    BadgeView(text: recipe.cuisine.rawValue, color: .orange)
                    BadgeView(text: recipe.difficulty.rawValue, color: .blue)
                }
            }
            
            // Time and servings info
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.caloriesPerServing)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 4) {
                    Text("Prep Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.prepTime) min")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 4) {
                    Text("Cook Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.cookTime) min")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 4) {
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.prepTime + recipe.cookTime) min")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 4) {
                    Text("Servings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.servings)")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Ingredients")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(recipe.ingredients.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(recipe.ingredients) { ingredient in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(ingredient.amount, specifier: "%.1f") \(ingredient.unit)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                
                                Text(ingredient.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
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
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Cooking Instructions Section
    private var cookingInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "number.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Cooking Instructions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(recipe.steps.count) steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                ForEach(recipe.steps) { step in
                    VStack(alignment: .leading, spacing: 12) {
                        // Step header
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                
                                Text("\(step.stepNumber)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Step \(step.stepNumber)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                if let duration = step.duration {
                                    Text("\(duration) minutes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Step description
                        Text(step.description)
                            .font(.body)
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                        
                        // Step details
                        VStack(alignment: .leading, spacing: 8) {
                            if let temperature = step.temperature {
                                HStack {
                                    Image(systemName: "thermometer")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text("Temperature: \(Int(temperature))°C")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let tips = step.tips, !tips.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Chef's Tip")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        
                                        Text(tips)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                                .padding(12)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Chef Notes Section
    private var chefNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Chef's Notes")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(recipe.chefNotes)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Wine Pairings Section
    private var winePairingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wineglass")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("Wine Pairings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(recipe.winePairings) { wine in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(wine.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            BadgeView(text: wine.type.rawValue, color: .purple)
                        }
                        
                        Text(wine.region)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(wine.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Plating Tips Section
    private var platingTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("Plating Tips")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(recipe.platingTips)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Start Cooking Mode Button
    private var startCookingModeButton: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: CookingModeView(recipe: recipe)) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Start Interactive Cooking Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange, Color.red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    let sampleRecipe = Recipe(
        name: "Coq au Vin",
        cuisine: .french,
        difficulty: .medium,
        prepTime: 30,
        cookTime: 90,
        servings: 4,
        ingredients: [
            Ingredient(name: "Chicken thighs", amount: 4, unit: "pieces"),
            Ingredient(name: "Red wine", amount: 750, unit: "ml"),
            Ingredient(name: "Bacon", amount: 200, unit: "g")
        ],
        steps: [
            CookingStep(stepNumber: 1, description: "Marinate the chicken in red wine with aromatics for at least 4 hours or overnight.", duration: 240),
            CookingStep(stepNumber: 2, description: "Brown the bacon in a large Dutch oven over medium heat until crispy.", duration: 10),
            CookingStep(stepNumber: 3, description: "Remove bacon and brown the chicken pieces in the rendered fat until golden brown on all sides.", duration: 15)
        ],
        platingTips: "Serve in a deep bowl with the sauce generously spooned over the chicken. Garnish with fresh parsley and serve with crusty bread.",
        chefNotes: "This classic French dish requires patience and attention to detail. The key is to develop deep flavors through proper browning and slow cooking."
    )
    
    DetailedCookingInstructionsView(recipe: sampleRecipe)
} 