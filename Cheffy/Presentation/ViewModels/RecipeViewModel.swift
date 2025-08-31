import Foundation
import Combine
import UIKit

@MainActor
class RecipeViewModel: ObservableObject {
    @Published var userRecipes: [UserRecipe] = []
    @Published var publicRecipes: [UserRecipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var successMessage = ""
    @Published var showingRecipeForm = false
    @Published var selectedRecipe: UserRecipe?
    
    let cloudKitService: any CloudKitServiceProtocol
    private let logger = Logger.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init(cloudKitService: any CloudKitServiceProtocol) {
        self.cloudKitService = cloudKitService
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor CloudKit sync status
        cloudKitService.syncStatusPublisher
            .sink { [weak self] status in
                self?.handleSyncStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadUserRecipes() async {
        guard cloudKitService.isCloudKitAvailable else {
            showError("CloudKit is not available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let recipes = try await cloudKitService.fetchUserRecipes()
            userRecipes = recipes
            showSuccess("Loaded \(recipes.count) user recipes")
        } catch {
            showError("Failed to load user recipes: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func loadPublicRecipes() async {
        guard cloudKitService.isCloudKitAvailable else {
            showError("CloudKit is not available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let recipes = try await cloudKitService.fetchPublicRecipes()
            publicRecipes = recipes
            showSuccess("Loaded \(publicRecipes.count) public recipes")
        } catch {
            showError("Failed to load public recipes: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func createRecipe(
        title: String,
        ingredients: [String],
        instructions: [String],
        image: UIImage?,
        cuisine: String?,
        difficulty: String?,
        prepTime: Int?,
        cookTime: Int?,
        servings: Int?,
        dietaryNotes: [String]?
    ) async {
        guard cloudKitService.isCloudKitAvailable else {
            showError("CloudKit is not available")
            return
        }
        
        guard let userID = cloudKitService.currentUserID else {
            showError("User not authenticated")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let imageData = image?.jpegData(compressionQuality: 0.8)
            
            let recipe = UserRecipe(
                title: title,
                ingredients: ingredients,
                instructions: instructions,
                authorID: userID,
                imageData: imageData,
                cuisine: cuisine,
                difficulty: difficulty,
                prepTime: prepTime,
                cookTime: cookTime,
                servings: servings,
                dietaryNotes: dietaryNotes,
                isPublic: true,
                syncStatus: .uploading
            )
            
            try await cloudKitService.uploadUserRecipe(recipe)
            
            // Add to local list
            userRecipes.insert(recipe, at: 0)
            
            showSuccess("Recipe '\(title)' created successfully!")
            showingRecipeForm = false
        } catch {
            showError("Failed to create recipe: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func updateRecipe(_ recipe: UserRecipe) async {
        guard cloudKitService.isCloudKitAvailable else {
            showError("CloudKit is not available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await cloudKitService.uploadUserRecipe(recipe)
            
            // Update in local list
            if let index = userRecipes.firstIndex(where: { $0.id == recipe.id }) {
                userRecipes[index] = recipe
            }
            
            showSuccess("Recipe '\(recipe.title)' updated successfully!")
        } catch {
            showError("Failed to update recipe: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func deleteRecipe(_ recipe: UserRecipe) async {
        guard cloudKitService.isCloudKitAvailable else {
            showError("CloudKit is not available")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await cloudKitService.deleteUserRecipe(recipe)
            
            // Remove from local lists
            userRecipes.removeAll { $0.id == recipe.id }
            publicRecipes.removeAll { $0.id == recipe.id }
            
            showSuccess("Recipe '\(recipe.title)' deleted successfully!")
        } catch {
            showError("Failed to delete recipe: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func refreshAllRecipes() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadUserRecipes() }
            group.addTask { await self.loadPublicRecipes() }
        }
    }
    
    func showRecipeForm() {
        selectedRecipe = nil
        showingRecipeForm = true
    }
    
    func editRecipe(_ recipe: UserRecipe) {
        selectedRecipe = recipe
        showingRecipeForm = true
    }
    
    // MARK: - Private Methods
    
    private func handleSyncStatusChange(_ status: CloudKitSyncStatus) {
        switch status {
        case .syncing:
            isLoading = true
        case .available, .notAvailable, .checking, .error:
            isLoading = false
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        logger.error(message)
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
        logger.info(message)
    }
    
    // MARK: - Computed Properties
    
    var totalUserRecipes: Int {
        userRecipes.count
    }
    
    var totalPublicRecipes: Int {
        publicRecipes.count
    }
    
    var pendingUploadRecipes: Int {
        userRecipes.filter { $0.syncStatus == .pending || $0.syncStatus == .uploading }.count
    }
    
    var syncedRecipes: Int {
        userRecipes.filter { $0.syncStatus == .synced }.count
    }
    
    var failedRecipes: Int {
        userRecipes.filter { $0.syncStatus == .failed }.count
    }
    
    var recipesByCuisine: [String: [UserRecipe]] {
        Dictionary(grouping: userRecipes, by: { $0.cuisine ?? "Unknown" })
    }
    
    var recipesByDifficulty: [String: [UserRecipe]] {
        Dictionary(grouping: userRecipes, by: { $0.difficulty ?? "Unknown" })
    }
    
    var recentRecipes: [UserRecipe] {
        Array(userRecipes.prefix(5))
    }
    
    var popularRecipes: [UserRecipe] {
        // Sort by creation date for now, could be enhanced with view counts later
        userRecipes.sorted { $0.createdAt > $1.createdAt }
    }
    
    var recipesWithImages: [UserRecipe] {
        userRecipes.filter { $0.imageData != nil }
    }
    
    var recipesWithoutImages: [UserRecipe] {
        userRecipes.filter { $0.imageData == nil }
    }
}

// MARK: - Mock Implementation for Testing
class MockRecipeViewModel: RecipeViewModel {
    override init(cloudKitService: any CloudKitServiceProtocol) {
        super.init(cloudKitService: cloudKitService)
        
        // Add some mock data for testing
        userRecipes = [
            UserRecipe(
                title: "Mock Recipe 1",
                ingredients: ["Ingredient 1", "Ingredient 2"],
                instructions: ["Step 1", "Step 2"],
                authorID: "mock-user-id",
                cuisine: "Italian",
                difficulty: "Medium",
                prepTime: 15,
                cookTime: 30,
                servings: 4
            ),
            UserRecipe(
                title: "Mock Recipe 2",
                ingredients: ["Ingredient 3", "Ingredient 4"],
                instructions: ["Step 1", "Step 2", "Step 3"],
                authorID: "mock-user-id",
                cuisine: "Mexican",
                difficulty: "Easy",
                prepTime: 10,
                cookTime: 20,
                servings: 2
            )
        ]
        
        publicRecipes = userRecipes
    }
}
