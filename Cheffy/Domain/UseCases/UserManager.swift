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
        // Update the lastUpdatedAt field instead of lastActive
        let updatedUser = user.updatePreferences(cuisines: user.preferredCuisines, dietary: user.dietaryPreferences)
        updateUserProfile(updatedUser)
    }
    
    // MARK: - Profile Validation
    
    func isProfileComplete() -> Bool {
        guard let user = currentUser else { return false }
        
        // Check if user has basic preferences set
        return user.hasPreferences
    }
    
    // MARK: - Recommendations
    
    func getRecommendedCuisines() -> [Cuisine] {
        guard let user = currentUser else { return Cuisine.allCases }
        
        // Convert string cuisine names to Cuisine enum values
        let userCuisines = user.preferredCuisines.compactMap { cuisineName in
            Cuisine.allCases.first { $0.rawValue.lowercased() == cuisineName.lowercased() }
        }
        
        // Return user's preferred cuisines, or all cuisines if none selected
        return userCuisines.isEmpty ? Cuisine.allCases : userCuisines
    }
    
    func getRecommendedDietaryRestrictions() -> [DietaryNote] {
        guard let user = currentUser else { return [] }
        
        // Convert string dietary preferences to DietaryNote enum values
        return user.dietaryPreferences.compactMap { dietaryName in
            DietaryNote.allCases.first { $0.rawValue.lowercased() == dietaryName.lowercased() }
        }
    }
    
    func getRecommendedDifficulty() -> Difficulty {
        // Default to medium difficulty since we don't track cooking experience anymore
        return .medium
    }
    
    func getRecommendedServings() -> Int {
        // Default to 2 servings since we don't track household size anymore
        return 2
    }
} 