import SwiftUI

struct RecipeLandingPageView: View {
    let recipe: Recipe
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    @Environment(\.dismiss) private var dismiss
    @State private var showingIngredients = true
    @State private var showingWinePairings = false
    @State private var showingChefNotes = false
    @State private var showingCookingMode = false
    @State private var showingNutritionDetails = false
    @State private var showingIngredientDetails = false
    @State private var selectedIngredient: Ingredient?
    @State private var showingRecipeTips = false
    @State private var showingSubstitutions = false
    @State private var showingEquipment = false
    @State private var showingKindleReading = false
    @State private var showingShoppingCart = false
    @State private var showingImageGeneration = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Recipe Header with Hero Image
                    recipeHeroSection
                    
                    // Quick Info Cards
                    quickInfoSection
                    
                    // Ingredients Section
                    ingredientsSection
                    
                    // Cooking Steps Section
                    cookingStepsSection
                    
                    // Wine Pairings (if available)
                    if !recipe.winePairings.isEmpty {
                        winePairingsSection
                    }
                    
                    // Chef Notes (if available)
                    if !recipe.chefNotes.isEmpty {
                        chefNotesSection
                    }
                    
                    // Plating Tips (if available)
                    if !recipe.platingTips.isEmpty {
                        platingTipsSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        recipeManager.toggleFavorite(recipe)
                    }) {
                        Image(systemName: recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "heart.fill" : "heart")
                            .foregroundColor(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? .red : .gray)
                    }
                    .accessibilityLabel(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "Remove from favorites" : "Add to favorites")
                }
            }
        }
        .sheet(isPresented: $showingCookingMode) {
            CookingModeView(recipe: recipe)
        }
        .fullScreenCover(isPresented: $showingKindleReading) {
            InlineKindleReadingView(recipe: recipe)
        }
        .sheet(isPresented: $showingShoppingCart) {
            InlineShoppingCartView()
        }
        .sheet(isPresented: $showingEquipment) {
            EquipmentView(recipe: recipe)
        }
        .sheet(isPresented: $showingImageGeneration) {
            ImageGenerationView(recipe: recipe)
        }
    }
    
    // MARK: - Recipe Hero Section
    private var recipeHeroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Recipe Image Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                
                VStack {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Recipe Image")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Recipe Title and Badges
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                
                HStack(spacing: 8) {
                    BadgeView(text: recipe.cuisine.rawValue, color: Color.orange)
                    BadgeView(text: recipe.difficulty.rawValue, color: Color.blue)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Quick Info Section
    private var quickInfoSection: some View {
        VStack(spacing: 16) {
            // Time breakdown
            HStack(spacing: 0) {
                TimeCard(title: "Prep", time: recipe.formattedPrepTime, icon: "clock")
                Divider()
                    .frame(height: 40)
                TimeCard(title: "Cook", time: recipe.formattedCookTime, icon: "flame")
                Divider()
                    .frame(height: 40)
                TimeCard(title: "Total", time: recipe.formattedTotalTime, icon: "timer", isHighlighted: true)
            }
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Interactive Nutrition and Servings Info
            VStack(spacing: 12) {
                // Servings and Calories info
                HStack(spacing: 16) {
                    Button(action: {
                        showingNutritionDetails = true
                    }) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(recipe.caloriesPerServing) cal/serving")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.green)
                        Text("\(recipe.servings) servings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Additional interactive info
                HStack(spacing: 16) {
                    Button(action: {
                        showingRecipeTips = true
                    }) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Cooking Tips")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingSubstitutions = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("Substitutions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingNutritionDetails) {
            NutritionDetailsView(recipe: recipe)
        }
        .sheet(isPresented: $showingRecipeTips) {
            RecipeTipsView(recipe: recipe)
        }
        .sheet(isPresented: $showingSubstitutions) {
            SubstitutionsView(recipe: recipe)
        }
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Ingredients",
                icon: "list.bullet",
                color: Color.orange,
                isExpanded: $showingIngredients
            )
            
            if showingIngredients {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recipe.ingredients) { ingredient in
                        Button(action: {
                            selectedIngredient = ingredient
                            showingIngredientDetails = true
                        }) {
                            IngredientRow(ingredient: ingredient)
                                .overlay(
                                    HStack {
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingIngredientDetails) {
            if let ingredient = selectedIngredient {
                IngredientDetailsView(ingredient: ingredient)
            }
        }
    }
    
    // MARK: - Cooking Steps Section
    private var cookingStepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Cooking Steps",
                icon: "list.number",
                color: Color.blue,
                isExpanded: .constant(true)
            )
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(recipe.steps) { step in
                    CookingStepRow(step: step)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Wine Pairings Section
    private var winePairingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Wine Pairings",
                icon: "wineglass",
                color: Color.purple,
                isExpanded: $showingWinePairings
            )
            
            if showingWinePairings {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recipe.winePairings) { wine in
                        WinePairingRow(wine: wine)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Chef Notes Section
    private var chefNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Chef's Notes",
                icon: "person.circle",
                color: Color.green,
                isExpanded: $showingChefNotes
            )
            
            if showingChefNotes {
                Text(recipe.chefNotes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Plating Tips Section
    private var platingTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.pink)
                    .font(.title2)
                Text("Plating Tips")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(recipe.platingTips)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Start Cooking Button
            Button(action: {
                showingCookingMode = true
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    Text("Start Cooking")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange)
                )
                .foregroundColor(.white)
            }
            
            // Interactive Action Buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: {
                        recipeManager.toggleFavorite(recipe)
                    }) {
                        HStack {
                            Image(systemName: recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "heart.fill" : "heart")
                                .font(.title3)
                            Text(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "Saved" : "Save to Favorites")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                        )
                        .foregroundColor(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? .red : .primary)
                    }
                    
                    Button(action: {
                        shareRecipe()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("Share")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue)
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        showingEquipment = true
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.title3)
                            Text("Equipment")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                        .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        shoppingCartService.addRecipeIngredients(recipe)
                        showingShoppingCart = true
                    }) {
                        HStack {
                            Image(systemName: "cart.badge.plus")
                                .font(.title3)
                            Text("Shopping List")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.1))
                        )
                        .foregroundColor(.purple)
                    }
                }
                
                // Kindle Reading Mode button (full width)
                Button(action: {
                    showingKindleReading = true
                }) {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.title3)
                        Text("📚 Kindle Reading Mode")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .padding(.horizontal, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // AI Image Generation button (full width)
                Button(action: {
                    showingImageGeneration = true
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        Text("🎨 Generate AI Image")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .padding(.horizontal, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Generate AI image for this recipe")
                .accessibilityHint("Tap to create an AI-generated image based on the recipe")
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingEquipment) {
            EquipmentView(recipe: recipe)
        }
    }
    
    // MARK: - Helper Methods
    private func shareRecipe() {
        let recipeText = """
        \(recipe.title)
        
        Cuisine: \(recipe.cuisine.rawValue)
        Difficulty: \(recipe.difficulty.rawValue)
        Prep Time: \(recipe.formattedPrepTime)
        Cook Time: \(recipe.formattedCookTime)
        Servings: \(recipe.servings)
        
        Ingredients:
        \(recipe.ingredients.map { "• \($0.amount) \($0.unit) \($0.name)" }.joined(separator: "\n"))
        
        Instructions:
        \(recipe.steps.enumerated().map { "\($0 + 1). \($1.description)" }.joined(separator: "\n"))
        
        Generated by Cheffy AI
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [recipeText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Views

struct CookingStepRow: View {
    let step: CookingStep
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.stepNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                
                if let duration = step.duration {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let temperature = step.temperature {
                    HStack {
                        Image(systemName: "thermometer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(temperature))°C")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let tips = step.tips {
                    Text(tips)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Detail Views

struct NutritionDetailsView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Nutrition Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nutrition Information")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            NutritionRow(title: "Calories", value: "\(recipe.caloriesPerServing) per serving", icon: "flame.fill", color: .orange)
                            NutritionRow(title: "Total Time", value: recipe.formattedTotalTime, icon: "clock.fill", color: .blue)
                            NutritionRow(title: "Servings", value: "\(recipe.servings) people", icon: "person.2.fill", color: .green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Detailed Nutrition Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nutritional Breakdown")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            NutritionBreakdownRow(nutrient: "Protein", percentage: 25, color: .blue)
                            NutritionBreakdownRow(nutrient: "Carbohydrates", percentage: 45, color: .green)
                            NutritionBreakdownRow(nutrient: "Fat", percentage: 30, color: .orange)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Dietary Information
                    if !recipe.dietaryNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dietary Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(recipe.dietaryNotes, id: \.self) { note in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text(note.rawValue)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Nutrition Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecipeTipsView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Chef's Tips
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.orange)
                            Text("Chef's Pro Tips")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Text(recipe.chefNotes.isEmpty ? "Follow the recipe steps carefully and don't rush the cooking process. Quality ingredients make a big difference in the final result." : recipe.chefNotes)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Cooking Tips
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Cooking Tips")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(tip: "Prep all ingredients before starting to cook")
                            TipRow(tip: "Use fresh ingredients for best results")
                            TipRow(tip: "Don't overcrowd the pan when cooking")
                            TipRow(tip: "Taste and adjust seasoning as you go")
                        }
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Plating Tips
                    if !recipe.platingTips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.pink)
                                Text("Plating Tips")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            Text(recipe.platingTips)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        .padding()
                        .background(Color.pink.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Cooking Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SubstitutionsView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Common Substitutions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("Ingredient Substitutions")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            SubstitutionRow(original: "Butter", substitute: "Olive oil or coconut oil")
                            SubstitutionRow(original: "Milk", substitute: "Almond milk or soy milk")
                            SubstitutionRow(original: "Eggs", substitute: "Flax seeds or chia seeds")
                            SubstitutionRow(original: "Sugar", substitute: "Honey or maple syrup")
                            SubstitutionRow(original: "All-purpose flour", substitute: "Gluten-free flour blend")
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Dietary Substitutions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Dietary Adaptations")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DietaryAdaptationRow(diet: "Vegetarian", adaptation: "Replace meat with tofu or tempeh")
                            DietaryAdaptationRow(diet: "Vegan", adaptation: "Use plant-based alternatives")
                            DietaryAdaptationRow(diet: "Gluten-Free", adaptation: "Use certified gluten-free ingredients")
                            DietaryAdaptationRow(diet: "Dairy-Free", adaptation: "Use nut milks and dairy-free cheese")
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Substitutions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct IngredientDetailsView: View {
    let ingredient: Ingredient
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Ingredient Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundColor(.green)
                            Text(ingredient.name.capitalized)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("\(ingredient.amount, specifier: "%.1f") \(ingredient.unit)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let notes = ingredient.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .italic()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Ingredient Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About this ingredient")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            IngredientInfoRow(title: "Storage", info: "Store in a cool, dry place")
                            IngredientInfoRow(title: "Shelf Life", info: "Check package for expiration date")
                            IngredientInfoRow(title: "Best Quality", info: "Look for fresh, unblemished items")
                            IngredientInfoRow(title: "Preparation", info: "Wash thoroughly before use")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // Substitution Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Substitution Options")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            SubstitutionOptionRow(option: "Fresh \(ingredient.name)")
                            SubstitutionOptionRow(option: "Frozen \(ingredient.name)")
                            SubstitutionOptionRow(option: "Dried \(ingredient.name)")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Ingredient Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct NutritionRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct NutritionBreakdownRow: View {
    let nutrient: String
    let percentage: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(nutrient)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(percentage)%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(percentage) / 100, height: 4)
            }
            .frame(height: 4)
        }
    }
}

struct TipRow: View {
    let tip: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(tip)
                .font(.subheadline)
                .lineLimit(nil)
        }
    }
}

struct SubstitutionRow: View {
    let original: String
    let substitute: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right")
                .foregroundColor(.blue)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(original)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(substitute)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DietaryAdaptationRow: View {
    let diet: String
    let adaptation: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(diet)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(adaptation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct IngredientInfoRow: View {
    let title: String
    let info: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(info)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SubstitutionOptionRow: View {
    let option: String
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(option)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct EquipmentView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Essential Equipment
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.green)
                            Text("Essential Equipment")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            EquipmentRow(equipment: "Chef's Knife", description: "For chopping and slicing")
                            EquipmentRow(equipment: "Cutting Board", description: "For safe food preparation")
                            EquipmentRow(equipment: "Large Pot", description: "For boiling pasta and soups")
                            EquipmentRow(equipment: "Skillet/Pan", description: "For sautéing and frying")
                            EquipmentRow(equipment: "Measuring Cups", description: "For accurate ingredient measurement")
                            EquipmentRow(equipment: "Wooden Spoon", description: "For stirring and mixing")
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Optional Equipment
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Optional Equipment")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            EquipmentRow(equipment: "Food Processor", description: "For chopping and pureeing")
                            EquipmentRow(equipment: "Blender", description: "For smoothies and sauces")
                            EquipmentRow(equipment: "Stand Mixer", description: "For baking and mixing")
                            EquipmentRow(equipment: "Slow Cooker", description: "For slow-cooked meals")
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Safety Equipment
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.red)
                            Text("Safety Equipment")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            EquipmentRow(equipment: "Oven Mitts", description: "For handling hot dishes")
                            EquipmentRow(equipment: "Fire Extinguisher", description: "Kitchen safety essential")
                            EquipmentRow(equipment: "First Aid Kit", description: "For minor kitchen accidents")
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Kitchen Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EquipmentRow: View {
    let equipment: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(equipment)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    RecipeLandingPageView(recipe: Recipe(
        title: "Sample Recipe",
        cuisine: .italian,
        difficulty: .medium,
        prepTime: 15,
        cookTime: 30,
        servings: 4,
        ingredients: [
            Ingredient(name: "Pasta", amount: 500, unit: "g"),
            Ingredient(name: "Tomato Sauce", amount: 400, unit: "ml")
        ],
        steps: [
            CookingStep(stepNumber: 1, description: "Boil water and cook pasta", duration: 10),
            CookingStep(stepNumber: 2, description: "Heat sauce and combine", duration: 5)
        ]
    ))
    .environmentObject(RecipeManager())
}

// Shopping cart views are now in ShoppingCartViews.swift
// MARK: - Inline Shopping Cart Item Row
 