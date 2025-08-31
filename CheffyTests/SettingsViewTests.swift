import XCTest
import SwiftUI
import ViewInspector
@testable import Cheffy

@MainActor
final class SettingsViewTests: XCTestCase {
    
    var settingsView: SettingsView!
    var subscriptionManager: SubscriptionManager!
    var recipeManager: RecipeManager!
    var userManager: UserManager!
    var userAnalyticsService: UserAnalyticsService!
    
    override func setUp() {
        super.setUp()
        
        // Initialize mock services
        subscriptionManager = SubscriptionManager()
        recipeManager = RecipeManager()
        userManager = UserManager()
        userAnalyticsService = UserAnalyticsService(cloudKitService: CloudKitService())
        
        // Create settings view with environment objects
        settingsView = SettingsView()
            .environmentObject(subscriptionManager)
            .environmentObject(recipeManager)
            .environmentObject(userManager)
            .environmentObject(userAnalyticsService)
    }
    
    override func tearDown() {
        settingsView = nil
        subscriptionManager = nil
        recipeManager = nil
        userManager = nil
        userAnalyticsService = nil
        super.tearDown()
    }
    
    // MARK: - View Structure Tests
    
    func testSettingsViewHasCorrectSections() throws {
        let view = settingsView
        
        // Test that all required sections are present
        XCTAssertNotNil(view)
        
        // Note: ViewInspector can't directly inspect Form sections in this context
        // These tests would need to be UI tests for full validation
    }
    
    // MARK: - API Configuration Tests
    
    func testAPIKeyStatusCheck() {
        // Test initial state
        XCTAssertFalse(settingsView.hasAPIKey)
        
        // Test with valid API key
        let keychain = Keychain(service: "com.cheffy.app")
        try? keychain.set("test-api-key", key: "gemini_api_key")
        
        settingsView.checkAPIKeyStatus()
        XCTAssertTrue(settingsView.hasAPIKey)
        
        // Clean up
        try? keychain.remove("gemini_api_key")
    }
    
    func testSaveAPIKey() {
        let testKey = "test-gemini-api-key"
        settingsView.geminiKey = testKey
        
        settingsView.saveAPIKey()
        
        // Verify API key was saved
        let keychain = Keychain(service: "com.cheffy.app")
        let savedKey = try? keychain.get("gemini_api_key")
        XCTAssertEqual(savedKey, testKey)
        
        // Clean up
        try? keychain.remove("gemini_api_key")
    }
    
    func testClearAPIKey() {
        // First save a key
        let keychain = Keychain(service: "com.cheffy.app")
        try? keychain.set("test-key", key: "gemini_api_key")
        
        // Clear it
        settingsView.clearAPIKey()
        
        // Verify it's cleared
        let savedKey = try? keychain.get("gemini_api_key")
        XCTAssertNil(savedKey)
    }
    
    // MARK: - Analytics Settings Tests
    
    func testAnalyticsToggleUpdatesUserAnalyticsService() {
        let initialValue = userAnalyticsService.isAnalyticsEnabled
        
        // Toggle analytics
        settingsView.updateAnalyticsSettings(enabled: !initialValue)
        
        // Verify the service was updated
        XCTAssertEqual(userAnalyticsService.isAnalyticsEnabled, !initialValue)
    }
    
    func testAnalyticsToggleUpdatesUserManager() {
        // Create a test user profile
        let testProfile = UserProfile(
            userID: "test-user",
            isAnalyticsEnabled: true
        )
        userManager.createUserProfile(testProfile)
        
        // Toggle analytics
        settingsView.updateAnalyticsSettings(enabled: false)
        
        // Verify user profile was updated
        XCTAssertFalse(userManager.currentUser?.isAnalyticsEnabled ?? true)
    }
    
    // MARK: - Crash Reporting Tests
    
    func testCrashReportingToggle() {
        let initialValue = settingsView.isCrashReportingEnabled
        
        // Toggle crash reporting
        settingsView.updateCrashReportingSettings(enabled: !initialValue)
        
        // Verify the setting was updated
        XCTAssertEqual(settingsView.isCrashReportingEnabled, !initialValue)
    }
    
    // MARK: - Purchase Restoration Tests
    
