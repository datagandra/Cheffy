import Foundation
import UIKit
import os.log

// MARK: - Image Generation Service Protocol
protocol ImageGenerationServiceProtocol {
    func generateImage(
        for recipe: Recipe,
        style: ImageStyle,
        size: ImageSize
    ) async throws -> UIImage
    
    func getCachedImage(for recipe: Recipe, style: ImageStyle) -> UIImage?
    func clearCache()
    func getCacheStatistics() -> [String: Any]
}

// MARK: - Image Generation Service
@MainActor
class ImageGenerationService: ObservableObject, @preconcurrency ImageGenerationServiceProtocol {
    
    // MARK: - Dependencies
    private let networkClient: NetworkClient
    private let secureConfigManager: SecureConfigManager
    private let logger: Logger
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var lastGeneratedImage: UIImage?
    @Published var lastError: ImageGenerationError?
    
    // MARK: - Private Properties
    private let imageCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // MARK: - Constants
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    private let cacheExpirationDays = 30
    
    // MARK: - Initialization
    init(
        networkClient: NetworkClient = NetworkClientImpl(),
        secureConfigManager: SecureConfigManager = SecureConfigManager.shared
    ) {
        self.networkClient = networkClient
        self.secureConfigManager = secureConfigManager
        self.logger = Logger.shared
        
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheDirectory = documentsPath.appendingPathComponent("GeneratedImages")
        
        setupCacheDirectory()
        setupImageCache()
        loadCachedImages()
        
        logger.info("ImageGenerationService initialized with cache directory: \(cacheDirectory.path)")
    }
    
    // MARK: - Public Methods
    
    /// Generates an AI image for a recipe
    func generateImage(
        for recipe: Recipe,
        style: ImageStyle = .photorealistic,
        size: ImageSize = .medium
    ) async throws -> UIImage {
        
        // Check cache first
        if let cachedImage = getCachedImage(for: recipe, style: style) {
            logger.info("Using cached image for recipe: \(recipe.name)")
            await MainActor.run {
                self.lastGeneratedImage = cachedImage
                self.lastError = nil
            }
            return cachedImage
        }
        
        // Start generation
        await MainActor.run {
            self.isGenerating = true
            self.generationProgress = 0.0
            self.lastError = nil
        }
        
        do {
            logger.info("Generating image for recipe: \(recipe.name) with style: \(style.rawValue)")
            
            // Generate prompt for the recipe
            let prompt = generateImagePrompt(for: recipe, style: style)
            
            // Get API configuration
            let apiConfig = try await getAPIConfiguration()
            
            // Generate image
            let image = try await generateImageWithAPI(
                prompt: prompt,
                style: style,
                size: size,
                apiConfig: apiConfig
            )
            
            // Cache the generated image
            await cacheImage(image, for: recipe, style: style)
            
            // Update state
            await MainActor.run {
                self.lastGeneratedImage = image
                self.isGenerating = false
                self.generationProgress = 1.0
            }
            
            logger.info("Successfully generated image for recipe: \(recipe.name)")
            return image
            
        } catch {
            await MainActor.run {
                self.lastError = ImageGenerationError.generationFailed(error.localizedDescription)
                self.isGenerating = false
                self.generationProgress = 0.0
            }
            
            logger.error("Failed to generate image for recipe \(recipe.name): \(error)")
            throw error
        }
    }
    
    // MARK: - Cache Management
    
    /// Retrieves a cached image for a recipe and style
    func getCachedImage(for recipe: Recipe, style: ImageStyle) -> UIImage? {
        let cacheKey = generateCacheKey(for: recipe, style: style)
        
        // Check memory cache first
        if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = loadImageFromDisk(cacheKey: cacheKey) {
            // Store in memory cache for future use
            imageCache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }
        
        return nil
    }
    
    /// Clears all cached images
    func clearCache() {
        // Clear memory cache
        imageCache.removeAllObjects()
        
        // Clear disk cache
        clearDiskCache()
    }
    
    /// Returns cache statistics
    func getCacheStatistics() -> [String: Any] {
        let memoryCacheCount = imageCache.totalCostLimit
        let diskCacheSize = getDiskCacheSize()
        
        return [
            "memoryCacheCount": memoryCacheCount,
            "diskCacheSize": diskCacheSize,
            "totalCachedImages": getTotalCachedImageCount()
        ]
    }
    
    // MARK: - Private Helper Methods
    
    /// Loads an image from disk cache
    private func loadImageFromDisk(cacheKey: String) -> UIImage? {
        let imageURL = cacheDirectory.appendingPathComponent(cacheKey)
        guard let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image
    }
    
