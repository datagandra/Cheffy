import Foundation
import Combine

class SubscriptionManager: ObservableObject {
    @Published var isPro = false
    @Published var showPaywall = false
    @Published var isLoading = false
    @Published var error: String?
    
    func loadSubscriptionStatus() {
        // TODO: Implement subscription loading
    }
    
    func getRemainingFreeGenerations() -> Int {
        return 5 // Default free generations
    }
} 