# 🎨 AI-Powered Image Generation Feature

## Overview

The AI-powered image generation feature allows users to create stunning, custom images for their recipes using advanced AI models. This feature integrates seamlessly with the existing Cheffy app architecture and provides users with professional-quality food photography without leaving the app.

## ✨ Features

### Core Functionality
- **AI Image Generation**: Generate images using OpenAI's DALL-E or similar models
- **Multiple Styles**: Choose from 4 different artistic styles
- **Customizable Sizes**: Generate images in 3 different resolutions
- **Smart Caching**: Intelligent caching system to avoid redundant API calls
- **Offline Support**: Generated images are stored locally for offline access

### Image Styles
1. **Photorealistic** - High-quality, realistic food photography
2. **Artistic** - Creative, magazine-style food art
3. **Minimalist** - Clean, simple compositions
4. **Vintage** - Retro, nostalgic aesthetic

### Image Sizes
- **Small**: 256×256 pixels (fast generation, low cost)
- **Medium**: 512×512 pixels (balanced quality and cost)
- **Large**: 1024×1024 pixels (highest quality, higher cost)

## 🏗️ Architecture

### MVVM Pattern
The feature follows the MVVM (Model-View-ViewModel) architecture pattern:

```
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────┐
│   View Layer    │◄──►│   ViewModel Layer    │◄──►│  Service Layer  │
│                 │    │                      │    │                 │
│ ImageGeneration │    │ ImageGeneration      │    │ ImageGeneration │
│ View            │    │ ViewModel            │    │ Service         │
└─────────────────┘    └──────────────────────┘    └─────────────────┘
```

### Service Layer
- **`ImageGenerationService`**: Core service handling AI image generation
- **`NetworkClient`**: Handles API communication
- **`SecureConfigManager`**: Manages API keys securely

### ViewModel Layer
- **`ImageGenerationViewModel`**: Manages UI state and business logic
- **Dependency Injection**: Services are injected for testability

### View Layer
- **`ImageGenerationView`**: Main UI for image generation
- **`StylePickerView`**: Style selection interface
- **`SizePickerView`**: Size selection interface

## 🔧 Technical Implementation

### Dependencies
```swift
import Foundation
import UIKit
import Photos
import os.log
```

### Key Components

#### 1. ImageGenerationService
```swift
@MainActor
class ImageGenerationService: ObservableObject, ImageGenerationServiceProtocol {
    // Core image generation logic
    // Caching and persistence
    // Network communication
}
```

#### 2. ImageGenerationViewModel
```swift
@MainActor
class ImageGenerationViewModel: ObservableObject {
    // UI state management
    // Business logic coordination
    // User interaction handling
}
```

#### 3. ImageGenerationView
```swift
struct ImageGenerationView: View {
    // Main UI components
    // Style and size selection
    // Image display and actions
}
```

### Caching System

#### Memory Cache
- Uses `NSCache` for fast access to recently generated images
- Configurable size limits (100MB default)
- Automatic eviction of least-used images

#### Disk Cache
- Persistent storage using `FileManager`
- Organized by recipe ID and style
- Automatic cleanup of expired images

#### Cache Key Generation
```swift
private func generateCacheKey(for recipe: Recipe, style: ImageStyle) -> String {
    let recipeHash = "\(recipe.id.uuidString)_\(recipe.name.hashValue)"
    let styleHash = style.rawValue.hashValue
    return "\(recipeHash)_\(styleHash).jpg"
}
```

### Network Layer

#### API Integration
- Supports OpenAI Images API
- Configurable base URLs
- Secure API key management
- Automatic retry logic

#### Request Structure
```swift
struct ImageGenerationRequest: Codable {
    let prompt: String
    let size: String
    let quality: String
    let style: String
}
```

#### Error Handling
```swift
enum ImageGenerationError: LocalizedError {
    case generationFailed(String)
    case invalidImageData
    case networkError(String)
    case apiKeyMissing
    case rateLimitExceeded
}
```

## 🎯 User Experience

### Workflow
1. **Recipe Selection**: User navigates to a recipe detail view
2. **Style Selection**: Choose from 4 artistic styles
3. **Size Selection**: Select desired image resolution
4. **Generation**: Tap "Generate Image" button
5. **Progress Tracking**: Real-time progress indicator
6. **Result Display**: View generated image with options
7. **Actions**: Save, share, or regenerate image

### UI Components

#### Generation Controls
- Style picker with visual icons
- Size selector with dimensions
- Generate button with dynamic states
- Progress indicator during generation

#### Image Display
- High-quality image preview
- Style and size information
- Quick action buttons (share, save)
- Regenerate option for new styles

#### Accessibility Features
- VoiceOver labels for all interactive elements
- Dynamic Type support
- High contrast mode compatibility
- Semantic accessibility traits

## 🔐 Security & Privacy

