import Foundation
import Combine

// MARK: - Recipe Service Protocol
protocol RecipeServiceProtocol {
    func generateRecipe(
        userPrompt: String?,
        recipeName: String?,
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        ingredients: [String]?,
        maxTime: Int?,
        servings: Int
    ) async throws -> Recipe
    
    func generatePopularRecipes(
        cuisine: Cuisine,
        difficulty: Difficulty,
        dietaryRestrictions: [DietaryNote],
        servings: Int
    ) async throws -> [Recipe]
    
    func generateDetailedInstructions(for recipe: Recipe) async throws -> [String]
}

// MARK: - Cache Service Protocol
protocol CacheServiceProtocol {
    func saveRecipe(_ recipe: Recipe) async throws
    func loadRecipes() async throws -> [Recipe]
    func clearCache() async throws
    func getCachedRecipesCount() -> Int
    func hasCachedRecipes() -> Bool
}

// MARK: - Voice Service Protocol
protocol VoiceServiceProtocol {
    func startSpeechRecognition() async throws
    func stopSpeechRecognition()
    func speak(_ text: String) async throws
    var isListening: Bool { get }
    var recognizedText: String { get }
}

// MARK: - Subscription Service Protocol
protocol SubscriptionServiceProtocol {
    func checkSubscriptionStatus() async throws -> SubscriptionStatus
    func purchaseSubscription() async throws
    func restorePurchases() async throws
    var isSubscribed: Bool { get }
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func performRequest<T: Codable>(_ request: APIRequest) async throws -> T
    func uploadImage(_ imageData: Data) async throws -> String
    var isConnected: Bool { get }
}

// MARK: - Security Service Protocol
protocol SecurityServiceProtocol {
    func storeSecureValue(_ value: String, for key: String) async throws
    func retrieveSecureValue(for key: String) async throws -> String?
    func encryptData(_ data: Data) throws -> Data
    func decryptData(_ data: Data) throws -> Data
}

// MARK: - Analytics Service Protocol
protocol AnalyticsServiceProtocol {
    func trackEvent(_ event: String, parameters: [String: Any]?)
    func trackScreen(_ screenName: String)
    func trackError(_ error: Error, context: String)
}

// MARK: - Localization Service Protocol
protocol LocalizationServiceProtocol {
    func localizedString(for key: String) -> String
    func setLanguage(_ language: String)
    var currentLanguage: String { get }
    var isRTL: Bool { get }
}

// MARK: - Performance Monitoring Protocol
protocol PerformanceMonitoringProtocol {
    func startTimer(for operation: String)
    func endTimer(for operation: String)
    func trackMemoryUsage()
    func trackCPUUsage()
}

// MARK: - Error Handling Protocol
protocol ErrorHandlingProtocol {
    func handleError(_ error: Error, context: String)
    func logError(_ error: Error, severity: ErrorSeverity)
    func showUserFriendlyError(_ error: Error)
}

// MARK: - Supporting Types
enum SubscriptionStatus {
    case free
    case pro
    case expired
}

enum ErrorSeverity {
    case low
    case medium
    case high
    case critical
}

struct APIRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    
    enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
    }
} 