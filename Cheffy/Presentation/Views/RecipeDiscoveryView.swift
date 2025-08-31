import SwiftUI

struct RecipeDiscoveryView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var recipeDatabase = RecipeDatabaseService.shared
    
    // MARK: - State Management
    @State private var selectedCuisine: Cuisine = .italian
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var selectedDietaryRestrictions: Set<DietaryNote> = []
    @State private var selectedCookingTime: CookingTimeFilter = .any
    @State private var selectedProtein: String = ""
    @State private var searchQuery: String = ""
    @State private var showingFilters = false
    @State private var isLoading = false
    @State private var selectedRecipe: Recipe?
    @State private var showingRecipeDetail = false
    @State private var showingLLMGeneration = false
    @State private var llmGeneratedRecipes: [Recipe] = []
    
    // MARK: - Computed Properties
    private var filteredRecipes: [Recipe] {
        var recipes = recipeDatabase.recipes
        
        // Filter by cuisine
        if selectedCuisine != .any {
            recipes = recipes.filter { $0.cuisine == selectedCuisine }
        }
        
        // Filter by difficulty
        recipes = recipes.filter { $0.difficulty == selectedDifficulty }
        
        // Filter by dietary restrictions
        if !selectedDietaryRestrictions.isEmpty {
            recipes = recipeDatabase.getRecipes(for: Array(selectedDietaryRestrictions))
        }
        
        // Filter by cooking time
        if selectedCookingTime != .any {
            let maxTime = selectedCookingTime.maxTotalTime
            recipes = recipes.filter { recipe in
                (recipe.prepTime + recipe.cookTime) <= maxTime
            }
        }
        
        // Filter by protein
        if !selectedProtein.isEmpty {
            recipes = recipeDatabase.getRecipes(by: selectedProtein)
        }
        
        // Filter by search query
        if !searchQuery.isEmpty {
            recipes = recipeDatabase.searchRecipes(query: searchQuery)
        }
        
        return recipes
    }
    
    private var availableProteins: [String] {
        recipeDatabase.getAvailableProteins()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Header
                searchAndFilterHeader
                
                // Cache Status Indicator
                if !isLoading && (!filteredRecipes.isEmpty || !llmGeneratedRecipes.isEmpty) {
                    cacheStatusIndicator
                }
                
                // Recipe Grid
                if isLoading {
                    loadingView
                } else if filteredRecipes.isEmpty && llmGeneratedRecipes.isEmpty {
                    emptyStateView
                } else {
                    recipeGridView
                }
            }
            .navigationTitle("Discover Recipes")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadRecipes()
            }
            .onAppear {
                initializeUserPreferences()
                Task {
                    await loadRecipes()
                }
            }
        }
    }
    
    // MARK: - Search and Filter Header
    private var searchAndFilterHeader: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search recipes...", text: $searchQuery)
                    .textFieldStyle(.plain)
                
                if !searchQuery.isEmpty {
                    Button("Clear") {
                        searchQuery = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Cuisine Filter
                    FilterChip(
                        title: selectedCuisine.rawValue,
                        isSelected: true,
                        action: { showingFilters = true }
                    )
                    
                    // Difficulty Filter
                    FilterChip(
                        title: selectedDifficulty.rawValue,
                        isSelected: true,
                        action: { showingFilters = true }
                    )
                    
                    // Cooking Time Filter
                    if selectedCookingTime != .any {
                        FilterChip(
                            title: selectedCookingTime.rawValue,
                            isSelected: true,
                            action: { showingFilters = true }
                        )
                    }
                    
                    // Dietary Restrictions
                    ForEach(Array(selectedDietaryRestrictions), id: \.self) { restriction in
                        FilterChip(
                            title: restriction.rawValue,
                            isSelected: true,
                            action: { selectedDietaryRestrictions.remove(restriction) }
                        )
                    }
                    
                    // Protein Filter
                    if !selectedProtein.isEmpty {
                        FilterChip(
                            title: selectedProtein,
                            isSelected: true,
                            action: { selectedProtein = "" }
                        )
                    }
                    
                    // Clear All Button
                    if !selectedDietaryRestrictions.isEmpty || !selectedProtein.isEmpty || selectedCookingTime != .any {
                        Button("Clear All") {
                            selectedDietaryRestrictions.removeAll()
                            selectedProtein = ""
                            selectedCookingTime = .any
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingFilters) {
            RecipeFilterView(
                selectedCuisine: $selectedCuisine,
                selectedDifficulty: $selectedDifficulty,
                selectedDietaryRestrictions: $selectedDietaryRestrictions,
                selectedCookingTime: $selectedCookingTime,
                selectedProtein: $selectedProtein,
                availableProteins: availableProteins
            )
        }
        .sheet(isPresented: $showingRecipeDetail) {
            if let recipe = selectedRecipe {
                RecipeLandingPageView(recipe: recipe)
            }
        }
        .alert("Generate New Recipes?", isPresented: $showingLLMGeneration) {
            Button("Generate") {
                Task {
                    await generateRecipesFromLLM()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("No local recipes match your current filters. Would you like to generate new recipes using AI?")
        }
    }
    
    // MARK: - Recipe Grid View
    private var recipeGridView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                // Show local recipes first
                ForEach(filteredRecipes) { recipe in
                    RecipeCard(recipe: recipe)
                        .onTapGesture {
                            selectedRecipe = recipe
                            showingRecipeDetail = true
                        }
                }
                
                // Show LLM generated recipes if any
                ForEach(llmGeneratedRecipes) { recipe in
                    RecipeCard(recipe: recipe)
                        .overlay(
                            VStack {
                                HStack {
                                    Spacer()
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.white.opacity(0.9))
                                        .clipShape(Circle())
                                }
                                Spacer()
                            }
                            .padding(4)
                        )
                        .onTapGesture {
                            selectedRecipe = recipe
                            showingRecipeDetail = true
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading recipes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No recipes found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your filters or generate new recipes using AI")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Generate AI Recipes") {
                showingLLMGeneration = true
            }
            .buttonStyle(.borderedProminent)
            
            Button("Clear Filters") {
                selectedCuisine = .italian
                selectedDifficulty = .medium
                selectedDietaryRestrictions.removeAll()
                selectedCookingTime = .any
                selectedProtein = ""
                searchQuery = ""
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Cache Status Indicator
    private var cacheStatusIndicator: some View {
        HStack {
            if recipeManager.isUsingCachedData {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Using cached recipes")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("\(filteredRecipes.count + llmGeneratedRecipes.count) recipes available offline")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task {
                            await generateRecipesFromLLM()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fresh AI-generated recipes")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Recipes saved to cache for offline use")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(filteredRecipes.count + llmGeneratedRecipes.count) recipes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helper Methods
    private func initializeUserPreferences() {
        if let user = userManager.currentUser {
            // Convert string cuisine names to Cuisine enum values
            if let firstCuisineString = user.preferredCuisines.first,
               let cuisine = Cuisine.allCases.first(where: { $0.rawValue.lowercased() == firstCuisineString.lowercased() }) {
                selectedCuisine = cuisine
            } else {
                selectedCuisine = .italian
            }
            
            // Convert string dietary preferences to DietaryNote enum values
            let dietaryNotes = user.dietaryPreferences.compactMap { dietaryString in
                DietaryNote.allCases.first { $0.rawValue.lowercased() == dietaryString.lowercased() }
            }
            selectedDietaryRestrictions = Set(dietaryNotes)
        }
    }
    
    private func loadRecipes() async {
        await MainActor.run {
            isLoading = true
        }
        
        await recipeDatabase.loadAllRecipes()
        
        // Check if we need to generate recipes from LLM
        if filteredRecipes.isEmpty {
            await MainActor.run {
                showingLLMGeneration = true
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func generateRecipesFromLLM() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Convert cooking time filter to max time
        let maxTime: Int? = selectedCookingTime == .any ? nil : selectedCookingTime.maxTotalTime
        
        // Generate recipes using LLM with strict filtering
        await recipeManager.generatePopularRecipes(
            cuisine: selectedCuisine,
            difficulty: selectedDifficulty,
            dietaryRestrictions: Array(selectedDietaryRestrictions),
            maxTime: maxTime,
            servings: 4
        )
        
        // Get the generated recipes
        let generatedRecipes = recipeManager.popularRecipes
        
        await MainActor.run {
            self.llmGeneratedRecipes = generatedRecipes
            self.isLoading = false
            
            if !generatedRecipes.isEmpty {
                // Show success message
                // You can add a toast or alert here
            }
        }
    }
}

// MARK: - Recipe Card
struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe Image
            AsyncImage(url: recipe.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            .frame(height: 120)
            .clipped()
            .cornerRadius(8)
            
            // Recipe Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack {
                    Label("\(recipe.prepTime + recipe.cookTime) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(recipe.difficulty.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.orange : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Recipe Filter View
struct RecipeFilterView: View {
    @Binding var selectedCuisine: Cuisine
    @Binding var selectedDifficulty: Difficulty
    @Binding var selectedDietaryRestrictions: Set<DietaryNote>
    @Binding var selectedCookingTime: CookingTimeFilter
    @Binding var selectedProtein: String
    let availableProteins: [String]
    
    @Environment(\.dismiss) private var dismiss
    @State private var validationMessage: String = ""
    @State private var showingValidationAlert = false
    @State private var autoAddedRestrictions: Set<DietaryNote> = []
    
    var body: some View {
        NavigationStack {
            Form {
                // Cuisine Selection
                Section("Cuisine") {
                    ForEach(Cuisine.allCases, id: \.self) { cuisine in
                        HStack {
                            Text(cuisine.rawValue)
                            Spacer()
                            if selectedCuisine == cuisine {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCuisine = cuisine
                        }
                    }
                }
                
                // Difficulty Selection
                Section("Difficulty") {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        HStack {
                            Text(difficulty.rawValue)
                            Spacer()
                            if selectedDifficulty == difficulty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDifficulty = difficulty
                        }
                    }
                }
                
                // Cooking Time Selection
                Section("Cooking Time") {
                    ForEach(CookingTimeFilter.allCases, id: \.self) { timeFilter in
                        HStack {
                            Text(timeFilter.rawValue)
                            Spacer()
                            if selectedCookingTime == timeFilter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCookingTime = timeFilter
                        }
                    }
                }
                
                // Dietary Restrictions
                Section("Dietary Restrictions") {
                    // Validation Message
                    if !validationMessage.isEmpty {
                        HStack {
                            Image(systemName: validationMessage.contains("cannot") ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .foregroundColor(validationMessage.contains("cannot") ? .red : .blue)
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundColor(validationMessage.contains("cannot") ? .red : .blue)
                        }
                    }
                    
                    // Auto-added restrictions info
                    if !autoAddedRestrictions.isEmpty {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Auto-added: \(autoAddedRestrictions.map { $0.rawValue }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ForEach(DietaryNote.allCases, id: \.self) { restriction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(restriction.rawValue)
                                
                                // Show restriction description
                                Text(getRestrictionDescription(restriction))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedDietaryRestrictions.contains(restriction) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleDietaryRestriction(restriction)
                        }
                    }
                }
                
                // Protein Selection
                Section("Protein") {
                    HStack {
                        Text("Any Protein")
                        Spacer()
                        if selectedProtein.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundColor(.orange)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedProtein = ""
                    }
                    
                    ForEach(availableProteins, id: \.self) { protein in
                        HStack {
                            Text(protein.capitalized)
                            Spacer()
                            if selectedProtein == protein {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProtein = protein
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedDietaryRestrictions) { _, newValue in
                validateDietaryRestrictions(newValue)
            }
            .alert("Dietary Restriction Conflict", isPresented: $showingValidationAlert) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func toggleDietaryRestriction(_ restriction: DietaryNote) {
        if selectedDietaryRestrictions.contains(restriction) {
            selectedDietaryRestrictions.remove(restriction)
        } else {
            selectedDietaryRestrictions.insert(restriction)
        }
    }
    
    private func validateDietaryRestrictions(_ restrictions: Set<DietaryNote>) {
        var conflicts: [String] = []
        
        // Check for mutual exclusivity conflicts
        if restrictions.contains(.vegetarian) && restrictions.contains(.nonVegetarian) {
            conflicts.append("Vegetarian and Non-Vegetarian cannot be selected together")
        }
        if restrictions.contains(.vegan) && restrictions.contains(.nonVegetarian) {
            conflicts.append("Vegan and Non-Vegetarian cannot be selected together")
        }
        
        if !conflicts.isEmpty {
            validationMessage = conflicts.joined(separator: "\n")
            showingValidationAlert = true
            
            // Remove conflicting restrictions
            if restrictions.contains(.vegetarian) && restrictions.contains(.nonVegetarian) {
                selectedDietaryRestrictions.remove(.vegetarian)
                selectedDietaryRestrictions.remove(.nonVegetarian)
            } else if restrictions.contains(.vegan) && restrictions.contains(.nonVegetarian) {
                selectedDietaryRestrictions.remove(.vegan)
                selectedDietaryRestrictions.remove(.nonVegetarian)
            }
        } else {
            validationMessage = ""
            autoAddedRestrictions.removeAll()
        }
    }
    
    private func getRestrictionDescription(_ restriction: DietaryNote) -> String {
        switch restriction {
        case .nonVegetarian:
            return "Includes meat, fish, eggs"
        case .vegetarian:
            return "No meat or fish, may include dairy/eggs"
        case .vegan:
            return "No animal products"
        case .glutenFree:
            return "No wheat, barley, rye"
        case .dairyFree:
            return "No milk, cheese, butter"
        case .nutFree:
            return "No nuts or nut products"
        case .lowCarb:
            return "Limited carbohydrates"
        case .keto:
            return "Very low carb, high fat"
        case .paleo:
            return "No grains, legumes, dairy"
        case .halal:
            return "No pork or alcohol"
        case .kosher:
            return "No pork or shellfish"
        }
    }
}

#Preview {
    RecipeDiscoveryView()
        .environmentObject(RecipeManager())
        .environmentObject(UserManager())
} 