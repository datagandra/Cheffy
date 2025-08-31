import SwiftUI
import KeychainAccess
import MessageUI

struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var userAnalyticsService: UserAnalyticsService
    
    // MARK: - State Management
    @State private var geminiKey = ""
    @State private var showingAPIKeyAlert = false
    @State private var showingResetAlert = false
    @State private var hasAPIKey = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingCacheManagement = false
    @State private var showingLLMDiagnostics = false
    @State private var showingDatabaseTest = false
    @State private var showingDeveloperDashboard = false
    @State private var showingContactSupport = false
    @State private var showingFeedback = false
    @State private var feedbackText = ""
    @State private var showingMailComposer = false
    @State private var showingRestorePurchases = false
    
    // MARK: - App Storage
    @AppStorage("isAnalyticsEnabled") private var isAnalyticsEnabled = true
    @AppStorage("isCrashReportingEnabled") private var isCrashReportingEnabled = true
    
    var body: some View {
        Form {
            // User Profile Section
            userProfileSection
            
            // API Configuration Section
            apiConfigurationSection
            
            // Account Section
            accountSection
            
            // Privacy & Legal Section
            privacyAndLegalSection
            
            // Support Section
            supportSection
            
            // App Section
            appSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            checkAPIKeyStatus()
        }
        .alert("Enter Gemini API Key", isPresented: $showingAPIKeyAlert) {
            TextField("AIza...", text: $geminiKey)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel("API Key Input")
            
            Button("Save") {
                saveAPIKey()
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your Gemini API key to enable recipe generation. You can get one from https://makersuite.google.com/app/apikey")
        }
        .alert("Reset Generation Count", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                recipeManager.resetGenerationCount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset your generation count to 0. This action cannot be undone.")
        }
        .alert("Send Feedback", isPresented: $showingFeedback) {
            TextField("Your feedback...", text: $feedbackText, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityLabel("Feedback Input")
            
            Button("Send") {
                sendFeedback()
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Help us improve Cheffy by sharing your thoughts.")
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingCacheManagement) {
            CacheManagementView()
        }
        .sheet(isPresented: $showingLLMDiagnostics) {
            LLMDiagnosticView()
        }
        .sheet(isPresented: $showingDatabaseTest) {
            LocalDatabaseTestView()
        }
        .sheet(isPresented: $showingDeveloperDashboard) {
            DeveloperAnalyticsView()
        }
        .sheet(isPresented: $showingContactSupport) {
            ContactSupportView()
        }
        .onAppear {
            checkAPIKeyStatus()
        }
    }
    
    // MARK: - User Profile Section
    
    private var userProfileSection: some View {
        Section {
            if let user = userManager.currentUser {
                // User Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User Profile")
                                .font(.headline)
                            
                            Text("Device: \(user.deviceType)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Analytics Status
                    HStack {
                        Image(systemName: user.isAnalyticsEnabled ? "chart.bar.fill" : "chart.bar")
                            .foregroundColor(user.isAnalyticsEnabled ? .green : .gray)
                            .accessibilityHidden(true)
                        Text("Analytics: \(user.isAnalyticsEnabled ? "Enabled" : "Disabled")")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    // Preferences
                    if user.hasPreferences {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .accessibilityHidden(true)
                            Text("Preferences set")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 8)
                
                // Edit Profile Button
                Button {
                    // Edit profile functionality will be added in future updates
                } label: {
                    Label("Edit Profile", systemImage: "pencil")
                }
                .accessibilityHint("Double tap to edit your profile")
                
                // Reset Onboarding Button
                Button {
                    userManager.resetOnboarding()
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.clockwise")
                        .foregroundColor(.orange)
                }
                .accessibilityHint("Double tap to reset onboarding experience")
            } else {
                // No profile
                HStack {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Profile")
                            .font(.headline)
                        
                        Text("Complete onboarding to personalize your experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                
                Button {
                    userManager.startOnboarding()
                } label: {
                    Label("Complete Onboarding", systemImage: "person.badge.plus")
                        .foregroundColor(.orange)
                }
                .accessibilityHint("Double tap to complete onboarding")
            }
        } header: {
            Text("Profile")
        } footer: {
            if let user = userManager.currentUser {
                Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
            } else {
                Text("Complete your profile to get personalized recipe recommendations")
            }
        }
    }
    
    // MARK: - API Configuration Section
    
    private var apiConfigurationSection: some View {
        Section {
            // API Key Status
            HStack {
                Label("Gemini API Key", systemImage: "key.fill")
                
                Spacer()
                
                if hasAPIKey {
                    Label("Set", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Not Set", systemImage: "exclamationmark.circle")
                        .foregroundColor(.red)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingAPIKeyAlert = true
            }
            .accessibilityLabel("Gemini API Key")
            .accessibilityValue(hasAPIKey ? "Set" : "Not Set")
            .accessibilityHint("Double tap to configure API key")
            .accessibilityAddTraits(.isButton)
            
            // Clear API Key
            if hasAPIKey {
                Button(role: .destructive) {
                    clearAPIKey()
                } label: {
                    Label("Clear API Key", systemImage: "trash")
                }
                .accessibilityHint("Double tap to remove API key")
            }
            
            // API Key Help
            Link(destination: URL(string: "https://makersuite.google.com/app/apikey")!) {
                Label("Get API Key", systemImage: "questionmark.circle")
            }
            .accessibilityHint("Opens Google AI Studio in Safari")
        } header: {
            Text("API Configuration")
        } footer: {
            Text("Your API key is stored securely in Keychain and never shared.")
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            // Subscription Status
            HStack {
                Label("Subscription", systemImage: "crown.fill")
                
                Spacer()
                
                if subscriptionManager.isSubscribed {
                    Label("PRO", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Free", systemImage: "person")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityLabel("Subscription")
            .accessibilityValue(subscriptionManager.isSubscribed ? "PRO" : "Free")
            
            // Generation Count
            HStack {
                Label("Generations Used", systemImage: "number.circle")
                
                Spacer()
                
                Text("\(recipeManager.generationCount)")
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Generations Used")
            .accessibilityValue("\(recipeManager.generationCount)")
            
            // Reset Generation Count
            if recipeManager.generationCount > 0 {
                Button {
                    showingResetAlert = true
                } label: {
                    Label("Reset Generation Count", systemImage: "arrow.clockwise")
                        .foregroundColor(.orange)
                }
                .accessibilityHint("Double tap to reset generation count")
            }
            
            // Upgrade to Pro
            if !subscriptionManager.isSubscribed {
                Button {
                    subscriptionManager.showPaywall = true
                } label: {
                    Label("Upgrade to PRO", systemImage: "crown.fill")
                        .foregroundColor(.orange)
                }
                .accessibilityHint("Double tap to upgrade to PRO subscription")
            }
            
            // Restore Purchases
            Button {
                restorePurchases()
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
            }
            .accessibilityHint("Double tap to restore previous purchases")
        } header: {
            Text("Account")
        } footer: {
            Text("PRO users get unlimited recipe generations and advanced features.")
        }
    }
    
    // MARK: - Privacy & Legal Section
    
    private var privacyAndLegalSection: some View {
        Section {
            // Analytics Toggle
            Toggle(isOn: $isAnalyticsEnabled) {
                Label("Analytics", systemImage: "chart.bar")
            }
            .onChange(of: isAnalyticsEnabled) { _, newValue in
                updateAnalyticsSettings(enabled: newValue)
            }
            .accessibilityHint("Toggle to enable or disable anonymous usage analytics")
            
            // Crash Reporting Toggle
            Toggle(isOn: $isCrashReportingEnabled) {
                Label("Crash Reporting", systemImage: "exclamationmark.triangle")
            }
            .onChange(of: isCrashReportingEnabled) { _, newValue in
                updateCrashReportingSettings(enabled: newValue)
            }
            .accessibilityHint("Toggle to enable or disable crash reporting")
            
            // Privacy Policy
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            .accessibilityHint("Double tap to view privacy policy")
            
            // Terms of Service
            Button {
                showingTermsOfService = true
            } label: {
                Label("Terms of Service", systemImage: "doc.text")
            }
            .accessibilityHint("Double tap to view terms of service")
        } header: {
            Text("Privacy & Legal")
        } footer: {
            Text("Analytics help us improve Cheffy. All data is anonymous and never shared with third parties.")
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section {
            // Contact Support
            Button {
                showingContactSupport = true
            } label: {
                Label("Contact Support", systemImage: "envelope")
            }
            .accessibilityHint("Double tap to contact support team")
            
            // Send Feedback
            Button {
                showingFeedback = true
            } label: {
                Label("Send Feedback", systemImage: "message")
            }
            .accessibilityHint("Double tap to send feedback")
            
            // Help & FAQ
            Link(destination: URL(string: "https://cheffy.app/help")!) {
                Label("Help & FAQ", systemImage: "questionmark.circle")
            }
            .accessibilityHint("Opens help documentation in Safari")
        } header: {
            Text("Support")
        } footer: {
            Text("We're here to help! Contact us for assistance or share your feedback.")
        }
    }
    
    // MARK: - App Section
    
    private var appSection: some View {
        Section {
            // App Version
            HStack {
                Label("Version", systemImage: "info.circle")
                
                Spacer()
                
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("App Version")
            .accessibilityValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            
            // Build Number
            HStack {
                Label("Build", systemImage: "hammer")
                
                Spacer()
                
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Build Number")
            .accessibilityValue(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
            
            // Cache Management
            Button {
                showingCacheManagement = true
            } label: {
                Label("Cache Management", systemImage: "externaldrive")
            }
            .accessibilityHint("Double tap to manage cached recipes")
            
            // LLM Diagnostics
            Button {
                showingLLMDiagnostics = true
            } label: {
                Label("LLM Diagnostics", systemImage: "stethoscope")
            }
            .accessibilityHint("Double tap to diagnose LLM connection issues")
            
            // Database Test
            Button {
                showingDatabaseTest = true
            } label: {
                Label("Database Test", systemImage: "database")
            }
            .accessibilityHint("Double tap to test local recipe database")
            
            // Developer Dashboard
            Button {
                showingDeveloperDashboard = true
            } label: {
                Label("Developer Dashboard", systemImage: "chart.bar.doc.horizontal")
            }
            .foregroundColor(.purple)
            .accessibilityHint("Double tap to access developer analytics dashboard")
            
            // Rate App
            Link(destination: URL(string: "https://apps.apple.com/app/cheffy")!) {
                Label("Rate Cheffy", systemImage: "star")
            }
            .accessibilityHint("Opens App Store rating page in Safari")
            
            // Share App
            ShareLink(item: "Check out Cheffy - AI Recipe Generator!") {
                Label("Share Cheffy", systemImage: "square.and.arrow.up")
            }
            .accessibilityHint("Double tap to share Cheffy with others")
        } header: {
            Text("App")
        } footer: {
            Text("Thank you for using Cheffy!")
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkAPIKeyStatus() {
        let keychain = Keychain(service: "com.cheffy.app")
        hasAPIKey = (try? keychain.get("gemini_api_key")) != nil
    }
    
    private func saveAPIKey() {
        guard !geminiKey.isEmpty else { return }
        
        let keychain = Keychain(service: "com.cheffy.app")
        try? keychain.set(geminiKey, key: "gemini_api_key")
        
        checkAPIKeyStatus()
        geminiKey = ""
    }
    
    private func clearAPIKey() {
        let keychain = Keychain(service: "com.cheffy.app")
        try? keychain.remove("gemini_api_key")
        
        checkAPIKeyStatus()
    }
    
    private func updateAnalyticsSettings(enabled: Bool) {
        userAnalyticsService.setAnalyticsEnabled(enabled)
        userManager.updateAnalyticsPreference(enabled: enabled)
    }
    
    private func updateCrashReportingSettings(enabled: Bool) {
        // Update crash reporting settings
        // This would integrate with your crash reporting service
    }
    
    private func restorePurchases() {
        showingRestorePurchases = true
        Task {
            await subscriptionManager.restorePurchases()
        }
    }
    
    private func sendFeedback() {
        guard !feedbackText.isEmpty else { return }
        
        // Send feedback to your backend or email
        // For now, we'll just clear the text
        feedbackText = ""
        
        // Show success message
        // You could add a toast or alert here
    }
}

// MARK: - Contact Support View

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingMailComposer = false
    @State private var showingEmailAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Need Help?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Our support team is here to help you with any questions or issues you might have.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Contact Options") {
                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailComposer = true
                        } else {
                            showingEmailAlert = true
                        }
                    } label: {
                        Label("Send Email", systemImage: "envelope")
                    }
                    .accessibilityHint("Double tap to send support email")
                    
                    Link(destination: URL(string: "mailto:support@cheffy.app")!) {
                        Label("Email Support", systemImage: "envelope.badge")
                    }
                    .accessibilityHint("Opens email app with support address")
                }
                
                Section("Before Contacting") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Please include:")
                            .font(.headline)
                        
                        Text("• Your device model and iOS version")
                        Text("• App version and build number")
                        Text("• Description of the issue")
                        Text("• Steps to reproduce")
                    }
                    .font(.body)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposeView()
            }
            .alert("Email Not Available", isPresented: $showingEmailAlert) {
                Button("OK") { }
            } message: {
                Text("Please use the email link below or contact us at support@cheffy.app")
            }
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        // Pre-fill email with device and app info
        composer.setToRecipients(["support@cheffy.app"])
        composer.setSubject("Cheffy Support Request")
        
        let deviceInfo = """
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        
        Issue Description:
        
        Steps to Reproduce:
        
        """
        
        composer.setMessageBody(deviceInfo, isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Last updated: August 31, 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Group {
                        Text("Information We Collect")
                            .font(.headline)
                        
                        Text("Cheffy collects minimal information necessary to provide our service. We do not store your personal data or recipe preferences.")
                        
                        Text("Analytics & Crash Reporting")
                            .font(.headline)
                        
                        Text("We collect anonymous usage analytics and crash reports to improve the app. You can disable these features in Settings.")
                        
                        Text("API Usage")
                            .font(.headline)
                        
                        Text("Your recipe generation requests are sent to Google's Gemini API. We do not store or log your recipe requests.")
                        
                        Text("Data Security")
                            .font(.headline)
                        
                        Text("Your API key is stored securely using iOS Keychain and is never transmitted to our servers.")
                        
                        Text("Privacy Controls")
                            .font(.headline)
                        
                        Text("You can control analytics, crash reporting, and data collection in the app settings. All data is anonymized before collection.")
                        
                        Text("Data Retention")
                            .font(.headline)
                        
                        Text("We retain anonymous analytics data for up to 2 years to improve our service. You can request data deletion at any time.")
                        
                        Text("Contact Us")
                            .font(.headline)
                        
                        Text("For privacy questions, contact us at privacy@cheffy.app")
                    }
                    .font(.body)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Last updated: August 31, 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Group {
                        Text("Acceptance of Terms")
                            .font(.headline)
                        
                        Text("By using Cheffy, you agree to these terms of service.")
                        
                        Text("Service Description")
                            .font(.headline)
                        
                        Text("Cheffy is an AI-powered recipe generator that uses Google's Gemini API to create personalized recipes.")
                        
                        Text("User Responsibilities")
                            .font(.headline)
                        
                        Text("You are responsible for providing accurate dietary restrictions and ensuring recipes meet your dietary needs.")
                        
                        Text("Subscription Terms")
                            .font(.headline)
                        
                        Text("PRO subscriptions auto-renew unless cancelled. You can manage subscriptions in App Store settings.")
                        
                        Text("Limitation of Liability")
                            .font(.headline)
                        
                        Text("Cheffy is provided as-is. We are not responsible for any issues arising from recipe preparation.")
                        
                        Text("Changes to Terms")
                            .font(.headline)
                        
                        Text("We may update these terms. Continued use constitutes acceptance of changes.")
                        
                        Text("Contact Us")
                            .font(.headline)
                        
                        Text("For questions about these terms, contact us at legal@cheffy.app")
                    }
                    .font(.body)
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SubscriptionManager())
            .environmentObject(RecipeManager())
            .environmentObject(UserManager())
            .environmentObject(UserAnalyticsService(cloudKitService: CloudKitService()))
    }
} 