import SwiftUI

struct RecipeDiscoveryView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var userManager: UserManager
    @StateObject private var recipeDatabase = RecipeDatabaseService.shared
    
    // MARK: - State Management
    @State private var selectedCuisine: Cuisine = .italian
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var selectedDietaryRestrictions: Set<DietaryNote> = []
    @State private var selectedProtein: String = ""
    @State private var searchQuery: String = ""
    @State private var showingFilters = false
    @State private var isLoading = false
    @State private var selectedRecipe: Recipe?
    @State private var showingRecipeDetail = false
    
    // MARK: - Computed Properties
    private var filteredRecipes: [Recipe] {
        var recipes = recipeDatabase.recipes
        
        // Filter by cuisine
        if selectedCuisine != .other {
            recipes = recipes.filter { $0.cuisine == selectedCuisine }
        }
        
        // Filter by difficulty
        recipes = recipes.filter { $0.difficulty == selectedDifficulty }
        
        // Filter by dietary restrictions
        if !selectedDietaryRestrictions.isEmpty {
            recipes = recipeDatabase.getRecipes(for: Array(selectedDietaryRestrictions))
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
                
                // Recipe Grid
                if isLoading {
                    loadingView
                } else if filteredRecipes.isEmpty {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
                    if !selectedDietaryRestrictions.isEmpty || !selectedProtein.isEmpty {
                        Button("Clear All") {
                            selectedDietaryRestrictions.removeAll()
                            selectedProtein = ""
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
                selectedProtein: $selectedProtein,
                availableProteins: availableProteins
            )
        }
        .sheet(isPresented: $showingRecipeDetail) {
            if let recipe = selectedRecipe {
                RecipeLandingPageView(recipe: recipe)
            }
        }
    }
    
    // MARK: - Recipe Grid View
    private var recipeGridView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(filteredRecipes) { recipe in
                    RecipeCard(recipe: recipe)
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
            
            Text("Try adjusting your filters or search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Clear Filters") {
                selectedCuisine = .italian
                selectedDifficulty = .medium
                selectedDietaryRestrictions.removeAll()
                selectedProtein = ""
                searchQuery = ""
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    private func initializeUserPreferences() {
        if let user = userManager.currentUser {
            selectedCuisine = user.favoriteCuisines.first ?? .italian
            selectedDietaryRestrictions = Set(user.dietaryPreferences)
        }
    }
    
    private func loadRecipes() async {
        await MainActor.run {
            isLoading = true
        }
        
        await recipeDatabase.loadAllRecipes()
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Recipe Card
struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recipe Image Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                
                VStack {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Recipe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Recipe Info
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack {
                    BadgeView(text: recipe.cuisine.rawValue, color: .orange)
                    BadgeView(text: recipe.difficulty.rawValue, color: .blue)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.prepTime + recipe.cookTime) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.servings)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
    @Binding var selectedProtein: String
    let availableProteins: [String]
    
    @Environment(\.dismiss) private var dismiss
    
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
                
                // Dietary Restrictions
                Section("Dietary Restrictions") {
                    ForEach(DietaryNote.allCases, id: \.self) { restriction in
                        HStack {
                            Text(restriction.rawValue)
                            Spacer()
                            if selectedDietaryRestrictions.contains(restriction) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedDietaryRestrictions.contains(restriction) {
                                selectedDietaryRestrictions.remove(restriction)
                            } else {
                                selectedDietaryRestrictions.insert(restriction)
                            }
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
        }
    }
}

#Preview {
    RecipeDiscoveryView()
        .environmentObject(RecipeManager())
        .environmentObject(UserManager())
} 