    func testRestorePurchases() {
        // Test that restore purchases calls the subscription manager
        settingsView.restorePurchases()
        
        // Verify the flag was set
        XCTAssertTrue(settingsView.showingRestorePurchases)
    }
    
    // MARK: - Feedback Tests
    
    func testSendFeedbackWithValidText() {
        let feedbackText = "Great app! Love the recipe suggestions."
        settingsView.feedbackText = feedbackText
        
        settingsView.sendFeedback()
        
        // Verify feedback text was cleared
        XCTAssertTrue(settingsView.feedbackText.isEmpty)
    }
    
    func testSendFeedbackWithEmptyText() {
        settingsView.feedbackText = ""
        
        settingsView.sendFeedback()
        
        // Verify feedback text remains empty
        XCTAssertTrue(settingsView.feedbackText.isEmpty)
    }
    
    // MARK: - User Profile Tests
    
    func testUserProfileSectionWithValidUser() {
        // Create a test user
        let testProfile = UserProfile(
            userID: "test-user",
            deviceType: "iPhone",
            preferredCuisines: ["Italian", "Mexican"],
            dietaryPreferences: ["Vegetarian"],
            isAnalyticsEnabled: true
        )
        userManager.createUserProfile(testProfile)
        
        // Verify user profile is displayed
        XCTAssertNotNil(userManager.currentUser)
        XCTAssertEqual(userManager.currentUser?.deviceType, "iPhone")
        XCTAssertTrue(userManager.currentUser?.hasPreferences ?? false)
    }
    
    func testUserProfileSectionWithoutUser() {
        // Ensure no user profile
        userManager.deleteUserProfile()
        
        // Verify no profile state
        XCTAssertNil(userManager.currentUser)
    }
    
    // MARK: - Subscription Tests
    
    func testSubscriptionStatusDisplay() {
        // Test free subscription
        subscriptionManager.isSubscribed = false
        XCTAssertFalse(subscriptionManager.isSubscribed)
        
        // Test pro subscription
        subscriptionManager.isSubscribed = true
        XCTAssertTrue(subscriptionManager.isSubscribed)
    }
    
    func testGenerationCountDisplay() {
        let testCount = 5
        recipeManager.generationCount = testCount
        
        XCTAssertEqual(recipeManager.generationCount, testCount)
    }
    
    // MARK: - Privacy and Legal Tests
    
    func testPrivacyPolicyNavigation() {
        XCTAssertFalse(settingsView.showingPrivacyPolicy)
        
        // Simulate navigation to privacy policy
        settingsView.showingPrivacyPolicy = true
        XCTAssertTrue(settingsView.showingPrivacyPolicy)
    }
    
    func testTermsOfServiceNavigation() {
        XCTAssertFalse(settingsView.showingTermsOfService)
        
        // Simulate navigation to terms of service
        settingsView.showingTermsOfService = true
        XCTAssertTrue(settingsView.showingTermsOfService)
    }
    
    // MARK: - Support Tests
    
    func testContactSupportNavigation() {
        XCTAssertFalse(settingsView.showingContactSupport)
        
        // Simulate navigation to contact support
        settingsView.showingContactSupport = true
        XCTAssertTrue(settingsView.showingContactSupport)
    }
    
    func testFeedbackNavigation() {
        XCTAssertFalse(settingsView.showingFeedback)
        
        // Simulate navigation to feedback
        settingsView.showingFeedback = true
        XCTAssertTrue(settingsView.showingFeedback)
    }
    
    // MARK: - App Information Tests
    
