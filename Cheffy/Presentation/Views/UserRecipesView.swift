import SwiftUI

struct UserRecipesView: View {
    @StateObject private var viewModel: RecipeViewModel
    @State private var showingRecipeForm = false
    @State private var selectedRecipe: UserRecipe?
    @State private var showingRecipeDetails = false
    @State private var searchText = ""
    @State private var selectedFilter: RecipeFilter = .all
    
    enum RecipeFilter: String, CaseIterable {
        case all = "All"
        case myRecipes = "My Recipes"
        case publicRecipes = "Public Recipes"
        case pending = "Pending"
        case synced = "Synced"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .myRecipes: return "person.circle"
            case .publicRecipes: return "globe"
            case .pending: return "clock"
            case .synced: return "checkmark.circle"
            }
        }
    }
    
    init(cloudKitService: any CloudKitServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: RecipeViewModel(cloudKitService: cloudKitService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter and search
                filterAndSearchSection
                
                // Stats header
                statsHeader
                
                // Recipes list
                recipesList
            }
            .navigationTitle("User Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Recipe") {
                        showingRecipeForm = true
                    }
                    .disabled(viewModel.isLoading)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Refresh") {
                        Task {
                            await viewModel.refreshAllRecipes()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await viewModel.refreshAllRecipes()
            }
            .task {
                await viewModel.refreshAllRecipes()
            }
            .sheet(isPresented: $showingRecipeForm) {
                RecipeContributionView(cloudKitService: viewModel.cloudKitService)
            }
            .sheet(isPresented: $showingRecipeDetails) {
                if let recipe = selectedRecipe {
                    UserRecipeDetailView(recipe: recipe, viewModel: viewModel)
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.successMessage)
            }
        }
    }
    
    // MARK: - Filter and Search Section
    
    private var filterAndSearchSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search recipes...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Filter buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RecipeFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack {
            StatBadge(
                title: "My Recipes",
                value: "\(viewModel.totalUserRecipes)",
                icon: "person.circle.fill",
                color: .blue
            )
            
            StatBadge(
                title: "Public",
                value: "\(viewModel.totalPublicRecipes)",
                icon: "globe",
                color: .green
            )
            
            StatBadge(
                title: "Pending",
                value: "\(viewModel.pendingUploadRecipes)",
                icon: "clock",
                color: .orange
            )
            
            StatBadge(
                title: "Synced",
                value: "\(viewModel.syncedRecipes)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Recipes List
    
    private var recipesList: some View {
        List {
            if viewModel.isLoading {
                LoadingRow()
            } else if filteredRecipes.isEmpty {
                EmptyStateRow()
            } else {
                ForEach(filteredRecipes) { recipe in
                    UserRecipeRow(recipe: recipe)
                        .onTapGesture {
                            selectedRecipe = recipe
                            showingRecipeDetails = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") {
                                selectedRecipe = recipe
                                showingRecipeForm = true
                            }
                            .tint(.blue)
                            
                            Button("Delete", role: .destructive) {
                                Task {
                                    await viewModel.deleteRecipe(recipe)
                                }
                            }
                        }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var filteredRecipes: [UserRecipe] {
        var recipes: [UserRecipe]
        
        switch selectedFilter {
        case .all:
            recipes = viewModel.userRecipes + viewModel.publicRecipes
        case .myRecipes:
            recipes = viewModel.userRecipes
        case .publicRecipes:
            recipes = viewModel.publicRecipes
        case .pending:
            recipes = viewModel.userRecipes.filter { $0.syncStatus == .pending || $0.syncStatus == .uploading }
        case .synced:
            recipes = viewModel.userRecipes.filter { $0.syncStatus == .synced }
        }
        
        if !searchText.isEmpty {
            recipes = recipes.filter { recipe in
                recipe.title.localizedCaseInsensitiveContains(searchText) ||
                recipe.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (recipe.cuisine?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return recipes.sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Supporting Views

struct FilterButton: View {
    let filter: UserRecipesView.RecipeFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                Text(filter.rawValue)
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct UserRecipeRow: View {
    let recipe: UserRecipe
    
    var body: some View {
        HStack(spacing: 12) {
            // Recipe image
            if let image = recipe.displayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Recipe details
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    if let cuisine = recipe.cuisine {
                        Text(cuisine)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let difficulty = recipe.difficulty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(difficulty)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if recipe.totalTime > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(recipe.totalTime) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(recipe.formattedCreatedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Sync status indicator
                    HStack(spacing: 4) {
                        Image(systemName: recipe.syncStatus.icon)
                            .foregroundColor(Color(recipe.syncStatus.color))
                        Text(recipe.syncStatus.rawValue)
                            .font(.caption2)
                            .foregroundColor(Color(recipe.syncStatus.color))
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct LoadingRow: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading recipes...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct EmptyStateRow: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Recipes Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Start contributing by adding your first recipe!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    UserRecipesView(cloudKitService: MockCloudKitService())
}
