import SwiftUI

struct UserRecipeDetailView: View {
    let recipe: UserRecipe
    let viewModel: RecipeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditForm = false
    @State private var showingDeleteAlert = false
    @State private var recipeDetailsExpanded = true
    @State private var ingredientsExpanded = true
    @State private var instructionsExpanded = true
    @State private var dietaryNotesExpanded = true
    @State private var syncStatusExpanded = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe image
                    recipeImageSection
                    
                    // Recipe header
                    recipeHeaderSection
                    
                    // Recipe details
                    recipeDetailsSection
                    
                    // Ingredients
                    ingredientsSection
                    
                    // Instructions
                    instructionsSection
                    
                    // Dietary notes
                    if let dietaryNotes = recipe.dietaryNotes, !dietaryNotes.isEmpty {
                        dietaryNotesSection(dietaryNotes)
                    }
                    
                    // Sync status
                    syncStatusSection
                }
                .padding()
            }
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditForm = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditForm) {
                RecipeContributionView(
                    cloudKitService: viewModel.cloudKitService,
                    editingRecipe: recipe
                )
            }
            .alert("Delete Recipe", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteRecipe(recipe)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete '\(recipe.title)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Recipe Image Section
    
    private var recipeImageSection: some View {
        Group {
            if let image = recipe.displayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Image")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
    
    // MARK: - Recipe Header Section
    
    private var recipeHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                if let cuisine = recipe.cuisine {
                    Label(cuisine, systemImage: "globe")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let difficulty = recipe.difficulty {
                    Label(difficulty, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if recipe.totalTime > 0 {
                    Label("\(recipe.totalTime) min", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
        }
    }
    
    // MARK: - Recipe Details Section
    
    private var recipeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recipe Details", icon: "info.circle", color: .blue, isExpanded: $recipeDetailsExpanded)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                if let prepTime = recipe.prepTime {
                    DetailCard(title: "Prep Time", value: "\(prepTime) min", icon: "timer")
                }
                
                if let cookTime = recipe.cookTime {
                    DetailCard(title: "Cook Time", value: "\(cookTime) min", icon: "flame")
                }
                
                if let servings = recipe.servings {
                    DetailCard(title: "Servings", value: "\(servings) people", icon: "person.2")
                }
                
                DetailCard(title: "Created", value: recipe.formattedCreatedDate, icon: "calendar")
            }
        }
    }
    
    // MARK: - Ingredients Section
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Ingredients", icon: "list.bullet", color: .green, isExpanded: $ingredientsExpanded)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(width: 25, alignment: .leading)
                        
                        Text(ingredient)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Instructions", icon: "list.number", color: .orange, isExpanded: $instructionsExpanded)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.blue)
                                .clipShape(Circle())
                            
                            Text(instruction)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        
                        if index < recipe.instructions.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Dietary Notes Section
    
    private func dietaryNotesSection(_ notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Dietary Notes", icon: "leaf", color: .green, isExpanded: $dietaryNotesExpanded)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(notes, id: \.self) { note in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Sync Status Section
    
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sync Status", icon: "icloud", color: .blue, isExpanded: $syncStatusExpanded)
            
            HStack {
                Image(systemName: recipe.syncStatus.icon)
                    .foregroundColor(Color(recipe.syncStatus.color))
                
                Text(recipe.syncStatus.rawValue)
                    .font(.subheadline)
                    .foregroundColor(Color(recipe.syncStatus.color))
                
                Spacer()
                
                if recipe.syncStatus == .failed {
                    Button("Retry") {
                        Task {
                            await viewModel.updateRecipe(recipe)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Supporting Views

struct DetailCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    UserRecipeDetailView(
        recipe: UserRecipe(
            title: "Sample Recipe",
            ingredients: ["Ingredient 1", "Ingredient 2", "Ingredient 3"],
            instructions: ["Step 1: Do this", "Step 2: Do that", "Step 3: Enjoy!"],
            authorID: "preview-user",
            cuisine: "Italian",
            difficulty: "Medium",
            prepTime: 15,
            cookTime: 30,
            servings: 4,
            dietaryNotes: ["Vegetarian", "Gluten-Free"]
        ),
        viewModel: MockRecipeViewModel(cloudKitService: MockCloudKitService())
    )
}
