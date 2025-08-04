import Foundation
import KeychainAccess

class UserManager: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var hasCompletedOnboarding: Bool = false
    @Published var isOnboarding: Bool = false
    
    private let keychain = Keychain(service: "com.cheffy.app")
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadUserProfile()
        checkOnboardingStatus()
    }
    
    // MARK: - User Profile Management
    
    func createUserProfile(_ profile: UserProfile) {
        currentUser = profile
        saveUserProfile()
        hasCompletedOnboarding = true
        isOnboarding = false
    }
    
    func updateUserProfile(_ profile: UserProfile) {
        currentUser = profile
        saveUserProfile()
    }
    
    func deleteUserProfile() {
        currentUser = nil
        hasCompletedOnboarding = false
        isOnboarding = true
        
        // Clear saved data
        userDefaults.removeObject(forKey: "user_profile")
        userDefaults.removeObject(forKey: "has_completed_onboarding")
        
        // Clear keychain data
        try? keychain.remove("user_profile")
    }
    
    // MARK: - Onboarding Management
    
    func startOnboarding() {
        isOnboarding = true
        hasCompletedOnboarding = false
    }
    
    func completeOnboarding() {
        isOnboarding = false
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: "has_completed_onboarding")
    }
    
    func resetOnboarding() {
        isOnboarding = true
        hasCompletedOnboarding = false
        userDefaults.set(false, forKey: "has_completed_onboarding")
    }
    
    // MARK: - Data Persistence
    
    private func saveUserProfile() {
        guard let user = currentUser else { return }
        
        do {
            let data = try JSONEncoder().encode(user)
            userDefaults.set(data, forKey: "user_profile")
            try keychain.set(data, key: "user_profile")
        } catch {
            logger.error("Error saving user profile: \(error)")
        }
    }
    
    private func loadUserProfile() {
        // Try to load from UserDefaults first
        if let data = userDefaults.data(forKey: "user_profile") {
            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                currentUser = profile
                return
            } catch {
                logger.error("Error loading user profile from UserDefaults: \(error)")
            }
        }
        
        // Try to load from Keychain as backup
        if let data = try? keychain.getData("user_profile") {
            do {
                let profile = try JSONDecoder().decode(UserProfile.self, from: data)
                currentUser = profile
                return
            } catch {
                logger.error("Error loading user profile from Keychain: \(error)")
            }
        }
        
        // No saved profile found
        currentUser = nil
    }
    
    private func checkOnboardingStatus() {
        hasCompletedOnboarding = userDefaults.bool(forKey: "has_completed_onboarding")
        
        // If no user profile exists, start onboarding
        if currentUser == nil {
            isOnboarding = true
        }
    }
    
    // MARK: - User Activity
    
    func updateLastActive() {
        guard var user = currentUser else { return }
        user.lastActive = Date()
        updateUserProfile(user)
    }
    
    // MARK: - Profile Validation
    
    func isProfileComplete() -> Bool {
        guard let user = currentUser else { return false }
        
        return !user.name.isEmpty &&
               !user.email.isEmpty &&
               !user.favoriteCuisines.isEmpty &&
               !user.cookingGoals.isEmpty &&
               user.householdSize > 0
    }
    
    // MARK: - Recommendations
    
    func getRecommendedCuisines() -> [Cuisine] {
        guard let user = currentUser else { return Cuisine.allCases }
        
        // Return user's favorite cuisines, or all cuisines if none selected
        return user.favoriteCuisines.isEmpty ? Cuisine.allCases : user.favoriteCuisines
    }
    
    func getRecommendedDietaryRestrictions() -> [DietaryNote] {
        guard let user = currentUser else { return [] }
        return user.dietaryPreferences
    }
    
    func getRecommendedDifficulty() -> Difficulty {
        guard let user = currentUser else { return .easy }
        
        switch user.cookingExperience {
        case .beginner:
            return .easy
        case .intermediate:
            return .medium
        case .advanced, .expert:
            return .hard
        }
    }
    
    func getRecommendedServings() -> Int {
        guard let user = currentUser else { return 2 }
        return user.householdSize
    }
} 