### API Key Management
- Secure storage using iOS Keychain
- No hardcoded credentials
- Automatic key rotation support
- Access control and permissions

### Data Privacy
- Generated images stored locally
- No user data transmitted to third parties
- Optional cloud backup (user-controlled)
- GDPR compliance considerations

### Network Security
- HTTPS-only communication
- Certificate pinning support
- Request validation and sanitization
- Rate limiting and abuse prevention

## 📱 Integration Points

### Recipe Views
- **RecipeLandingPageView**: Full-featured image generation
- **RecipeDetailView**: Quick image generation access
- **CookingModeView**: Contextual image generation

### Navigation
- Modal presentation for full-screen experience
- Deep linking support for generated images
- Share sheet integration for social media

### State Management
- Integration with existing app state
- Recipe context preservation
- User preference persistence
- Offline mode support

## 🧪 Testing

### Unit Tests
- Service layer testing with mocks
- ViewModel business logic validation
- Error handling and edge cases
- Cache management verification

### Integration Tests
- End-to-end image generation flow
- Network layer integration
- Cache persistence testing
- UI state synchronization

### Mock Services
```swift
class MockImageGenerationService: ImageGenerationServiceProtocol {
    // Configurable mock responses
    // Test scenario simulation
    // Performance testing support
}
```

## 🚀 Performance Optimization

### Image Processing
- Efficient JPEG compression (80% quality)
- Lazy loading of cached images
- Background image processing
- Memory usage optimization

### Caching Strategy
- Multi-level caching (memory + disk)
- Intelligent cache eviction
- Background cache cleanup
- Size-based cache limits

### Network Optimization
- Request batching and queuing
- Automatic retry with exponential backoff
- Connection pooling
- Response compression

## 🔮 Future Enhancements

### Planned Features
- **Local AI Models**: Core ML integration for offline generation
- **Style Transfer**: Apply existing image styles to new generations
- **Batch Generation**: Generate multiple images simultaneously
- **Custom Prompts**: User-defined generation parameters

### Scalability Improvements
- **CDN Integration**: Global image delivery
- **Multi-Provider Support**: Multiple AI service providers
- **Advanced Caching**: Redis or similar distributed cache
- **Analytics**: Usage tracking and optimization

### Platform Expansion
- **macOS Support**: Desktop app integration
- **watchOS**: Quick image generation on Apple Watch
- **Web Platform**: Browser-based generation
- **API Access**: Third-party developer access

## 📋 Configuration

### Environment Variables
```bash
OPENAI_API_KEY=your_api_key_here
OPENAI_BASE_URL=https://api.openai.com
```

### App Configuration
```swift
// In your app's configuration
let imageGenerationService = ImageGenerationService(
    networkClient: NetworkClient.shared,
    secureConfigManager: SecureConfigManager.shared
)
```

### Cache Settings
```swift
// Customizable cache limits
private let maxCacheSize = 100 * 1024 * 1024 // 100MB
private let cacheExpirationDays = 30
```

## 🐛 Troubleshooting

### Common Issues

#### API Key Errors
- Verify API key is correctly configured
- Check API key permissions and quotas
- Ensure network connectivity

#### Generation Failures
- Review error logs for specific issues
- Check API service status
- Verify request parameters

#### Cache Issues
- Clear app cache if needed
- Check available disk space
- Verify file permissions

### Debug Information
```swift
// Get cache statistics
let stats = imageGenerationService.getCacheStatistics()
print("Cache Statistics: \(stats)")

// Check service state
print("Is Generating: \(imageGenerationService.isGenerating)")
print("Progress: \(imageGenerationService.generationProgress)")
```

## 📚 API Reference

### ImageGenerationService
```swift
// Generate image
func generateImage(
    for recipe: Recipe,
    style: ImageStyle,
    size: ImageSize
) async throws -> UIImage

// Get cached image
func getCachedImage(for recipe: Recipe, style: ImageStyle) -> UIImage?

// Clear cache
func clearCache()

// Get statistics
func getCacheStatistics() -> [String: Any]
```

### ImageGenerationViewModel
```swift
// Generate image
func generateImage() async

// Change style
func changeStyle(_ style: ImageStyle)

// Change size
func changeSize(_ size: ImageSize)

// Save to Photos
func saveToPhotos() async

// Share image
func shareImage()
```

## 🤝 Contributing

### Development Setup
1. Clone the repository
2. Install Xcode 15.0+
3. Configure API keys in SecureConfig
4. Run tests to verify setup

### Code Style
- Follow Swift style guide
- Use SwiftLint for consistency
- Document public APIs
- Write comprehensive tests

### Testing Guidelines
- Maintain 90%+ test coverage
- Mock external dependencies
- Test error scenarios
- Validate UI interactions

---

**Note**: This feature requires an active OpenAI API key or similar AI image generation service. Please ensure you have the necessary credentials and understand the associated costs before implementation.
