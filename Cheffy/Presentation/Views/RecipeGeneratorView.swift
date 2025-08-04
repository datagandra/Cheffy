import SwiftUI

struct RecipeGeneratorView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var userManager: UserManager
    
    // MARK: - State Management
    @State private var selectedCuisine: Cuisine = .french
    @State private var selectedDietaryRestrictions: Set<DietaryNote> = []
    @State private var userPrompt: String = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var showIngredientAnalysis = false
    @FocusState private var isPromptFieldFocused: Bool
    
    // MARK: - Haptic Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Computed Properties
    private var shouldDisableInteractions: Bool {
        isPromptFieldFocused
    }
    
    private func initializeUserPreferences() {
        if let user = userManager.currentUser {
            selectedCuisine = user.favoriteCuisines.first ?? .italian
            selectedDietaryRestrictions = Set(user.dietaryPreferences)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header Section
                headerSection
                
                // Input Section
                inputSection
                
                // Options Section
                optionsSection
                
                // Generate Button
                generateButton
                
                // Cache Status Display
                cacheStatusDisplay
                
                // Cache Test Button (for debugging)
                cacheTestButton
                
                // Results Section
                resultsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Recipe Generator")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshData()
        }
        .accessibilityElement(children: .contain)
        .onTapGesture {
            // Dismiss keyboard when tapping outside text field
            isPromptFieldFocused = false
        }
        .onAppear {
            initializeUserPreferences()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Logo
            appLogo
            
            // Welcome Text
            welcomeText
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cheffy AI Recipe Generator")
    }
    
    private var appLogo: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
            
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.white)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Cheffy App Logo")
    }
    
    private var welcomeText: some View {
        VStack(spacing: 8) {
            Text("CHEFFY")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("AI Recipe Generator")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                )
        }
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Input Label
            Label("Recipe Description", systemImage: "text.bubble")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Text Field
            TextField("", text: $userPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isPromptFieldFocused)
                .lineLimit(3...6)
                .placeholder(when: userPrompt.isEmpty) {
                    Text("Enter recipe name or description (Leave empty for popular \(selectedCuisine.rawValue) recipes)")
                        .foregroundColor(.secondary)
                        .font(.body)
                }
                .onChange(of: userPrompt) { _, newValue in
                    if showValidationError {
                        showValidationError = false
                        validationMessage = ""
                    }
                }
                .onTapGesture {
                    // Ensure focus stays on text field when tapped
                    isPromptFieldFocused = true
                }
                .accessibilityLabel("Recipe name input field")
                                    .accessibilityHint("Enter your recipe name or description, or leave empty for popular recipes")
            
            // Character Count and Hints
            inputHints
        }
    }
    
    private var inputHints: some View {
        HStack {
            // Character Count
            Text("\(userPrompt.count)/200")
                .font(.caption)
                .foregroundColor(userPrompt.count > 180 ? .orange : .secondary)
                .accessibilityLabel("Character count: \(userPrompt.count) out of 200")
            
            Spacer()
            
            // Dynamic Hints
            if userPrompt.isEmpty {
                Label("Leave empty for popular \(selectedCuisine.rawValue) recipes", systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Hint: Leave empty for popular \(selectedCuisine.rawValue) recipes")
            } else if userPrompt.count < 10 {
                Label("Please provide more details", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .accessibilityLabel("Warning: Please provide more details")
            }
        }
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(spacing: 24) {
            // Cuisine Selection
            cuisineSelection
            
            // Dietary Restrictions
            dietaryRestrictions
        }
    }
    
    private var cuisineSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cuisine", systemImage: "globe")
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(Cuisine.allCases, id: \.self) { cuisine in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCuisine = cuisine
                        }
                        impactFeedback.impactOccurred()
                    }) {
                        HStack {
                            Text(cuisine.rawValue.capitalized)
                            if selectedCuisine == cuisine {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedCuisine.rawValue.capitalized)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .onTapGesture {
                // Ensure text field loses focus when cuisine menu is tapped
                isPromptFieldFocused = false
            }
            .accessibilityLabel("Cuisine selection dropdown")
            .accessibilityHint("Tap to select cuisine type")
        }
    }
    

    
    private var dietaryRestrictions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dietary Restrictions", systemImage: "leaf")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DietaryNote.allCases, id: \.self) { restriction in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedDietaryRestrictions.contains(restriction) {
                                    selectedDietaryRestrictions.remove(restriction)
                                } else {
                                    selectedDietaryRestrictions.insert(restriction)
                                }
                            }
                            impactFeedback.impactOccurred()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: selectedDietaryRestrictions.contains(restriction) ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                    .foregroundColor(selectedDietaryRestrictions.contains(restriction) ? .blue : .secondary)
                                
                                Text(restriction.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedDietaryRestrictions.contains(restriction) ? .blue : .primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedDietaryRestrictions.contains(restriction) ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedDietaryRestrictions.contains(restriction) ? Color.blue : Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .onTapGesture {
                            // Ensure text field loses focus when dietary restriction is tapped
                            isPromptFieldFocused = false
                        }
                        .accessibilityLabel("\(restriction.rawValue) dietary restriction")
                        .accessibilityAddTraits(selectedDietaryRestrictions.contains(restriction) ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button(action: {
            // Ensure text field loses focus when generate button is tapped
            isPromptFieldFocused = false
            generateRecipe()
        }) {
            HStack {
                if recipeManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.headline)
                }
                
                Text(generateButtonTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        recipeManager.isLoading ? Color.gray : Color.orange
                    )
            )
            .foregroundColor(.white)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(recipeManager.isLoading)
        .accessibilityLabel(generateButtonTitle)
        .accessibilityHint("Double tap to generate recipe")
    }
    
    private var generateButtonTitle: String {
        if recipeManager.isLoading {
            return "Generating..."
        } else if userPrompt.isEmpty {
            return "Generate Popular \(selectedCuisine.rawValue) Recipes"
        } else {
            return "Generate Recipe"
        }
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 16) {
            // Cache Status Indicator
            if recipeManager.isUsingCachedData {
                cacheStatusIndicator
            }
            
            if let error = recipeManager.error {
                ErrorView(error: error)
            }
            
            if let recipe = recipeManager.generatedRecipe {
                SingleRecipeView(recipe: recipe)
            }
            
                    if !recipeManager.popularRecipes.isEmpty {
            PopularRecipesView(recipes: recipeManager.popularRecipes)
                
                // Analysis button
                Button(action: {
                    showIngredientAnalysis = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.headline)
                        Text("Show Ingredient Analysis")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showIngredientAnalysis) {
            IngredientAnalysisView(recipeManager: recipeManager)
        }
    }
    
    // MARK: - Cache Status Indicator
    
    private var cacheStatusIndicator: some View {
        HStack {
            Image(systemName: "externaldrive.fill")
                .foregroundColor(.green)
            Text("Using cached data")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Cache Test Button
    
    private var cacheTestButton: some View {
        Button(action: {
            print("🧪 Testing cache functionality...")
            print("📊 Current cache stats:")
            print("   - Cached recipes: \(recipeManager.getCachedRecipesCount())")
            print("   - Has cached recipes: \(recipeManager.hasCachedRecipes())")
            
            if recipeManager.hasCachedRecipes() {
                recipeManager.loadAllCachedRecipes()
                print("✅ Loaded cached recipes successfully")
            } else {
                print("❌ No cached recipes available")
            }
        }) {
            HStack {
                Image(systemName: "externaldrive.arrow.down")
                Text("Test Cache (\(recipeManager.getCachedRecipesCount()) recipes)")
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Cache Status Display
    
    private var cacheStatusDisplay: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.green)
                Text("Cache Status")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(recipeManager.getCachedRecipesCount()) recipes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if recipeManager.isUsingCachedData {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Using cached data")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.orange)
                    Text("Connecting to LLM")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Show dietary restrictions change notice
            if !recipeManager.isUsingCachedData && !selectedDietaryRestrictions.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Fresh recipe for dietary restrictions")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func generateRecipe() {
        guard validateInput() else { return }
        
        isPromptFieldFocused = false
        impactFeedback.impactOccurred()
        
        Task {
            if userPrompt.isEmpty {
                await recipeManager.generatePopularRecipes(
                    cuisine: selectedCuisine,
                    difficulty: .medium, // Default to medium difficulty
                    dietaryRestrictions: Array(selectedDietaryRestrictions)
                )
            } else {
                await recipeManager.generateRecipe(
                    userPrompt: userPrompt,
                    recipeName: userPrompt.isEmpty ? nil : userPrompt,
                    cuisine: selectedCuisine,
                    difficulty: .medium, // Default to medium difficulty
                    dietaryRestrictions: Array(selectedDietaryRestrictions)
                )
            }
        }
    }
    
    private func validateInput() -> Bool {
        if !userPrompt.isEmpty && userPrompt.count < 10 {
            showValidationError = true
            validationMessage = "Please provide more details for your recipe"
            return false
        }
        return true
    }
    
    private func refreshData() async {
        // Refresh data if needed
    }
}

// MARK: - Supporting Views

struct CuisineButton: View {
    let cuisine: Cuisine
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(cuisine.rawValue.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.orange : Color.gray.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(cuisine.rawValue.capitalized) cuisine")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DifficultyButton: View {
    let difficulty: Difficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(difficulty.rawValue.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(difficulty.rawValue.capitalized) difficulty")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct IngredientAnalysisView: View {
    let recipeManager: RecipeManager
    @Environment(\.dismiss) private var dismiss
    @State private var analysisText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(analysisText)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            }
            .navigationTitle("Ingredient Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareAnalysis()
                    }
                }
            }
        }
        .onAppear {
            analysisText = recipeManager.getCompleteRecipeAnalysis()
        }
    }
    
    private func shareAnalysis() {
        let activityVC = UIActivityViewController(
            activityItems: [analysisText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct DietaryRestrictionButton: View {
    let restriction: DietaryNote
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.subheadline)
                
                Text(restriction.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(restriction.rawValue.capitalized) dietary restriction")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ErrorView: View {
    let error: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error)")
    }
}

struct SingleRecipeView: View {
    let recipe: Recipe
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var showingIngredients = true
    @State private var showingWinePairings = false
    @State private var showingChefNotes = false
    @State private var showingLandingPage = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Recipe Preview Card
            recipePreviewCard
            
            // Quick Action Buttons
            quickActionButtons
        }
        .sheet(isPresented: $showingLandingPage) {
            RecipeLandingPageView(recipe: recipe)
        }
    }
    
    // MARK: - Recipe Preview Card
    private var recipePreviewCard: some View {
        Button(action: {
            showingLandingPage = true
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Recipe Header
                recipeHeader
                
                // Quick Info
                quickInfoSection
                
                // Preview of first few ingredients
                ingredientsPreview
                
                // View Full Recipe Button
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.orange)
                    Text("View Full Recipe")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Recipe Header
    private var recipeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recipe.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Spacer()
                
                Button(action: {
                    recipeManager.toggleFavorite(recipe)
                }) {
                    Image(systemName: recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? .red : .gray)
                }
                .accessibilityLabel(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "Remove from favorites" : "Add to favorites")
            }
            
            HStack(spacing: 8) {
                BadgeView(text: recipe.cuisine.rawValue, color: Color.orange)
                BadgeView(text: recipe.difficulty.rawValue, color: Color.blue)
                Spacer()
            }
        }
    }
    
    // MARK: - Quick Info Section
    private var quickInfoSection: some View {
        HStack(spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text(recipe.formattedTotalTime)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                Text("\(recipe.servings) servings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(recipe.caloriesPerServing) cal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Ingredients Preview
    private var ingredientsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.orange)
                Text("Ingredients")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(recipe.ingredients.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Show first 3 ingredients
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(recipe.ingredients.prefix(3)), id: \.id) { ingredient in
                    HStack {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(ingredient.amount, specifier: "%.0f") \(ingredient.unit) \(ingredient.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                if recipe.ingredients.count > 3 {
                    Text("+ \(recipe.ingredients.count - 3) more ingredients")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .italic()
                }
            }
        }
    }
    
    // MARK: - Quick Action Buttons
    private var quickActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingLandingPage = true
            }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("View Details")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Button(action: {
                recipeManager.toggleFavorite(recipe)
            }) {
                HStack {
                    Image(systemName: recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "heart.fill" : "heart")
                    Text(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "Saved" : "Save")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? .red : .primary)
                .cornerRadius(12)
            }
        }
    }
    

    

}

struct PopularRecipesView: View {
    let recipes: [Recipe]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Popular Recipes")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                PopularRecipeRow(index: index, recipe: recipe)
                }
            }
        }
    }
}

struct PopularRecipeRow: View {
    let index: Int
    let recipe: Recipe
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var showingLandingPage = false
    
    var body: some View {
        Button(action: {
            showingLandingPage = true
        }) {
            HStack {
                Text("\(index + 1)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(recipe.cuisine.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(recipe.difficulty.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    // Quick info
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(recipe.formattedTotalTime)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(recipe.servings)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flame")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(recipe.caloriesPerServing) cal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: {
                        recipeManager.toggleFavorite(recipe)
                    }) {
                        Image(systemName: recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "heart.fill" : "heart")
                            .foregroundColor(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? .red : .gray)
                    }
                    .accessibilityLabel(recipeManager.favorites.contains(where: { $0.id == recipe.id }) ? "Remove from favorites" : "Add to favorites")
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingLandingPage) {
            RecipeLandingPageView(recipe: recipe)
        }
    }
}

// MARK: - Custom Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    NavigationStack {
        RecipeGeneratorView()
            .environmentObject(RecipeManager())
            .environmentObject(SubscriptionManager())
    }
} 