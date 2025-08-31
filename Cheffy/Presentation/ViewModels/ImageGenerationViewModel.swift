import Foundation
import UIKit
import Photos
import os.log

// MARK: - Image Generation ViewModel
@MainActor
class ImageGenerationViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let imageGenerationService: ImageGenerationServiceProtocol
    private let logger: Logger
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var generatedImage: UIImage?
    @Published var selectedStyle: ImageStyle = .photorealistic
    @Published var selectedSize: ImageSize = .medium
    @Published var showingStylePicker = false
    @Published var showingSizePicker = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var showingSuccess = false
    @Published var successMessage = ""
    @Published var showingShareSheet = false
    @Published var showingSaveOptions = false
    
    // MARK: - Private Properties
    private var currentRecipe: Recipe?
    private var imageToShare: UIImage?
    
    // MARK: - Internal Properties for Testing
    internal var testCurrentRecipe: Recipe? {
        get { currentRecipe }
        set { currentRecipe = newValue }
    }
    
    // MARK: - Initialization
    init(imageGenerationService: ImageGenerationServiceProtocol) {
        self.imageGenerationService = imageGenerationService
        self.logger = Logger.shared
        
        // Bind to service updates
        bindToService()
    }
    
    convenience init() {
        self.init(imageGenerationService: ImageGenerationService())
    }
    
    // MARK: - Public Methods
    
    /// Sets the current recipe and checks for cached images
    func setRecipe(_ recipe: Recipe) {
        self.currentRecipe = recipe
        checkForCachedImage()
    }
    
    /// Generates an image for the current recipe
    func generateImage() async {
        guard let recipe = currentRecipe else {
            showError("No recipe selected")
            return
        }
        
        do {
            logger.info("Starting image generation for recipe: \(recipe.name)")
            
            // Check if we already have a cached image for this style
            if let cachedImage = imageGenerationService.getCachedImage(for: recipe, style: selectedStyle) {
                logger.info("Using cached image for recipe: \(recipe.name)")
                self.generatedImage = cachedImage
                showSuccess("Using cached image")
                return
            }
            
            // Start generation
            isGenerating = true
            generationProgress = 0.0
            
            // Generate the image
            let image = try await imageGenerationService.generateImage(
                for: recipe,
                style: selectedStyle,
                size: selectedSize
            )
            
            // Update UI
            self.generatedImage = image
            self.isGenerating = false
            self.generationProgress = 1.0
            
            showSuccess("Image generated successfully!")
            logger.info("Successfully generated image for recipe: \(recipe.name)")
            
        } catch {
            handleGenerationError(error)
        }
    }
    
    /// Regenerates the image with current settings
    func regenerateImage() async {
        guard currentRecipe != nil else { return }
        
        // Clear current image
        generatedImage = nil
        
        // Generate new image
        await generateImage()
    }
    
    /// Changes the image style and regenerates if needed
    func changeStyle(_ style: ImageStyle) {
        selectedStyle = style
        showingStylePicker = false
        
        // Check if we have a cached image for this style
        if let recipe = currentRecipe,
           let cachedImage = imageGenerationService.getCachedImage(for: recipe, style: style) {
            generatedImage = cachedImage
            showSuccess("Using cached image for \(style.rawValue) style")
        } else {
            // Clear current image since style changed
            generatedImage = nil
        }
    }
    
    /// Changes the image size
    func changeSize(_ size: ImageSize) {
        selectedSize = size
        showingSizePicker = false
    }
    
    /// Shares the generated image
    func shareImage() {
        guard let image = generatedImage else {
            showError("No image to share")
            return
        }
        
        imageToShare = image
        showingShareSheet = true
    }
    
    /// Saves the image to Photos
    func saveToPhotos() async {
        guard let image = generatedImage else {
            showError("No image to save")
            return
        }
        
        do {
            try await saveImageToPhotos(image)
            showSuccess("Image saved to Photos")
        } catch {
            showError("Failed to save image: \(error.localizedDescription)")
        }
    }
    
    /// Shows save options
    func showSaveOptions() {
        showingSaveOptions = true
    }
    
    /// Clears the generated image
    func clearImage() {
        generatedImage = nil
        generationProgress = 0.0
    }
    
    /// Gets cache statistics
    func getCacheStatistics() -> [String: Any] {
        return imageGenerationService.getCacheStatistics()
    }
    
    /// Clears the image cache
    func clearCache() {
        imageGenerationService.clearCache()
        showSuccess("Cache cleared")
    }
    
    // MARK: - Private Methods
    
    /// Binds to service updates
    private func bindToService() {
        // Observe service state changes
        // Note: In a real implementation, you might use Combine or other reactive patterns
        // For now, we'll handle updates through the service calls
    }
    
    /// Checks for cached images
    private func checkForCachedImage() {
        guard let recipe = currentRecipe else { return }
        
        if let cachedImage = imageGenerationService.getCachedImage(for: recipe, style: selectedStyle) {
            generatedImage = cachedImage
            logger.info("Found cached image for recipe: \(recipe.name)")
        }
    }
    
    /// Handles generation errors
    private func handleGenerationError(_ error: Error) {
        isGenerating = false
        generationProgress = 0.0
        
        let message: String
        if let imageError = error as? ImageGenerationError {
            message = imageError.localizedDescription
        } else {
            message = error.localizedDescription
        }
        
        showError(message)
        logger.error("Image generation failed: \(error)")
    }
    
    /// Shows an error message
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    /// Shows a success message
    private func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
    }
    
    /// Saves image to Photos
    private func saveImageToPhotos(_ image: UIImage) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            try await saveImageToPhotosLibrary(image)
        case .denied, .restricted:
            throw ImageGenerationError.photosAccessDenied
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if granted == .authorized || granted == .limited {
                try await saveImageToPhotosLibrary(image)
            } else {
                throw ImageGenerationError.photosAccessDenied
            }
        @unknown default:
            throw ImageGenerationError.photosAccessDenied
        }
    }
    
    /// Saves image to Photos library
    private func saveImageToPhotosLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? ImageGenerationError.saveFailed)
                }
            }
        }
    }
    
    /// Gets the current recipe
    var recipe: Recipe? {
        currentRecipe
    }
    
    /// Checks if we have a cached image for the current style
    var hasCachedImage: Bool {
        guard let recipe = currentRecipe else { return false }
        return imageGenerationService.getCachedImage(for: recipe, style: selectedStyle) != nil
    }
    
    /// Gets the cache status message
    var cacheStatusMessage: String {
        if hasCachedImage {
            return "Using cached image"
        } else {
            return "Generate new image"
        }
    }
    
    /// Gets the generation button title
    var generationButtonTitle: String {
        if isGenerating {
            return "Generating..."
        } else if hasCachedImage {
            return "Regenerate"
        } else {
            return "Generate Image"
        }
    }
    
    /// Gets the generation button icon
    var generationButtonIcon: String {
        if isGenerating {
            return "stop.fill"
        } else if hasCachedImage {
            return "arrow.clockwise"
        } else {
            return "sparkles"
        }
    }
    
    /// Gets the generation button color
    var generationButtonColor: String {
        if isGenerating {
            return "red"
        } else if hasCachedImage {
            return "blue"
        } else {
            return "orange"
        }
    }
}