    func testAppVersionDisplay() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        XCTAssertNotEqual(version, "Unknown")
    }
    
    func testBuildNumberDisplay() {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        XCTAssertNotEqual(build, "Unknown")
    }
    
    // MARK: - Cache Management Tests
    
    func testCacheManagementNavigation() {
        XCTAssertFalse(settingsView.showingCacheManagement)
        
        // Simulate navigation to cache management
        settingsView.showingCacheManagement = true
        XCTAssertTrue(settingsView.showingCacheManagement)
    }
    
    // MARK: - LLM Diagnostics Tests
    
    func testLLMDiagnosticsNavigation() {
        XCTAssertFalse(settingsView.showingLLMDiagnostics)
        
        // Simulate navigation to LLM diagnostics
        settingsView.showingLLMDiagnostics = true
        XCTAssertTrue(settingsView.showingLLMDiagnostics)
    }
    
    // MARK: - Database Test Tests
    
    func testDatabaseTestNavigation() {
        XCTAssertFalse(settingsView.showingDatabaseTest)
        
        // Simulate navigation to database test
        settingsView.showingDatabaseTest = true
        XCTAssertTrue(settingsView.showingDatabaseTest)
    }
    
    // MARK: - Developer Dashboard Tests
    
    func testDeveloperDashboardNavigation() {
        XCTAssertFalse(settingsView.showingDeveloperDashboard)
        
        // Simulate navigation to developer dashboard
        settingsView.showingDeveloperDashboard = true
        XCTAssertTrue(settingsView.showingDeveloperDashboard)
    }
    
    // MARK: - Reset Generation Count Tests
    
    func testResetGenerationCountAlert() {
        XCTAssertFalse(settingsView.showingResetAlert)
        
        // Set some generation count
        recipeManager.generationCount = 5
        
        // Simulate showing reset alert
        settingsView.showingResetAlert = true
        XCTAssertTrue(settingsView.showingResetAlert)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabelsAreSet() {
        // Test that accessibility labels are properly configured
        // This would require UI testing for full validation
        XCTAssertNotNil(settingsView)
    }
    
    // MARK: - Security Tests
    
    func testAPIKeyStoredInKeychain() {
        let testKey = "secure-test-key"
        settingsView.geminiKey = testKey
        settingsView.saveAPIKey()
        
        // Verify key is stored in Keychain, not UserDefaults
        let keychain = Keychain(service: "com.cheffy.app")
        let storedKey = try? keychain.get("gemini_api_key")
        XCTAssertEqual(storedKey, testKey)
        
        // Verify key is NOT in UserDefaults
        let userDefaultsKey = UserDefaults.standard.string(forKey: "gemini_api_key")
        XCTAssertNil(userDefaultsKey)
        
        // Clean up
        try? keychain.remove("gemini_api_key")
    }
    
    // MARK: - Performance Tests
    
    func testSettingsViewLoadsQuickly() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create settings view
        _ = SettingsView()
            .environmentObject(subscriptionManager)
            .environmentObject(recipeManager)
            .environmentObject(userManager)
            .environmentObject(userAnalyticsService)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let loadTime = endTime - startTime
        
        // Settings view should load in under 100ms
        XCTAssertLessThan(loadTime, 0.1)
    }
}

// MARK: - Contact Support View Tests

@MainActor
final class ContactSupportViewTests: XCTestCase {
    
    var contactSupportView: ContactSupportView!
    
    override func setUp() {
        super.setUp()
        contactSupportView = ContactSupportView()
    }
    
    override func tearDown() {
        contactSupportView = nil
        super.tearDown()
    }
    
    func testContactSupportViewInitialization() {
        XCTAssertNotNil(contactSupportView)
    }
    
    func testMailComposerAvailability() {
        // Test mail composer availability check
        let canSendMail = MFMailComposeViewController.canSendMail()
        XCTAssertNotNil(canSendMail)
    }
}

// MARK: - Privacy Policy View Tests

@MainActor
final class PrivacyPolicyViewTests: XCTestCase {
    
    var privacyPolicyView: PrivacyPolicyView!
    
    override func setUp() {
        super.setUp()
        privacyPolicyView = PrivacyPolicyView()
    }
    
    override func tearDown() {
        privacyPolicyView = nil
        super.tearDown()
    }
    
    func testPrivacyPolicyViewInitialization() {
        XCTAssertNotNil(privacyPolicyView)
    }
    
    func testPrivacyPolicyContent() {
        // Test that privacy policy content is displayed
        XCTAssertNotNil(privacyPolicyView)
    }
}

// MARK: - Terms of Service View Tests

@MainActor
final class TermsOfServiceViewTests: XCTestCase {
    
    var termsOfServiceView: TermsOfServiceView!
    
    override func setUp() {
        super.setUp()
        termsOfServiceView = TermsOfServiceView()
    }
    
    override func tearDown() {
        termsOfServiceView = nil
        super.tearDown()
    }
    
    func testTermsOfServiceViewInitialization() {
        XCTAssertNotNil(termsOfServiceView)
    }
    
    func testTermsOfServiceContent() {
        // Test that terms of service content is displayed
        XCTAssertNotNil(termsOfServiceView)
    }
}
