import SwiftUI
import PhotosUI

struct RecipeContributionView: View {
    @StateObject private var viewModel: RecipeViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var ingredients: [String] = [""]
    @State private var instructions: [String] = [""]
    @State private var selectedImage: PhotosPickerItem?
    @State private var displayImage: UIImage?
    @State private var cuisine = ""
    @State private var difficulty = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var servings = ""
    @State private var dietaryNotes: [String] = []
    
    private let availableCuisines = ["Italian", "Mexican", "Chinese", "Indian", "French", "Japanese", "Thai", "Mediterranean", "American", "Other"]
    private let availableDifficulties = ["Easy", "Medium", "Hard", "Expert"]
    private let availableDietaryNotes = ["Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free", "Nut-Free", "Low-Carb", "Keto", "Paleo"]
    private let editingRecipe: UserRecipe?
    
    init(cloudKitService: any CloudKitServiceProtocol, editingRecipe: UserRecipe? = nil) {
        self._viewModel = StateObject(wrappedValue: RecipeViewModel(cloudKitService: cloudKitService))
        self.editingRecipe = editingRecipe
        
        if let recipe = editingRecipe {
            self.title = recipe.title
            self.ingredients = recipe.ingredients
            self.instructions = recipe.instructions
            self.cuisine = recipe.cuisine ?? ""
            self.difficulty = recipe.difficulty ?? ""
            self.prepTime = recipe.prepTime?.description ?? ""
            self.cookTime = recipe.cookTime?.description ?? ""
            self.servings = recipe.servings?.description ?? ""
            self.dietaryNotes = recipe.dietaryNotes ?? []
            if let imageData = recipe.imageData {
                self.displayImage = UIImage(data: imageData)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                basicInformationSection
                
                // Ingredients
                ingredientsSection
                
                // Instructions
                instructionsSection
                
                // Image
                imageSection
                
                // Additional Details
                additionalDetailsSection
                
                // Dietary Notes
                dietaryNotesSection
            }
            .navigationTitle(editingRecipe != nil ? "Edit Recipe" : "Contribute Recipe")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveRecipe()
                        }
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                }
            }
            .onChange(of: selectedImage) { _ in
                Task {
                    await loadImage()
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage)
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay()
                }
            }
        }
    }
    
    // MARK: - Basic Information Section
    
    private var basicInformationSection: some View {
        Section("Basic Information") {
            TextField("Recipe Title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Picker("Cuisine", selection: $cuisine) {
                Text("Select Cuisine").tag("")
                ForEach(availableCuisines, id: \.self) { cuisine in
                    Text(cuisine).tag(cuisine)
                }
            }
            
            Picker("Difficulty", selection: $difficulty) {
                Text("Select Difficulty").tag("")
                ForEach(availableDifficulties, id: \.self) { difficulty in
                    Text(difficulty).tag(difficulty)
                }
            }
        }
    }
    
    // MARK: - Ingredients Section
    
    private var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(ingredients.indices, id: \.self) { index in
                HStack {
                    TextField("Ingredient \(index + 1)", text: $ingredients[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if ingredients.count > 1 {
                        Button(action: {
                            ingredients.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Button("Add Ingredient") {
                ingredients.append("")
            }
            .disabled(ingredients.last?.isEmpty == true)
        }
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        Section("Instructions") {
            ForEach(instructions.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                    
                    TextField("Step \(index + 1)", text: $instructions[index], axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
                    
                    if instructions.count > 1 {
                        Button(action: {
                            instructions.remove(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Button("Add Step") {
                instructions.append("")
            }
            .disabled(instructions.last?.isEmpty == true)
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        Section("Recipe Image") {
            VStack(spacing: 12) {
                if let displayImage = displayImage {
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            Button(action: {
                                self.displayImage = nil
                                self.selectedImage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(8),
                            alignment: .topTrailing
                        )
                }
                
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    HStack {
                        Image(systemName: "photo")
                        Text(displayImage == nil ? "Select Image" : "Change Image")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Additional Details Section
    
    private var additionalDetailsSection: some View {
        Section("Additional Details") {
            HStack {
                Text("Prep Time")
                Spacer()
                TextField("Minutes", text: $prepTime)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .keyboardType(.numberPad)
                Text("min")
            }
            
            HStack {
                Text("Cook Time")
                Spacer()
                TextField("Minutes", text: $cookTime)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .keyboardType(.numberPad)
                Text("min")
            }
            
            HStack {
                Text("Servings")
                Spacer()
                TextField("People", text: $servings)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .keyboardType(.numberPad)
                Text("people")
            }
        }
    }
    
    // MARK: - Dietary Notes Section
    
    private var dietaryNotesSection: some View {
        Section("Dietary Notes") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(availableDietaryNotes, id: \.self) { note in
                    Button(action: {
                        if dietaryNotes.contains(note) {
                            dietaryNotes.removeAll { $0 == note }
                        } else {
                            dietaryNotes.append(note)
                        }
                    }) {
                        HStack {
                            Image(systemName: dietaryNotes.contains(note) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(dietaryNotes.contains(note) ? .green : .gray)
                            Text(note)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(dietaryNotes.contains(note) ? Color.green.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty &&
        !instructions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty
    }
    
    private func loadImage() async {
        guard let selectedImage = selectedImage else { return }
        
        do {
            if let data = try await selectedImage.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    displayImage = uiImage
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    
    private func saveRecipe() async {
        let cleanIngredients = ingredients.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let cleanInstructions = instructions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        await viewModel.createRecipe(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            ingredients: cleanIngredients,
            instructions: cleanInstructions,
            image: displayImage,
            cuisine: cuisine.isEmpty ? nil : cuisine,
            difficulty: difficulty.isEmpty ? nil : difficulty,
            prepTime: Int(prepTime),
            cookTime: Int(cookTime),
            servings: Int(servings),
            dietaryNotes: dietaryNotes.isEmpty ? nil : dietaryNotes
        )
    }
}

// MARK: - Supporting Views

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Saving Recipe...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray6).opacity(0.9))
            .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#Preview {
    RecipeContributionView(cloudKitService: MockCloudKitService())
}
