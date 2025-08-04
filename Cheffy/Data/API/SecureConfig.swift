import Foundation
import KeychainAccess

class SecureConfig {
    static let shared = SecureConfig()
    
    private let keychain = Keychain(service: "com.cheffy.app")
    private let secureConfigPath = Bundle.main.path(forResource: "SecureConfig", ofType: "plist")
    
    private init() {}
    
    // MARK: - API Keys
    var geminiAPIKey: String {
        // First try keychain (most secure)
        if let keychainKey = try? keychain.get("gemini_api_key"), !keychainKey.isEmpty {
            return keychainKey
        }
        
        // Fallback to SecureConfig.plist (for development)
        if let configPath = secureConfigPath,
           let config = NSDictionary(contentsOfFile: configPath),
           let apiKey = config["GEMINI_API_KEY"] as? String,
           apiKey != "YOUR_GEMINI_API_KEY_HERE" {
            // Store in keychain for future use
            try? keychain.set(apiKey, key: "gemini_api_key")
            return apiKey
        }
        
        // Last resort - environment variable
        return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    }
    
    var stripePublishableKey: String {
        if let keychainKey = try? keychain.get("stripe_publishable_key"), !keychainKey.isEmpty {
            return keychainKey
        }
        
        if let configPath = secureConfigPath,
           let config = NSDictionary(contentsOfFile: configPath),
           let apiKey = config["STRIPE_PUBLISHABLE_KEY"] as? String,
           apiKey != "YOUR_STRIPE_PUBLISHABLE_KEY_HERE" {
            try? keychain.set(apiKey, key: "stripe_publishable_key")
            return apiKey
        }
        
        return ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"] ?? ""
    }
    
    // MARK: - Security Methods
    func setGeminiAPIKey(_ key: String) {
        try? keychain.set(key, key: "gemini_api_key")
    }
    
    func setStripePublishableKey(_ key: String) {
        try? keychain.set(key, key: "stripe_publishable_key")
    }
    
    func clearAllKeys() {
        try? keychain.remove("gemini_api_key")
        try? keychain.remove("stripe_publishable_key")
    }
    
    // MARK: - Validation
    var hasValidGeminiKey: Bool {
        return !geminiAPIKey.isEmpty && geminiAPIKey != "YOUR_GEMINI_API_KEY_HERE"
    }
    
    var hasValidStripeKey: Bool {
        return !stripePublishableKey.isEmpty && stripePublishableKey != "YOUR_STRIPE_PUBLISHABLE_KEY_HERE"
    }
} 