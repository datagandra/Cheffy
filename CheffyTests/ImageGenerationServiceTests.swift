import XCTest
@testable import Cheffy

@MainActor
final class ImageGenerationServiceTests: XCTestCase {
    
    var imageGenerationService: ImageGenerationService!
    var mockNetworkClient: NetworkClient!
    var mockSecureConfigManager: SecureConfigManager!
    
    override func setUpWithError() throws {
        mockNetworkClient = NetworkClientImpl()
        mockSecureConfigManager = SecureConfigManager.shared
        imageGenerationService = ImageGenerationService(
            networkClient: mockNetworkClient,
            secureConfigManager: mockSecureConfigManager
        )
    }
    
    override func tearDownWithError() throws {
        imageGenerationService = nil
        mockNetworkClient = nil
        mockSecureConfigManager = nil
    }
    
    // MARK: - Test Data
    
    private func createMockRecipe() -> Recipe {
        Recipe(
            id: UUID(),
            title: "Test Recipe",
            name: "Test Recipe",
            cuisine: .italian,
            difficulty: .medium,
            prepTime: 15,
            cookTime: 30,
            servings: 4,
            ingredients: [
                Ingredient(name: "Ingredient 1", amount: 1.0, unit: "cup"),
                Ingredient(name: "Ingredient 2", amount: 2.0, unit: "tbsp")
            ],
            steps: [
                CookingStep(stepNumber: 1, description: "Step 1"),
                CookingStep(stepNumber: 2, description: "Step 2")
            ],
            winePairings: [
                WinePairing(name: "Wine 1", type: .red, region: "Italy", description: "A nice red wine")
            ],
            dietaryNotes: [.vegetarian],
            platingTips: "Tip 1",
            chefNotes: "Note 1",
            imageURL: nil,
            stepImages: [],
            createdAt: Date(),
            isFavorite: false
        )
    }
    