    /// Clears the disk cache
    private func clearDiskCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            try contents.forEach { url in
                try fileManager.removeItem(at: url)
            }
        } catch {
            logger.error("Failed to clear disk cache: \(error)")
        }
    }
    
    /// Gets the total size of disk cache in bytes
    private func getDiskCacheSize() -> Int64 {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            let totalSize = try contents.reduce(Int64(0)) { total, url in
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                return total + Int64(resourceValues.fileSize ?? 0)
            }
            return totalSize
        } catch {
            return 0
        }
    }
    
    /// Gets the total count of cached images
    private func getTotalCachedImageCount() -> Int {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            return 0
        }
    }
    
    // MARK: - Private Methods
    
    /// Generates an image prompt based on recipe and style
    private func generateImagePrompt(for recipe: Recipe, style: ImageStyle) -> String {
        let basePrompt = "Professional food photography of \(recipe.name), \(recipe.cuisine.rawValue) cuisine"
        
        let stylePrompt: String
        switch style {
        case .photorealistic:
            stylePrompt = "highly detailed, photorealistic, professional food photography, natural lighting, shallow depth of field, appetizing presentation"
        case .artistic:
            stylePrompt = "artistic interpretation, creative composition, vibrant colors, modern food styling, magazine quality"
        case .minimalist:
            stylePrompt = "minimalist design, clean composition, simple background, focus on food, elegant presentation"
        case .vintage:
            stylePrompt = "vintage aesthetic, retro styling, warm tones, classic food photography, nostalgic feel"
        }
        
        let ingredients = recipe.ingredients.prefix(5).map { $0.name }.joined(separator: ", ")
        let finalPrompt = "\(basePrompt) with ingredients: \(ingredients). \(stylePrompt). No text, no watermarks, high resolution."
        
        logger.debug("Generated prompt: \(finalPrompt)")
        return finalPrompt
    }
    
    /// Gets API configuration for image generation
    private func getAPIConfiguration() async throws -> APIConfig {
        let apiKey = try await secureConfigManager.getSecureValue(for: "OPENAI_API_KEY") ?? ""
        let baseURL = try await secureConfigManager.getSecureValue(for: "OPENAI_BASE_URL") ?? "https://api.openai.com"
        
        guard !apiKey.isEmpty else {
            throw ImageGenerationError.configurationError("OpenAI API key not found")
        }
        
        return APIConfig(
            apiKey: apiKey,
            baseURL: baseURL
        )
    }
    
    /// Generates image using the configured API
    private func generateImageWithAPI(
        prompt: String,
        style: ImageStyle,
        size: ImageSize,
        apiConfig: APIConfig
    ) async throws -> UIImage {
        
        // Simulate progress updates
        await updateProgress(0.1)
        
        // For now, we'll simulate the API call
        // In a real implementation, you would make an actual network request
        logger.info("Simulating API call for image generation")
        
        await updateProgress(0.3)
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await updateProgress(0.7)
        
        // Create a mock image for demonstration
        let mockImage = createMockImage(for: prompt, style: style, size: size)
        
        await updateProgress(1.0)
        
        return mockImage
    }
    
    /// Updates generation progress
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.generationProgress = progress
        }
    }
    
    /// Caches an image for a recipe
    private func cacheImage(_ image: UIImage, for recipe: Recipe, style: ImageStyle) async {
        let cacheKey = generateCacheKey(for: recipe, style: style)
        
        // Add to memory cache
        imageCache.setObject(image, forKey: cacheKey as NSString)
        
        // Save to disk cache
        await saveImageToDisk(image, withKey: cacheKey)
        
        logger.info("Cached image for recipe: \(recipe.name)")
    }
    
    /// Saves image to disk cache
    private func saveImageToDisk(_ image: UIImage, withKey key: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            logger.error("Failed to convert image to JPEG data")
            return
        }
        
        let imageURL = cacheDirectory.appendingPathComponent(key)
        
        do {
            try imageData.write(to: imageURL)
            logger.debug("Saved image to disk: \(imageURL.path)")
        } catch {
            logger.error("Failed to save image to disk: \(error)")
        }
    }
    
    /// Generates cache key for a recipe and style
    private func generateCacheKey(for recipe: Recipe, style: ImageStyle) -> String {
        let recipeHash = "\(recipe.id.uuidString)_\(recipe.name.hashValue)"
        let styleHash = style.rawValue.hashValue
        return "\(recipeHash)_\(styleHash).jpg"
    }
    
    /// Sets up cache directory
    private func setupCacheDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                logger.info("Created cache directory: \(cacheDirectory.path)")
            } catch {
                logger.error("Failed to create cache directory: \(error)")
            }
        }
    }
    
    /// Sets up image cache configuration
    private func setupImageCache() {
        imageCache.totalCostLimit = maxCacheSize
        imageCache.countLimit = 50
        imageCache.evictsObjectsWithDiscardedContent = true
    }
    
    /// Loads cached images from disk
    private func loadCachedImages() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            logger.info("Found \(contents.count) cached images on disk")
        } catch {
            logger.error("Failed to load cached images: \(error)")
        }
    }
    
    /// Creates a mock image for demonstration purposes
    private func createMockImage(for prompt: String, style: ImageStyle, size: ImageSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size.dimensions)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size.dimensions)
            
            // Background based on style
            let backgroundColor: UIColor
            switch style {
            case .photorealistic:
                backgroundColor = UIColor.systemGray6
            case .artistic:
                backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
            case .minimalist:
                backgroundColor = UIColor.white
            case .vintage:
                backgroundColor = UIColor.systemBrown.withAlphaComponent(0.3)
            }
            
            backgroundColor.setFill()
            context.fill(rect)
            
            // Recipe name (from prompt)
            let text = prompt.components(separatedBy: ",").first ?? "Recipe Image"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.dimensions.width * 0.05, weight: .medium),
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
            let styleText = style.rawValue
            let styleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.dimensions.width * 0.03, weight: .regular),
                .foregroundColor: UIColor.systemGray2
            ]
            
            let styleSize = styleText.size(withAttributes: styleAttributes)
            let styleRect = CGRect(
                x: (rect.width - styleSize.width) / 2,
                y: rect.height - styleSize.height - 20,
                width: styleSize.width,
                height: styleSize.height
            )
            
            styleText.draw(in: styleRect, withAttributes: styleAttributes)
            
            // AI Generated indicator
            let aiText = "AI Generated"
            let aiAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.dimensions.width * 0.025, weight: .bold),
                .foregroundColor: UIColor.systemOrange
            ]
            
            let aiSize = aiText.size(withAttributes: aiAttributes)
            let aiRect = CGRect(
                x: (rect.width - aiSize.width) / 2,
                y: 20,
                width: aiSize.width,
                height: aiSize.height
            )
            
            aiText.draw(in: aiRect, withAttributes: aiAttributes)
        }
    }
}

