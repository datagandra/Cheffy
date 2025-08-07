import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var recipeToDelete: Recipe?
    @State private var isSelectionMode = false
    @State private var selectedRecipes: Set<UUID> = []
    @State private var showingBulkDeleteAlert = false
    
    private var filteredFavorites: [Recipe] {
        if searchText.isEmpty {
            return recipeManager.favorites
        } else {
            return recipeManager.favorites.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.cuisine.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        Group {
            if recipeManager.favorites.isEmpty {
                emptyStateView
            } else {
                favoritesListView
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search favorites")
        .refreshable {
            // Refresh favorites if needed
        }
        .toolbar {
            if !recipeManager.favorites.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        if isSelectionMode {
                            // Exit selection mode
                            isSelectionMode = false
                            selectedRecipes.removeAll()
                        } else {
                            // Enter selection mode
                            isSelectionMode = true
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                if isSelectionMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Select All") {
                            selectedRecipes = Set(filteredFavorites.map { $0.id })
                        }
                        .foregroundColor(.blue)
                    }
                    
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button("Remove Selected (\(selectedRecipes.count))") {
                                showingBulkDeleteAlert = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedRecipes.isEmpty)
                            
                            Spacer()
                            
                            Button("Remove All") {
                                selectedRecipes = Set(filteredFavorites.map { $0.id })
                                showingBulkDeleteAlert = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .alert("Remove from Favorites", isPresented: $showingDeleteAlert) {
            Button("Remove", role: .destructive) {
                if let recipe = recipeToDelete {
                    recipeManager.removeFromFavorites(recipe)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove this recipe from your favorites?")
        }
        .alert("Remove Selected Recipes", isPresented: $showingBulkDeleteAlert) {
            Button("Remove \(selectedRecipes.count) Recipes", role: .destructive) {
                removeSelectedRecipes()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove \(selectedRecipes.count) recipe\(selectedRecipes.count == 1 ? "" : "s") from your favorites?")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Empty State Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.orange)
            }
            .accessibilityHidden(true)
            
            // Empty State Text
            VStack(spacing: 8) {
                Text("No Favorites Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Your favorite recipes will appear here")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Call to Action
            Button("Generate Your First Recipe") {
                // Navigate to recipe generator
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No favorites yet. Your favorite recipes will appear here.")
    }
    
    // MARK: - Favorites List
    
    private var favoritesListView: some View {
        List {
            ForEach(filteredFavorites) { recipe in
                FavoriteRecipeRow(
                    recipe: recipe,
                    onDelete: {
                        recipeToDelete = recipe
                        showingDeleteAlert = true
                    },
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedRecipes.contains(recipe.id),
                    onSelectionToggle: {
                        if selectedRecipes.contains(recipe.id) {
                            selectedRecipes.remove(recipe.id)
                        } else {
                            selectedRecipes.insert(recipe.id)
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
        .overlay {
            if filteredFavorites.isEmpty && !searchText.isEmpty {
                noSearchResultsView
            }
        }
    }
    
    private var noSearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your search terms")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No search results found. Try adjusting your search terms.")
    }
    
    // MARK: - Helper Methods
    
    private func removeSelectedRecipes() {
        let recipesToRemove = filteredFavorites.filter { selectedRecipes.contains($0.id) }
        for recipe in recipesToRemove {
            recipeManager.removeFromFavorites(recipe)
        }
        selectedRecipes.removeAll()
        isSelectionMode = false
    }
}

// MARK: - Favorite Recipe Row

struct FavoriteRecipeRow: View {
    let recipe: Recipe
    let onDelete: () -> Void
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var shoppingCartService: ShoppingCartService
    @State private var showingShoppingCart = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Button(action: onSelectionToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isSelected ? "Deselect \(recipe.name)" : "Select \(recipe.name)")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Recipe Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Recipe Tags
                        HStack(spacing: 8) {
                            RecipeTag(text: recipe.cuisine.rawValue.capitalized, color: .orange)
                            RecipeTag(text: recipe.difficulty.rawValue.capitalized, color: .blue)
                        }
                    }
                    
                    Spacer()
                    
                    // Recipe Info
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(recipe.formattedTotalTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(recipe.servings) servings", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(recipe.caloriesPerServing) cal", systemImage: "flame")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Ingredients Preview
                if !recipe.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ingredients")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(ingredientsPreview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Action Buttons
                HStack {
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        Text("View Recipe")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("View recipe details for \(recipe.name)")
                    .accessibilityHint("Navigate to detailed recipe view")
                    
                    NavigationLink(destination: DetailedCookingInstructionsView(recipe: recipe)) {
                        Text("Start Cooking")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Start cooking \(recipe.name)")
                    .accessibilityHint("View detailed cooking instructions for this recipe")
                    
                    // Shopping List Button
                    Button(action: {
                        shoppingCartService.addRecipeIngredients(recipe)
                        showingShoppingCart = true
                    }) {
                        Text("Shopping List")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Add ingredients to shopping list")
                    .accessibilityHint("Add all ingredients for \(recipe.name) to your shopping list")
                    
                    Spacer()
                    
                    if !isSelectionMode {
                        Button("Remove", role: .destructive) {
                            onDelete()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Remove \(recipe.name) from favorites")
                        .accessibilityHint("Delete this recipe from your favorites list")
                    }
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(recipe.name), \(recipe.cuisine.rawValue) cuisine, \(recipe.difficulty.rawValue) difficulty, \(recipe.formattedTotalTime) total time")
            .accessibilityHint("Double tap to view recipe details")
        }
        .sheet(isPresented: $showingShoppingCart) {
            InlineShoppingCartView()
        }
    }
    
    private var ingredientsPreview: String {
        let ingredientNames = recipe.ingredients.prefix(3).map { $0.name }
        let preview = ingredientNames.joined(separator: ", ")
        return recipe.ingredients.count > 3 ? "\(preview)..." : preview
    }
}

// MARK: - Recipe Tag

struct RecipeTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environmentObject(RecipeManager())
    }
} 