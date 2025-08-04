import Foundation
import Combine

class SubscriptionManager: ObservableObject {
    @Published var isSubscribed = false
    @Published var subscriptionTier: SubscriptionTier = .free
    @Published var daysUntilExpiry = 0
    @Published var canGenerateUnlimitedRecipes = false
    @Published var showPaywall = false
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        loadSubscriptionStatus()
    }
    
    func loadSubscriptionStatus() {
        // Load subscription status from UserDefaults or keychain
        let defaults = UserDefaults.standard
        isSubscribed = defaults.bool(forKey: "isSubscribed")
        daysUntilExpiry = defaults.integer(forKey: "daysUntilExpiry")
        canGenerateUnlimitedRecipes = defaults.bool(forKey: "canGenerateUnlimitedRecipes")
        
        // Set default tier if not set
        if subscriptionTier == .free {
            subscriptionTier = .premium
        }
    }
    
    func checkSubscriptionStatus() {
        loadSubscriptionStatus()
    }
    
    func purchaseSubscription(tier: SubscriptionTier) async -> Bool {
        // Simulate purchase process
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isSubscribed = true
        subscriptionTier = tier
        daysUntilExpiry = 30
        canGenerateUnlimitedRecipes = true
        
        // Save to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(isSubscribed, forKey: "isSubscribed")
        defaults.set(daysUntilExpiry, forKey: "daysUntilExpiry")
        defaults.set(canGenerateUnlimitedRecipes, forKey: "canGenerateUnlimitedRecipes")
        
        return true
    }
    
    func restorePurchases() async -> Bool {
        // Simulate restore process
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Check if user has valid subscription
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "isSubscribed") {
            isSubscribed = true
            subscriptionTier = .premium
            daysUntilExpiry = defaults.integer(forKey: "daysUntilExpiry")
            canGenerateUnlimitedRecipes = true
            return true
        }
        
        return false
    }
    
    func cancelSubscription() {
        isSubscribed = false
        subscriptionTier = .free
        daysUntilExpiry = 0
        canGenerateUnlimitedRecipes = false
        
        // Save to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "isSubscribed")
        defaults.set(0, forKey: "daysUntilExpiry")
        defaults.set(false, forKey: "canGenerateUnlimitedRecipes")
    }
    
    func getRemainingFreeGenerations() -> Int {
        return 5 // Default free generations
    }
} 