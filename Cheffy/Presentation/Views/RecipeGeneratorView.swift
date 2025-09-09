import SwiftUI

struct RecipeGeneratorView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var recipeDatabase = RecipeDatabaseService.shared
    
    // MARK: - State Management
    @State private var selectedCuisine: Cuisine = .any
    @State private var selectedDietaryRestrictions: Set<DietaryNote> = [.nonVegetarian] // Default: Non-Vegetarian to ensure meat recipes
    @State private var selectedMealType: MealType = .regular
    @State private var selectedServings: Int = 4
    @State private var selectedCookingTime: CookingTimeFilter = .any
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var showIngredientAnalysis = false
    @State private var isLoading = false
    @State private var selectedRecipe: Recipe?
    @State private var showingRecipeDetail = false
    
    // MARK: - Haptic Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Computed Properties
    private var shouldDisableInteractions: Bool {
        false
    }
    
    private var filteredRecipes: [Recipe] {
        var recipes = recipeDatabase.recipes
        
        print("🔍 DEBUG: Total recipes in database: \(recipes.count)")
        print("🔍 DEBUG: Selected meal type: \(selectedMealType.rawValue)")
        
        // Debug: Show meal type distribution
        let kidsCount = recipes.filter { $0.mealType == .kids }.count
        let regularCount = recipes.filter { $0.mealType == .regular }.count
        print("🔍 DEBUG: Kids recipes: \(kidsCount), Regular recipes: \(regularCount)")
        
        // STRICT FILTERING: Only show recipes that match the selected meal type exactly
        recipes = recipes.filter { recipe in
            let matches = recipe.mealType == selectedMealType
            if !matches {
                print("🔍 DEBUG: Filtering out recipe '\(recipe.title)' with meal type '\(recipe.mealType.rawValue)'")
            }
            return matches
        }
        
        print("🔍 DEBUG: After STRICT meal type filtering: \(recipes.count) recipes")
        
        // Verify all remaining recipes have the correct meal type
        for recipe in recipes {
            if recipe.mealType != selectedMealType {
                print("❌ ERROR: Recipe '\(recipe.title)' has wrong meal type: \(recipe.mealType.rawValue) (expected: \(selectedMealType.rawValue))")
            }
        }
        
        // Filter by cuisine
        if selectedCuisine != .any {
            recipes = recipes.filter { $0.cuisine == selectedCuisine }
        }
        
        // Filter by dietary restrictions
        if !selectedDietaryRestrictions.isEmpty {
            recipes = recipes.filter { recipe in
                let recipeDietaryNotes = Set(recipe.dietaryNotes.map { $0.rawValue })
                let selectedDietaryNotes = Set(selectedDietaryRestrictions.map { $0.rawValue })
                return selectedDietaryNotes.isSubset(of: recipeDietaryNotes)
            }
        }
        
        // Filter by cooking time
        if selectedCookingTime != .any {
            let maxTime = selectedCookingTime.maxTotalTime
            recipes = recipes.filter { recipe in
                let totalTime = recipe.prepTime + recipe.cookTime
                return totalTime <= maxTime
            }
        }
        
        return recipes
    }
    
    private func initializeUserPreferences() {
        if let user = userManager.currentUser {
            // Convert string cuisine names to Cuisine enum values
            if let firstCuisineString = user.preferredCuisines.first,
               let cuisine = Cuisine.allCases.first(where: { $0.rawValue.lowercased() == firstCuisineString.lowercased() }) {
                selectedCuisine = cuisine
            } else {
                selectedCuisine = .any
            }
            
            // Convert string dietary preferences to DietaryNote enum values
            let dietaryNotes = user.dietaryPreferences.compactMap { dietaryString in
                DietaryNote.allCases.first { $0.rawValue.lowercased() == dietaryString.lowercased() }
            }
            selectedDietaryRestrictions = dietaryNotes.isEmpty ? [.nonVegetarian] : Set(dietaryNotes)
            
            // Default to any cooking time for new users
            selectedCookingTime = .any
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header Section
                headerSection
                
                // Options Section
                optionsSection
                
                // Generate Button
                generateButton
                
                // Results Section
                resultsSection
                
                // Database Recipes Section
                if !filteredRecipes.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(selectedMealType == .kids ? "Kids Recipes" : "Available Recipes")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(filteredRecipes.count) recipes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(filteredRecipes.prefix(6), id: \.id) { recipe in
                                Button(action: {
                                    selectedRecipe = recipe
                                    showingRecipeDetail = true
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(recipe.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        
                                        Text(recipe.cuisine.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text("\(recipe.prepTime + recipe.cookTime) min")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        if filteredRecipes.count > 6 {
                            Button("View All Recipes") {
                                // TODO: Navigate to full recipe list
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 16)
                    .sheet(isPresented: $showingRecipeDetail) {
                        if let recipe = selectedRecipe {
                            RecipeDetailView(recipe: recipe)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshData()
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            print("🚀 DEBUG: RecipeGeneratorView onAppear called")
            initializeUserPreferences()
            Task {
                print("🚀 DEBUG: About to call loadRecipes() from onAppear")
                await loadRecipes()
            }
        }
        .onChange(of: selectedMealType) { _, newValue in
            print("🚀 DEBUG: selectedMealType changed to: \(newValue.rawValue)")
            Task {
                print("🚀 DEBUG: About to call loadRecipes() from onChange")
                await loadRecipes()
            }
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
            Text("Cheffy")
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
    
    // MARK: - Meal Type Section
    
    private var mealTypeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Meal Type", systemImage: "fork.knife")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    Button(action: {
                        print("🚀 DEBUG: Meal type selected: \(mealType.rawValue)")
                        print("🚀 DEBUG: Current selectedMealType: \(selectedMealType.rawValue)")
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMealType = mealType
                            // Update servings based on meal type
                            selectedServings = mealType.defaultServings
                        }
                        print("🚀 DEBUG: After selection, selectedMealType: \(selectedMealType.rawValue)")
                        impactFeedback.impactOccurred()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mealType == .kids ? "child.fill" : "person.fill")
                                .font(.title2)
                                .foregroundColor(selectedMealType == mealType ? .white : .primary)
                            
                            Text(mealType.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedMealType == mealType ? .white : .primary)
                            
                            Text(mealType.description)
                                .font(.caption)
                                .foregroundColor(selectedMealType == mealType ? .white.opacity(0.8) : .secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMealType == mealType ? 
                                      LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                      LinearGradient(colors: [Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMealType == mealType ? Color.blue : Color(.systemGray4), lineWidth: selectedMealType == mealType ? 2 : 1)
                        )
                        .scaleEffect(selectedMealType == mealType ? 1.05 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Servings Section
    
    private var servingsSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Number of Servings", systemImage: "person.2")
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                let servingRange = selectedMealType == .kids ? 1...4 : 2...10
                ForEach(servingRange, id: \.self) { serving in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedServings = serving
                        }
                        impactFeedback.impactOccurred()
                    }) {
                        HStack {
                            Text("\(serving)")
                            if selectedServings == serving {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("\(selectedServings)")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Cooking Time Section
    
    private var cookingTimeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Cooking Time", systemImage: "clock")
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(CookingTimeFilter.allCases, id: \.self) { timeFilter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCookingTime = timeFilter
                        }
                        impactFeedback.impactOccurred()
                    }) {
                        HStack {
                            Text(timeFilter.rawValue)
                            if selectedCookingTime == timeFilter {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedCookingTime.rawValue)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .accessibilityLabel("Cooking time filter dropdown")
            .accessibilityHint("Tap to select maximum cooking time")
        }
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(spacing: 24) {
            // Meal Type Selection
            mealTypeSelection
            
            // Servings Selection
            servingsSelection
            
            // Cooking Time Selection
            cookingTimeSelection
            
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
            generateRecipe()
        }) {
            HStack(spacing: 12) {
                if recipeManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(generateButtonTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        recipeManager.isLoading ? Color.gray : Color.orange
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(recipeManager.isLoading)
        .accessibilityLabel(generateButtonTitle)
        .accessibilityHint("Double tap to generate recipe")
    }
    
    private var generateButtonTitle: String {
        if recipeManager.isLoading {
            return "Generating..."
        } else {
            let mealTypeText = selectedMealType == .kids ? "Kids" : ""
            let cuisineText = selectedCuisine == .any ? "Any Cuisine" : selectedCuisine.rawValue
            return "Generate Popular \(mealTypeText) \(cuisineText) Recipes".trimmingCharacters(in: .whitespaces)
        }
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 16) {
            if let error = recipeManager.error {
                ErrorView(error: error)
            }
            
            if let recipe = recipeManager.generatedRecipe {
                SingleRecipeView(recipe: recipe)
            }
            
            // Show friendly empty state when no recipes match dietary restrictions
            if !selectedDietaryRestrictions.isEmpty && recipeManager.popularRecipes.isEmpty && !recipeManager.isLoading && recipeManager.error == nil {
                emptyStateView
            }
            
            if !recipeManager.popularRecipes.isEmpty {
                let filteredRecipes = filterRecipesByDietaryRestrictions(recipeManager.popularRecipes)
                if !filteredRecipes.isEmpty {
                    PopularRecipesView(recipes: filteredRecipes)
                } else {
                    emptyStateView
                }
                
                // Analysis button
                Button(action: {
                    showIngredientAnalysis = true
                }) {
                    HStack(spacing: 8) {
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
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Friendly illustration
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            VStack(spacing: 12) {
                Text("No Recipes Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("We couldn't find any \(selectedCuisine.rawValue) recipes that match your dietary preferences.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Quick action buttons
            VStack(spacing: 12) {
                Button(action: {
                    selectedCuisine = .any
                    generateRecipe()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                        Text("Try Different Cuisine")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    selectedDietaryRestrictions = [.nonVegetarian]
                    generateRecipe()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf")
                        Text("Relax Dietary Restrictions")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func loadRecipes() async {
        print("🚀 DEBUG: loadRecipes() called in RecipeGeneratorView")
        await MainActor.run {
            isLoading = true
        }
        
        print("🚀 DEBUG: About to call recipeDatabase.loadAllRecipes()")
        print("🚀 DEBUG: Current recipeDatabase.recipes count: \(recipeDatabase.recipes.count)")
        await recipeDatabase.loadAllRecipes()
        print("🚀 DEBUG: recipeDatabase.loadAllRecipes() completed")
        print("🚀 DEBUG: After loadAllRecipes, recipeDatabase.recipes count: \(recipeDatabase.recipes.count)")
        
        // Force a UI update
        await MainActor.run {
            isLoading = false
        }
        
        // Wait a moment for the @Published recipes to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Debug logging
        print("🔍 DEBUG: Recipe loading completed")
        print("🔍 DEBUG: Total recipes loaded: \(recipeDatabase.recipes.count)")
        print("🔍 DEBUG: Filtered recipes count: \(filteredRecipes.count)")
        print("🔍 DEBUG: Selected cuisine: \(selectedCuisine.rawValue)")
        print("🔍 DEBUG: Selected cooking time: \(selectedCookingTime.rawValue)")
        
        // Additional debug: Check if recipes are actually loaded
        if recipeDatabase.recipes.isEmpty {
            print("❌ ERROR: No recipes loaded from database!")
        } else {
            print("✅ SUCCESS: \(recipeDatabase.recipes.count) recipes loaded from database")
            // Show first few recipe meal types
            for (index, recipe) in recipeDatabase.recipes.prefix(5).enumerated() {
                print("🔍 DEBUG: Recipe \(index + 1): '\(recipe.title)' - Meal Type: \(recipe.mealType.rawValue)")
            }
        }
        print("🔍 DEBUG: Selected meal type: \(selectedMealType.rawValue)")
        
        // Debug meal type distribution
        let kidsRecipes = recipeDatabase.recipes.filter { $0.mealType == .kids }
        let regularRecipes = recipeDatabase.recipes.filter { $0.mealType == .regular }
        print("🔍 DEBUG: Kids recipes count: \(kidsRecipes.count)")
        print("🔍 DEBUG: Regular recipes count: \(regularRecipes.count)")
        
        // Debug filtered results
        let filteredKids = filteredRecipes.filter { $0.mealType == .kids }
        let filteredRegular = filteredRecipes.filter { $0.mealType == .regular }
        print("🔍 DEBUG: Filtered kids recipes: \(filteredKids.count)")
        print("🔍 DEBUG: Filtered regular recipes: \(filteredRegular.count)")
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func generateRecipe() {
        guard validateInput() else { return }
        
        impactFeedback.impactOccurred()
        
        // Debug logging for dietary restrictions
        print("🔍 DEBUG: Generating recipes with dietary restrictions: \(selectedDietaryRestrictions.map { $0.rawValue })")
        print("🔍 DEBUG: Selected cuisine: \(selectedCuisine.rawValue)")
        print("🔍 DEBUG: Selected cooking time: \(selectedCookingTime.rawValue)")
        
        Task {
            await recipeManager.generatePopularRecipes(
                cuisine: selectedCuisine,
                difficulty: .medium, // Default to medium difficulty
                dietaryRestrictions: Array(selectedDietaryRestrictions),
                maxTime: selectedCookingTime == .any ? nil : selectedCookingTime.maxTotalTime,
                servings: selectedServings,
                mealType: selectedMealType
            )
        }
    }
    
    private func validateInput() -> Bool {
        let minServings = selectedMealType == .kids ? 1 : 2
        let maxServings = selectedMealType == .kids ? 4 : 10
        
        if selectedServings < minServings || selectedServings > maxServings {
            showValidationError = true
            validationMessage = "Please select a valid number of servings (\(minServings)-\(maxServings))"
            return false
        }
        
        // Validate cooking time constraints for kids meals
        if selectedMealType == .kids && selectedCookingTime != .any && selectedCookingTime.maxTotalTime > 30 {
            showValidationError = true
            validationMessage = "Kids meals must be under 30 minutes for quick preparation"
            return false
        }
        
        // Validate cooking time constraints for regular meals
        if selectedMealType == .regular && selectedCookingTime == .under30min && selectedServings > 6 {
            showValidationError = true
            validationMessage = "Quick recipes (under 30 min) are limited to 6 servings or less for quality"
            return false
        }
        
        return true
    }
    
    private func refreshData() async {
        // Refresh data if needed
    }
    
    // MARK: - Dietary Restriction Filtering
    
    private func filterRecipesByDietaryRestrictions(_ recipes: [Recipe]) -> [Recipe] {
        guard !selectedDietaryRestrictions.isEmpty else {
            return recipes // No restrictions, show all recipes
        }
        
        return recipes.filter { recipe in
            // Check if recipe matches ALL selected dietary restrictions
            for restriction in selectedDietaryRestrictions {
                switch restriction {
                case .vegetarian:
                    // Recipe must NOT contain meat, fish, or eggs
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("chicken") || name.contains("beef") || name.contains("pork") || 
                               name.contains("lamb") || name.contains("fish") || name.contains("shrimp") || 
                               name.contains("egg") || name.contains("meat")
                    }) {
                        return false
                    }
                case .vegan:
                    // Recipe must NOT contain any animal products
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("chicken") || name.contains("beef") || name.contains("pork") || 
                               name.contains("lamb") || name.contains("fish") || name.contains("shrimp") || 
                               name.contains("egg") || name.contains("milk") || name.contains("cheese") || 
                               name.contains("butter") || name.contains("yogurt") || name.contains("honey") ||
                               name.contains("meat")
                    }) {
                        return false
                    }
                case .nonVegetarian:
                    // Recipe must contain meat, fish, or eggs
                    let hasAnimalProduct = recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("chicken") || name.contains("beef") || name.contains("pork") || 
                               name.contains("lamb") || name.contains("fish") || name.contains("shrimp") || 
                               name.contains("egg") || name.contains("meat")
                    })
                    if !hasAnimalProduct {
                        return false
                    }
                case .glutenFree:
                    // Recipe must NOT contain gluten
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("wheat") || name.contains("flour") || name.contains("bread") || 
                               name.contains("pasta") || name.contains("barley") || name.contains("rye")
                    }) {
                        return false
                    }
                case .dairyFree:
                    // Recipe must NOT contain dairy
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("milk") || name.contains("cheese") || name.contains("butter") || 
                               name.contains("yogurt") || name.contains("cream")
                    }) {
                        return false
                    }
                case .nutFree:
                    // Recipe must NOT contain nuts
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("nut") || name.contains("almond") || name.contains("peanut") || 
                               name.contains("cashew") || name.contains("walnut") || name.contains("pecan")
                    }) {
                        return false
                    }
                case .lowCarb:
                    // Recipe must be low in carbohydrates
                    // This is a simplified check - in a real app, you'd check nutritional info
                    return true // For now, allow all recipes
                case .keto:
                    // Recipe must be keto-friendly (very low carb, high fat)
                    // This is a simplified check - in a real app, you'd check nutritional info
                    return true // For now, allow all recipes
                case .paleo:
                    // Recipe must be paleo-friendly (no grains, legumes, dairy)
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("wheat") || name.contains("rice") || name.contains("corn") || 
                               name.contains("bean") || name.contains("lentil") || name.contains("milk") || 
                               name.contains("cheese") || name.contains("yogurt")
                    }) {
                        return false
                    }
                case .halal:
                    // Recipe must be halal (no pork, alcohol)
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("pork") || name.contains("bacon") || name.contains("ham") || 
                               name.contains("alcohol") || name.contains("wine") || name.contains("beer")
                    }) {
                        return false
                    }
                case .kosher:
                    // Recipe must be kosher (no pork, shellfish, mixing meat and dairy)
                    if recipe.ingredients.contains(where: { ingredient in
                        let name = ingredient.name.lowercased()
                        return name.contains("pork") || name.contains("bacon") || name.contains("ham") || 
                               name.contains("shrimp") || name.contains("crab") || name.contains("lobster")
                    }) {
                        return false
                    }
                }
            }
            return true // Recipe passed all dietary restriction checks
        }
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
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            Button(action: {
                // Retry action could be added here
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.05))
        )
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
    @State private var showingKindleReading = false
    
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
        .fullScreenCover(isPresented: $showingKindleReading) {
            InlineKindleReadingView(recipe: recipe)
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
                Text(recipe.title)
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
        VStack(spacing: 12) {
            // First row: View Details and Save buttons
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
            
            // Second row: Kindle Reading Mode button
            Button(action: {
                showingKindleReading = true
            }) {
                HStack {
                    Image(systemName: "book.fill")
                    Text("📚 Kindle Reading Mode")
                    Spacer()
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
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
    @State private var showingKindleReading = false
    
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
                    Text(recipe.title)
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
                        showingKindleReading = true
                    }) {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Open in Kindle reading mode")
                    
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
        .fullScreenCover(isPresented: $showingKindleReading) {
            InlineKindleReadingView(recipe: recipe)
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