// MARK: - Supporting Types

/// Image generation styles
enum ImageStyle: String, CaseIterable, Codable {
    case photorealistic = "Photorealistic"
    case artistic = "Artistic"
    case minimalist = "Minimalist"
    case vintage = "Vintage"
    
    var icon: String {
        switch self {
        case .photorealistic: return "camera.fill"
        case .artistic: return "paintbrush.fill"
        case .minimalist: return "rectangle.dashed"
        case .vintage: return "camera.filters"
        }
    }
}

/// Image sizes
enum ImageSize: String, CaseIterable, Codable {
    case small = "256x256"
    case medium = "512x512"
    case large = "1024x1024"
    
    var dimensions: CGSize {
        switch self {
        case .small: return CGSize(width: 256, height: 256)
        case .medium: return CGSize(width: 512, height: 512)
        case .large: return CGSize(width: 1024, height: 1024)
        }
    }
}

/// Image generation errors
enum ImageGenerationError: LocalizedError {
    case generationFailed(String)
    case invalidImageData
    case networkError(String)
    case apiKeyMissing
    case rateLimitExceeded
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return "Image generation failed: \(message)"
        case .invalidImageData:
            return "Invalid image data received"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiKeyMissing:
            return "API key not configured"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

/// API configuration
struct APIConfig {
    let apiKey: String
    let baseURL: String
}

// MARK: - Mock Service for Testing
class MockImageGenerationService: ImageGenerationServiceProtocol, ObservableObject {
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var lastGeneratedImage: UIImage?
    @Published var lastError: ImageGenerationError?
    
    private var shouldFail = false
    private var mockDelay: TimeInterval = 2.0
    
    func setShouldFail(_ shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func setMockDelay(_ delay: TimeInterval) {
        self.mockDelay = delay
    }
    
    func generateImage(
        for recipe: Recipe,
        style: ImageStyle,
        size: ImageSize
    ) async throws -> UIImage {
        isGenerating = true
        generationProgress = 0.0
        
        // Simulate progress
        for i in 1...10 {
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 100_000_000 / 10))
            generationProgress = Double(i) / 10.0
        }
        
        isGenerating = false
        
        if shouldFail {
            throw ImageGenerationError.generationFailed("Mock failure")
        }
        
        // Return a mock image
        let mockImage = createMockImage(for: recipe, style: style, size: size)
        lastGeneratedImage = mockImage
        return mockImage
    }
    
    func getCachedImage(for recipe: Recipe, style: ImageStyle) -> UIImage? {
        return lastGeneratedImage
    }
    
    func clearCache() {
        lastGeneratedImage = nil
    }
    
    func getCacheStatistics() -> [String: Any] {
        return ["mock": true]
    }
    
    private func createMockImage(for recipe: Recipe, style: ImageStyle, size: ImageSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size.dimensions)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size.dimensions)
            
            // Background
            UIColor.systemGray6.setFill()
            context.fill(rect)
            
            // Recipe name
            let text = recipe.name
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
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
            let styleText = style.rawValue
            let styleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.systemGray2
            ]
            
            let styleSize = styleText.size(withAttributes: styleAttributes)
            let styleRect = CGRect(
                x: (rect.width - styleSize.width) / 2,
                y: rect.height - styleSize.height - 20,
                width: styleSize.width,
                height: styleSize.height
            )
            
            styleText.draw(in: styleRect, withAttributes: styleAttributes)
        }
    }
}
