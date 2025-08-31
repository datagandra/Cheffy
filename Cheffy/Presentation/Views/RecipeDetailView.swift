import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var showingIngredients = true
    @State private var showingWinePairings = false
    @State private var showingChefNotes = false
    @State private var showingMichelinGuide = false
    @State private var showingImageGeneration = false
    @State private var targetServings: Int
    
    init(recipe: Recipe) {
        self.recipe = recipe
        self._targetServings = State(initialValue: recipe.servings)
    }
    
    // Computed property to get scaled recipe for target servings
    private var scaledRecipe: Recipe {
        if targetServings == recipe.servings {
            return recipe
        } else {
            return recipe.scaledForServings(targetServings)
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Recipe Header
                recipeHeader
                
                // Michelin Cooking Guide Button
                // Cooking guide and Michelin chef techniques will be added in future updates
                // if recipe.cookingGuide != nil || recipe.michelinChefTechniques != nil {
                //     michelinGuideButton
                // }
                
                // Ingredients Section
                ingredientsSection
                
                // Wine Pairings (if available)
                if !scaledRecipe.winePairings.isEmpty {
                    winePairingsSection
                }
                
                // Chef Notes (if available)
                if !scaledRecipe.chefNotes.isEmpty {
                    chefNotesSection
                }
                
                // Plating Tips (if available)
                if !scaledRecipe.platingTips.isEmpty {
                    platingTipsSection
                }
                
                // Start Cooking Button
                startCookingButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingImageGeneration) {
            ImageGenerationView(recipe: recipe)
        }

    }
    
    // MARK: - Recipe Header
    private var recipeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and badges
            VStack(alignment: .leading, spacing: 12) {
                Text(scaledRecipe.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                
                HStack(spacing: 8) {
                    BadgeView(text: scaledRecipe.cuisine.rawValue, color: Color.orange)
                    BadgeView(text: scaledRecipe.difficulty.rawValue, color: Color.blue)
                    Spacer()
                }
            }
            
            // Time breakdown
            timeBreakdownView
            
            // Servings and Calories info
            HStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.green)
                    
                    // Servings selector
                    Menu {
                        ForEach([2, 4, 6, 8, 10, 12], id: \.self) { serving in
                            Button(action: {
                                targetServings = serving
                            }) {
                                HStack {
                                    Text("\(serving) servings")
                                    if targetServings == serving {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("\(scaledRecipe.servings) servings")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(scaledRecipe.caloriesPerServing) cal/serving")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Time Breakdown
    private var timeBreakdownView: some View {
        HStack(spacing: 0) {
            TimeCard(title: "Prep", time: scaledRecipe.formattedPrepTime, icon: "clock")
            Divider()
                .frame(height: 40)
            TimeCard(title: "Cook", time: scaledRecipe.formattedCookTime, icon: "flame")
            Divider()
                .frame(height: 40)
            TimeCard(title: "Total", time: scaledRecipe.formattedTotalTime, icon: "timer", isHighlighted: true)
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    ForEach(scaledRecipe.ingredients) { ingredient in
                        IngredientRow(ingredient: ingredient)
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
                    ForEach(scaledRecipe.winePairings) { wine in
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
                Text(scaledRecipe.chefNotes)
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
            
            Text(scaledRecipe.platingTips)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Michelin Cooking Guide Button
    private var michelinGuideButton: some View {
        Button(action: {
            showingMichelinGuide = true
        }) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("View Michelin Star Cooking Guide")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingMichelinGuide) {
            // MichelinCookingGuideView will be added in future updates
            Text("Michelin Star Cooking Guide")
                .font(.title)
                .padding()
        }
    }
    
    // MARK: - Start Cooking Button
    private var startCookingButton: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: CookingModeView(recipe: scaledRecipe)) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Start Cooking Mode")
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
            
            // AI Image Generation Button
            Button(action: {
                showingImageGeneration = true
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Generate AI Image")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Generate AI image for this recipe")
            .accessibilityHint("Tap to create an AI-generated image based on the recipe")
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
}

// MARK: - Supporting Views

struct WinePairingRow: View {
    let wine: WinePairing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wine.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(wine.region)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                BadgeView(text: wine.type.rawValue, color: Color.purple)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Check for specific wine details and format them
                if wine.description.contains("vintage") || wine.description.contains("serving temperature") {
                    HStack {
                        Image(systemName: "thermometer.snowflake")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Serving Details")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                
                if wine.description.contains("tasting notes") || wine.description.contains("flavor") {
                    HStack {
                        Image(systemName: "wineglass.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text("Tasting Notes")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                }
                
                if wine.description.contains("alternative") || wine.description.contains("substitution") {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("Alternative Options")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                
                Text(wine.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

 