# 🍳 Cheffy - Michelin-Level Recipe App

A sophisticated iOS app that generates Michelin-star quality recipes using OpenAI's GPT-4o and DALL-E 3, featuring voice navigation, step-by-step cooking mode, and PRO subscription features.

## 🚀 Features

### Core Features
- **AI-Powered Recipe Generation**: Create restaurant-quality recipes using OpenAI GPT-4o
- **Multi-Cuisine Support**: 20+ world cuisines including French, Italian, Japanese, Indian, and more
- **Voice Input & Navigation**: Speech recognition for hands-free recipe generation
- **Step-by-Step Cooking Mode**: Visual cooking guide with voice narration and timers
- **Offline Recipe Storage**: Save favorites locally with Core Data
- **Dietary Restrictions**: Support for vegetarian, vegan, gluten-free, and more

### PRO Features (Subscription)
- **Unlimited Recipe Generation**: No daily limits
- **High-Resolution Images**: DALL-E 3 generated cooking step images
- **Advanced Meal Planning**: Weekly meal planning and shopping lists
- **Premium Wine Pairings**: Expert sommelier recommendations
- **Priority Support**: Direct access to customer support

## 🏗️ Architecture

### Clean Architecture / MVVM Pattern
```
Cheffy/
├── Domain/           # Business logic and entities
│   ├── Entities/     # Data models (Recipe, Ingredient, etc.)
│   └── UseCases/     # Business logic managers
├── Data/             # Data layer
│   └── API/          # External API clients
├── Presentation/     # UI layer
│   └── Views/        # SwiftUI views
└── Resources/        # Assets and localization
```

### Key Components
- **RecipeManager**: Orchestrates recipe generation and favorites
- **SubscriptionManager**: Handles PRO subscription logic
- **VoiceManager**: Speech recognition and synthesis
- **OpenAIClient**: GPT-4o and DALL-E 3 integration
- **StripeManager**: Payment processing and subscriptions

## 🛠️ Technology Stack

- **Swift 5.9** + **SwiftUI 4**
- **Combine** for reactive programming
- **Core Data** for local persistence
- **OpenAI API** (GPT-4o, DALL-E 3)
- **Stripe iOS SDK** for payments
- **KeychainAccess** for secure storage
- **SDWebImageSwiftUI** for image loading
- **Speech Framework** for voice features

## 📱 Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- OpenAI API Key
- Stripe Account (for payments)

## 🚀 Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/cheffy-ios.git
cd cheffy-ios
```

### 2. Install Dependencies
The project uses Swift Package Manager. Dependencies will be automatically resolved when you open the project in Xcode.

### 3. Configure API Keys
1. Get your OpenAI API key from [OpenAI Platform](https://platform.openai.com/)
2. Get your Stripe publishable key from [Stripe Dashboard](https://dashboard.stripe.com/)
3. Add the keys to your environment or configure them in the app settings

### 4. Build and Run
```bash
# Using xcodegen (recommended)
xcodegen generate
open Cheffy.xcodeproj

# Or open directly in Xcode
open Cheffy.xcodeproj
```

### 5. Run on Simulator
```bash
xcodebuild -project Cheffy.xcodeproj -scheme Cheffy -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build
```

## 🔧 Configuration

### OpenAI Configuration
Update the OpenAI API key in `CheffyApp.swift`:
```swift
// Replace with your actual OpenAI API key
private func setupOpenAI() {
    // Configure OpenAI client
}
```

### Stripe Configuration
Update the Stripe publishable key in `CheffyApp.swift`:
```swift
private func setupStripe() {
    StripeAPI.defaultPublishableKey = "pk_test_your_stripe_publishable_key_here"
}
```

## 📁 Project Structure

```
Cheffy/
├── CheffyApp.swift              # App entry point
├── ContentView.swift            # Main tab navigation
├── Domain/
│   ├── Entities/
│   │   └── Recipe.swift         # Recipe data model
│   └── UseCases/
│       ├── RecipeManager.swift  # Recipe business logic
│       └── SubscriptionManager.swift # Subscription logic
├── Data/
│   └── API/
│       └── VoiceManager.swift   # Speech recognition
├── Presentation/
│   └── Views/
│       ├── RecipeGeneratorView.swift
│       ├── FavoritesView.swift
│       ├── CookingModeView.swift
│       ├── SettingsView.swift
│       └── PaywallView.swift
├── Assets.xcassets/             # App icons and images
└── Preview Content/             # SwiftUI previews
```

## 🧪 Testing

Run tests using Xcode or command line:
```bash
xcodebuild -project Cheffy.xcodeproj -scheme Cheffy -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test
```

## 📦 Dependencies

### Swift Package Manager Dependencies
- **KeychainAccess** (4.2.2+) - Secure key storage
- **Stripe** (23.0.0+) - Payment processing
- **SDWebImageSwiftUI** (2.0.0+) - Image loading and caching

## 🔒 Security

- API keys stored securely in iOS Keychain
- No sensitive data in source code
- HTTPS for all network requests
- Secure payment processing via Stripe

## 🌐 Localization

The app supports multiple languages through `Localizable.strings` files. To add a new language:

1. Add the language in Xcode project settings
2. Create `Localizable.strings` for the new language
3. Translate all user-facing strings

## 🚀 Deployment

### App Store Deployment
1. Configure signing and capabilities in Xcode
2. Set up App Store Connect
3. Archive and upload via Xcode or fastlane

### Fastlane Setup (Optional)
```bash
# Install fastlane
gem install fastlane

# Initialize fastlane
fastlane init

# Configure lanes for building and deploying
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- OpenAI for GPT-4o and DALL-E 3 APIs
- Stripe for payment processing
- Apple for SwiftUI and iOS frameworks
- The open-source community for various dependencies

## 📞 Support

For support, email support@cheffy.app or create an issue in this repository.

---

**Made with ❤️ for food lovers everywhere** 