// MARK: - Extended Error Types
extension ImageGenerationError {
    static let photosAccessDenied = ImageGenerationError.generationFailed("Photos access denied")
    static let saveFailed = ImageGenerationError.generationFailed("Failed to save image")
}

// MARK: - Mock ViewModel for Testing
class MockImageGenerationViewModel: ImageGenerationViewModel {
    
    private var shouldFail = false
    private var mockDelay: TimeInterval = 1.0
    
    override init(imageGenerationService: ImageGenerationServiceProtocol = MockImageGenerationService()) {
        super.init(imageGenerationService: imageGenerationService)
    }
    
    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func setMockDelay(_ delay: TimeInterval) {
        self.mockDelay = delay
    }
    
    override func generateImage() async {
        guard let recipe = testCurrentRecipe else {
            // Use internal method to show error
            await MainActor.run {
                self.errorMessage = "No recipe selected"
                self.showingError = true
                self.isGenerating = false
                self.generationProgress = 0.0
            }
            return
        }
        
        if shouldFail {
            await MainActor.run {
                self.errorMessage = "Mock failure"
                self.showingError = true
                self.isGenerating = false
                self.generationProgress = 0.0
            }
            return
        }
        
        // Simulate generation
        isGenerating = true
        generationProgress = 0.0
        
        // Simulate progress
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay * 100_000_000 / 10))
            generationProgress = Double(i) / 10.0
        }
        
        // Create mock image
        let mockImage = createMockImage(for: recipe)
        generatedImage = mockImage
        isGenerating = false
        generationProgress = 1.0
        
        await MainActor.run {
            self.successMessage = "Mock image generated successfully!"
            self.showingSuccess = true
        }
    }
    
    private func createMockImage(for recipe: Recipe) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: 512, height: 512))
            
            // Background
            UIColor.systemGray6.setFill()
            context.fill(rect)
            
            // Recipe name
            let text = recipe.name
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.systemGray
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            
            // Style indicator
            let styleText = selectedStyle.rawValue
            let styleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.systemGray2
            ]
            
            let styleSize = styleText.size(withAttributes: styleAttributes)
            let styleRect = CGRect(
                x: (rect.width - styleSize.width) / 2,
                y: rect.height - styleSize.height - 40,
                width: styleSize.width,
                height: styleSize.height
            )
            
            styleText.draw(in: styleRect, withAttributes: styleAttributes)
            
            // Mock indicator
            let mockText = "MOCK IMAGE"
            let mockAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.systemOrange
            ]
            
            let mockSize = mockText.size(withAttributes: mockAttributes)
            let mockRect = CGRect(
                x: (rect.width - mockSize.width) / 2,
                y: 20,
                width: mockSize.width,
                height: mockSize.height
            )
            
            mockText.draw(in: mockRect, withAttributes: mockAttributes)
        }
    }
}
