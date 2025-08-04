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
        // Use secure configuration manager
        let secureConfig = SecureConfigManager.shared
        let apiKey = secureConfig.geminiAPIKey
        
        if !apiKey.isEmpty {
            recipeManager.openAIClient.setAPIKey(apiKey)
            logger.security("Gemini API configured securely")
            
            // Perform security audit
            let audit = secureConfig.performSecurityAudit()
            if !audit.isSecure {
                logger.warning("Security audit issues: \(audit.description)")
            }
        } else {
            logger.error("No valid API key found - app functionality will be limited")
        }
        
        // Log API key status (privacy-compliant)
        os_log("Gemini API configured - hasKey: %{public}@", log: .default, type: .info, secureConfig.hasValidAPIKey ? "true" : "false")
    }
} 