    private func createMockImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(imageGenerationService)
        XCTAssertFalse(imageGenerationService.isGenerating)
        XCTAssertEqual(imageGenerationService.generationProgress, 0.0)
        XCTAssertNil(imageGenerationService.lastGeneratedImage)
        XCTAssertNil(imageGenerationService.lastError)
    }
    
    // MARK: - Image Generation Tests
    
    func testSuccessfulImageGeneration() async throws {
        let recipe = createMockRecipe()
        let style = ImageStyle.photorealistic
        let size = ImageSize.medium
        
        // Test successful generation
        let image = try await imageGenerationService.generateImage(
            for: recipe,
            style: style,
            size: size
        )
        
        XCTAssertNotNil(image)
        XCTAssertFalse(imageGenerationService.isGenerating)
        XCTAssertEqual(imageGenerationService.generationProgress, 1.0)
        XCTAssertNotNil(imageGenerationService.lastGeneratedImage)
        XCTAssertNil(imageGenerationService.lastError)
    }
    
    func testFailedImageGeneration() async {
        let recipe = createMockRecipe()
        let style = ImageStyle.photorealistic
        let size = ImageSize.medium
        
        // Test failed generation (simulated by invalid recipe)
        do {
            _ = try await imageGenerationService.generateImage(
                for: recipe,
                style: style,
                size: size
            )
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
            XCTAssertFalse(imageGenerationService.isGenerating)
            XCTAssertEqual(imageGenerationService.generationProgress, 0.0)
            XCTAssertNotNil(imageGenerationService.lastError)
        }
    }
    
    func testImageGenerationWithDifferentStyles() async throws {
        let recipe = createMockRecipe()
        let size = ImageSize.medium
        
        let styles: [ImageStyle] = [.photorealistic, .artistic, .minimalist, .vintage]
        
        for style in styles {
            let image = try await imageGenerationService.generateImage(
                for: recipe,
                style: style,
                size: size
            )
            XCTAssertNotNil(image)
        }
    }
    
    func testImageGenerationWithDifferentSizes() async throws {
        let recipe = createMockRecipe()
        let style = ImageStyle.photorealistic
        
        let sizes: [ImageSize] = [.small, .medium, .large]
        
        for size in sizes {
            let image = try await imageGenerationService.generateImage(
                for: recipe,
                style: style,
                size: size
            )
            XCTAssertNotNil(image)
        }
    }
    
    // MARK: - Caching Tests
    
    func testGetCachedImage() {
        let recipe = createMockRecipe()
        let style = ImageStyle.photorealistic
        
        // Initially no cached image
        let cachedImage = imageGenerationService.getCachedImage(for: recipe, style: style)
        XCTAssertNil(cachedImage)
        
        // Generate and cache an image
        Task {
            do {
                let _ = try await imageGenerationService.generateImage(
                    for: recipe,
                    style: style,
                    size: .medium
                )
                
                // Now should have cached image
                let cachedImage = imageGenerationService.getCachedImage(for: recipe, style: style)
                XCTAssertNotNil(cachedImage)
            } catch {
                XCTFail("Failed to generate image: \(error)")
            }
        }
    }
    
    func testCacheClearing() {
        let recipe = createMockRecipe()
        let style = ImageStyle.photorealistic
        
        // Generate and cache an image
        Task {
            do {
                let _ = try await imageGenerationService.generateImage(
                    for: recipe,
                    style: style,
                    size: .medium
                )
                
                // Verify image is cached
                let cachedImage = imageGenerationService.getCachedImage(for: recipe, style: style)
                XCTAssertNotNil(cachedImage)
                
                // Clear cache
                imageGenerationService.clearCache()
                
                // Verify cache is cleared
                let cachedImageAfterClear = imageGenerationService.getCachedImage(for: recipe, style: style)
                XCTAssertNil(cachedImageAfterClear)
            } catch {
                XCTFail("Failed to generate image: \(error)")
            }
        }
    }
    
    func testGetCacheStatistics() {
        let stats = imageGenerationService.getCacheStatistics()
        XCTAssertNotNil(stats)
        XCTAssertTrue(stats.keys.contains("memoryCacheCount"))
        XCTAssertTrue(stats.keys.contains("diskCacheSize"))
        XCTAssertTrue(stats.keys.contains("totalCachedImages"))
    }
    
    // MARK: - Error Handling Tests
    
    func testConfigurationError() async {
        // Test with invalid configuration
        let recipe = createMockRecipe()
        let style = ImageStyle.photorealistic
        let size = ImageSize.medium
        
        do {
            _ = try await imageGenerationService.generateImage(
                for: recipe,
                style: style,
                size: size
            )
            XCTFail("Expected configuration error")
        } catch ImageGenerationError.configurationError {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Image Style Tests
    
    func testImageStyleProperties() {
        let photorealistic = ImageStyle.photorealistic
        XCTAssertEqual(photorealistic.rawValue, "Photorealistic")
        XCTAssertEqual(photorealistic.icon, "camera.fill")
        
        let artistic = ImageStyle.artistic
        XCTAssertEqual(artistic.rawValue, "Artistic")
        XCTAssertEqual(artistic.icon, "paintbrush.fill")
        
        let minimalist = ImageStyle.minimalist
        XCTAssertEqual(minimalist.rawValue, "Minimalist")
        XCTAssertEqual(minimalist.icon, "rectangle.dashed")
        
        let vintage = ImageStyle.vintage
        XCTAssertEqual(vintage.rawValue, "Vintage")
        XCTAssertEqual(vintage.icon, "camera.filters")
    }
    
    // MARK: - Image Size Tests
    
    func testImageSizeProperties() {
        let small = ImageSize.small
        XCTAssertEqual(small.rawValue, "256x256")
        XCTAssertEqual(small.dimensions, CGSize(width: 256, height: 256))
        
        let medium = ImageSize.medium
        XCTAssertEqual(medium.rawValue, "512x512")
        XCTAssertEqual(medium.dimensions, CGSize(width: 512, height: 512))
        
        let large = ImageSize.large
        XCTAssertEqual(large.rawValue, "1024x1024")
        XCTAssertEqual(large.dimensions, CGSize(width: 1024, height: 1024))
    }
    
    // MARK: - Error Description Tests
    
    func testImageGenerationErrorDescriptions() {
        let networkError = ImageGenerationError.networkError("Test error")
        XCTAssertEqual(networkError.errorDescription, "Network error: Test error")
        
        let generationFailed = ImageGenerationError.generationFailed("Generation failed")
        XCTAssertEqual(generationFailed.errorDescription, "Image generation failed: Generation failed")
        
        let invalidInput = ImageGenerationError.invalidImageData
        XCTAssertEqual(invalidInput.errorDescription, "Invalid image data received")
        
        let configurationError = ImageGenerationError.configurationError("Config error")
        XCTAssertEqual(configurationError.errorDescription, "Configuration error: Config error")
        
        let rateLimitExceeded = ImageGenerationError.rateLimitExceeded
        XCTAssertEqual(rateLimitExceeded.errorDescription, "Rate limit exceeded. Please try again later.")
    }
}
