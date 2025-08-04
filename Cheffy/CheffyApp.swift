import SwiftUI
import Stripe
import KeychainAccess
import os.log

@main
struct CheffyApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var recipeManager = RecipeManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var userManager = UserManager()

    var body: some Scene {
        WindowGroup {
            if userManager.isOnboarding {
                OnboardingView()
                    .environmentObject(userManager)
                    .environmentObject(subscriptionManager)
                    .environmentObject(recipeManager)
                    .environmentObject(voiceManager)
            } else {
                ContentView()
                    .environmentObject(userManager)
                    .environmentObject(subscriptionManager)
                    .environmentObject(recipeManager)
                    .environmentObject(voiceManager)
                    .onAppear {
                        setupStripe()
                        setupGemini()
                        userManager.updateLastActive()
                    }
            }
        }
    }

    private func setupStripe() {
        StripeAPI.defaultPublishableKey = "pk_test_your_stripe_publishable_key_here"
    }
    
    private func setupGemini() {
        // Use environment variable or secure configuration
        let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        recipeManager.openAIClient.setAPIKey(apiKey)
        
        // Also save to keychain for persistence
        let keychain = Keychain(service: "com.cheffy.app")
        try? keychain.set(apiKey, key: "gemini_api_key")
        
        // Log API key status (privacy-compliant)
        os_log("Gemini API configured - hasKey: %{public}@", log: .default, type: .info, recipeManager.openAIClient.hasAPIKey() ? "true" : "false")
    }
} 