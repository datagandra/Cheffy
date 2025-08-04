import Foundation

// MARK: - Subscription Tier
enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "Free"
    case premium = "Premium"
    case pro = "Pro"
}

struct UserProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var email: String
    var cookingExperience: CookingExperience
    var dietaryPreferences: [DietaryNote]
    var favoriteCuisines: [Cuisine]
    var cookingGoals: [CookingGoal]
    var householdSize: Int
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var lastActive: Date
    
    init(
        name: String = "",
        email: String = "",
        cookingExperience: CookingExperience = .beginner,
        dietaryPreferences: [DietaryNote] = [],
        favoriteCuisines: [Cuisine] = [],
        cookingGoals: [CookingGoal] = [],
        householdSize: Int = 2,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = Date(),
        lastActive: Date = Date()
    ) {
        self.name = name
        self.email = email
        self.cookingExperience = cookingExperience
        self.dietaryPreferences = dietaryPreferences
        self.favoriteCuisines = favoriteCuisines
        self.cookingGoals = cookingGoals
        self.householdSize = householdSize
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = createdAt
        self.lastActive = lastActive
    }
}

enum CookingExperience: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    
    var description: String {
        switch self {
        case .beginner:
            return "Just starting out with cooking"
        case .intermediate:
            return "Some experience with basic recipes"
        case .advanced:
            return "Comfortable with complex recipes"
        case .expert:
            return "Professional-level cooking skills"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner:
            return "leaf"
        case .intermediate:
            return "flame"
        case .advanced:
            return "star"
        case .expert:
            return "crown"
        }
    }
}

enum CookingGoal: String, CaseIterable, Codable {
    case quickMeals = "Quick Meals"
    case healthyEating = "Healthy Eating"
    case familyDinners = "Family Dinners"
    case entertaining = "Entertaining"
    case mealPrep = "Meal Prep"
    case baking = "Baking"
    case internationalCuisine = "International Cuisine"
    case budgetFriendly = "Budget Friendly"
    
    var description: String {
        switch self {
        case .quickMeals:
            return "Fast and easy recipes"
        case .healthyEating:
            return "Nutritious and balanced meals"
        case .familyDinners:
            return "Recipes perfect for family meals"
        case .entertaining:
            return "Impressive dishes for guests"
        case .mealPrep:
            return "Make-ahead meal planning"
        case .baking:
            return "Sweet treats and breads"
        case .internationalCuisine:
            return "Explore global flavors"
        case .budgetFriendly:
            return "Affordable meal options"
        }
    }
    
    var icon: String {
        switch self {
        case .quickMeals:
            return "clock"
        case .healthyEating:
            return "heart"
        case .familyDinners:
            return "person.3"
        case .entertaining:
            return "wineglass"
        case .mealPrep:
            return "calendar"
        case .baking:
            return "birthday.cake"
        case .internationalCuisine:
            return "globe"
        case .budgetFriendly:
            return "dollarsign.circle"
        }
    }
} 