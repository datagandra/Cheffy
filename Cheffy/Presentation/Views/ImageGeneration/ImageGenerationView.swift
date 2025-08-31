import SwiftUI
import Photos

// MARK: - Image Generation View
struct ImageGenerationView: View {
    let recipe: Recipe
    @StateObject private var viewModel: ImageGenerationViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(recipe: Recipe, imageGenerationService: ImageGenerationServiceProtocol? = nil) {
        self.recipe = recipe
        let service = imageGenerationService ?? ImageGenerationService()
        self._viewModel = StateObject(wrappedValue: ImageGenerationViewModel(imageGenerationService: service))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Recipe Header
                    recipeHeaderSection
                    
                    // Image Generation Controls
                    generationControlsSection
                    
                    // Generated Image Display
                    if viewModel.generatedImage != nil || viewModel.isGenerating {
                        generatedImageSection
                    }
                    
                    // Style and Size Options
                    optionsSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Image Generation")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.generatedImage != nil {
                        Button("Clear") {
                            viewModel.clearImage()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                viewModel.setRecipe(recipe)
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.successMessage)
            }
            .sheet(isPresented: $viewModel.showingStylePicker) {
                StylePickerView(selectedStyle: $viewModel.selectedStyle)
            }
            .sheet(isPresented: $viewModel.showingSizePicker) {
                SizePickerView(selectedSize: $viewModel.selectedSize)
            }
            .sheet(isPresented: $viewModel.showingShareSheet) {
                if let image = viewModel.generatedImage {
                    ShareSheet(items: [image])
                }
            }
            .actionSheet(isPresented: $viewModel.showingSaveOptions) {
                ActionSheet(
                    title: Text("Save Image"),
                    message: Text("Choose how to save the generated image"),
                    buttons: [
                        .default(Text("Save to Photos")) {
                            Task {
                                await viewModel.saveToPhotos()
                            }
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    // MARK: - Recipe Header Section
    private var recipeHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(recipe.cuisine.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Recipe image placeholder or existing image
                if let existingImage = recipe.imageURL {
                    AsyncImage(url: existingImage) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "fork.knife")
                                .foregroundColor(.secondary)
                        )
                        .frame(width: 60, height: 60)
                }
            }
            
            // Recipe chef notes
            if !recipe.chefNotes.isEmpty {
                Text(recipe.chefNotes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(3)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Generation Controls Section
    private var generationControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate AI Image")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Style and Size Picker Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.showingStylePicker = true
                    }) {
                        HStack {
                            Image(systemName: viewModel.selectedStyle.icon)
                                .foregroundColor(.orange)
                            Text(viewModel.selectedStyle.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        viewModel.showingSizePicker = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.expand.vertical")
                                .foregroundColor(.blue)
                            Text(viewModel.selectedSize.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Generate Button
                Button(action: {
                    if viewModel.isGenerating {
                        // Stop generation if in progress
                        viewModel.clearImage()
                    } else {
                        Task {
                            await viewModel.generateImage()
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: viewModel.generationButtonIcon)
                        }
                        
                        Text(viewModel.generationButtonTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(viewModel.generationButtonColor))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isGenerating)
                .accessibilityLabel(viewModel.generationButtonTitle)
                .accessibilityHint("Tap to generate an AI image for this recipe")
                
                // Cache Status
                if viewModel.hasCachedImage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(viewModel.cacheStatusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Generated Image Section
    private var generatedImageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generated Image")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.isGenerating {
                // Loading State
                VStack(spacing: 16) {
                    ProgressView(value: viewModel.generationProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    Text("Generating your image...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(viewModel.generationProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            } else if let image = viewModel.generatedImage {
                // Generated Image
                VStack(spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .accessibilityLabel("Generated AI image for \(recipe.name)")
                    
                    // Image Info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Style: \(viewModel.selectedStyle.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Size: \(viewModel.selectedSize.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Quick Actions
                        HStack(spacing: 12) {
                            Button(action: {
                                viewModel.shareImage()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel("Share image")
                            
                            Button(action: {
                                viewModel.showSaveOptions()
                            }) {
                                Image(systemName: "photo")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                            .accessibilityLabel("Save to Photos")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Options Section
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generation Options")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Style Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Style")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(ImageStyle.allCases, id: \.self) { style in
                            StyleOptionCard(
                                style: style,
                                isSelected: viewModel.selectedStyle == style,
                                action: {
                                    viewModel.changeStyle(style)
                                }
                            )
                        }
                    }
                }
                
                // Size Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(ImageSize.allCases, id: \.self) { size in
                            SizeOptionCard(
                                size: size,
                                isSelected: viewModel.selectedSize == size,
                                action: {
                                    viewModel.changeSize(size)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if viewModel.generatedImage != nil {
                // Regenerate Button
                Button(action: {
                    Task {
                        await viewModel.regenerateImage()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Regenerate with New Settings")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .accessibilityLabel("Regenerate image with new settings")
            }
            
            // Cache Management
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.clearCache()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .accessibilityLabel("Clear image cache")
                
                Button(action: {
                    // Show cache statistics
                    let stats = viewModel.getCacheStatistics()
                    print("Cache Statistics: \(stats)")
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Cache Info")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
                .accessibilityLabel("Show cache information")
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Style Option Card
struct StyleOptionCard: View {
    let style: ImageStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .orange)
                
                Text(style.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.orange : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(style.rawValue) style")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Size Option Card
struct SizeOptionCard: View {
    let size: ImageSize
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(size.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(Int(size.dimensions.width))×\(Int(size.dimensions.height))")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(size.rawValue) size")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Style Picker View
struct StylePickerView: View {
    @Binding var selectedStyle: ImageStyle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(ImageStyle.allCases, id: \.self) { style in
                Button(action: {
                    selectedStyle = style
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: style.icon)
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text(style.rawValue)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedStyle == style {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Select Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Size Picker View
struct SizePickerView: View {
    @Binding var selectedSize: ImageSize
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(ImageSize.allCases, id: \.self) { size in
                Button(action: {
                    selectedSize = size
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(size.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(Int(size.dimensions.width))×\(Int(size.dimensions.height)) pixels")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedSize == size {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Select Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ImageGenerationView(
        recipe: Recipe(
            id: UUID(),
            title: "Classic Italian Carbonara",
            name: "Classic Italian Carbonara",
            cuisine: .italian,
            difficulty: .medium,
            prepTime: 15,
            cookTime: 20,
            servings: 4,
            ingredients: [
                Ingredient(name: "Pasta", amount: 500, unit: "g"),
                Ingredient(name: "Eggs", amount: 4, unit: "pieces")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Boil pasta"),
                CookingStep(stepNumber: 2, description: "Add sauce")
            ],
            winePairings: [],
            dietaryNotes: [.vegetarian],
            platingTips: "Garnish with black pepper",
            chefNotes: "A traditional Roman pasta dish",
            imageURL: nil,
            stepImages: [],
            createdAt: Date(),
            isFavorite: false
        )
    )
}
