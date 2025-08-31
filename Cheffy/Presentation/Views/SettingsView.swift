import SwiftUI
import KeychainAccess

struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var recipeManager: RecipeManager
    @EnvironmentObject var userManager: UserManager
    
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

    
    var body: some View {
        List {
            // User Profile Section
            userProfileSection
            
            // API Configuration Section
            apiConfigurationSection
            
            // Account Section
            accountSection
            
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
            Text("LLM Diagnostics - Coming Soon")
                .padding()
        }
        .sheet(isPresented: $showingDatabaseTest) {
            VStack(spacing: 20) {
                Text("Local Recipe Database Test")
                    .font(.title)
                    .fontWeight(.bold)
                
                let recipeService = RecipeDatabaseService.shared
                let allRecipes = recipeService.recipes
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("📊 Total recipes: \(allRecipes.count)")
                    
                    let cuisines = Set(allRecipes.map { $0.cuisine.rawValue })
                    Text("🌍 Cuisines: \(cuisines.count)")
                    Text("   \(cuisines.joined(separator: ", "))")
                    
                    let vegetarianRecipes = recipeService.getRecipes(for: [.vegetarian])
                    Text("🥬 Vegetarian: \(vegetarianRecipes.count)")
                    
                    let chickenRecipes = recipeService.searchRecipes(query: "chicken")
                    Text("🍗 Chicken recipes: \(chickenRecipes.count)")
                    
                    if let firstRecipe = allRecipes.first {
                        Text("Sample: \(firstRecipe.title)")
                        Text("Cuisine: \(firstRecipe.cuisine.rawValue)")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingDeveloperDashboard) {
            DeveloperAnalyticsView()
        }
        .onAppear {
            checkAPIKeyStatus()
        }
    }
    
    // MARK: - API Configuration Section
    
    private var apiConfigurationSection: some View {
        Section {
            // API Key Status
            HStack {
                Label("Gemini API Key", systemImage: "key")
                
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
            
            // Clear API Key
            if hasAPIKey {
                Button(role: .destructive) {
                    clearAPIKey()
                } label: {
                    Label("Clear API Key", systemImage: "trash")
                }
            }
            
            // API Key Help
            Link(destination: URL(string: "https://makersuite.google.com/app/apikey")!) {
                Label("Get API Key", systemImage: "questionmark.circle")
            }
        } header: {
            Text("API Configuration")
        } footer: {
            Text("Your API key is stored securely and never shared.")
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
                        Text("Analytics: \(user.isAnalyticsEnabled ? "Enabled" : "Disabled")")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    // Preferences
                    if user.hasPreferences {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
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
                
                // Reset Onboarding Button
                Button {
                    userManager.resetOnboarding()
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.clockwise")
                        .foregroundColor(.orange)
                }
            } else {
                // No profile
                HStack {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
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
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            // Subscription Status
            HStack {
                Label("Subscription", systemImage: "crown")
                
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
                Label("Generations Used", systemImage: "number")
                
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
        } header: {
            Text("Account")
        } footer: {
            Text("PRO users get unlimited recipe generations and advanced features.")
        }
    }
    

    

    

    
    // MARK: - App Section
    
    private var appSection: some View {
        Section {
            // App Version
            HStack {
                Label("Version", systemImage: "info.circle")
                
                Spacer()
                
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("App Version")
            .accessibilityValue("1.0.0")
            
            // Privacy Policy
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            
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
            
            // Terms of Service
            Button {
                showingTermsOfService = true
            } label: {
                Label("Terms of Service", systemImage: "doc.text")
            }
            
            // Rate App
            Link(destination: URL(string: "https://apps.apple.com/app/cheffy")!) {
                Label("Rate Cheffy", systemImage: "star")
            }
            
            // Share App
            ShareLink(item: "Check out Cheffy - AI Recipe Generator!") {
                Label("Share Cheffy", systemImage: "square.and.arrow.up")
            }
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
                    
                    Text("Last updated: July 28, 2024")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Group {
                        Text("Information We Collect")
                            .font(.headline)
                        
                        Text("Cheffy collects minimal information necessary to provide our service. We do not store your personal data or recipe preferences.")
                        
                        Text("API Usage")
                            .font(.headline)
                        
                        Text("Your recipe generation requests are sent to Google's Gemini API. We do not store or log your recipe requests.")
                        
                        Text("Data Security")
                            .font(.headline)
                        
                        Text("Your API key is stored securely using iOS Keychain and is never transmitted to our servers.")
                        
                        Text("Privacy Controls")
                            .font(.headline)
                        
                        Text("You can control analytics, crash reporting, and data collection in the app settings. All data is anonymized before collection.")
                        
                        Text("SSL Certificate Pinning")
                            .font(.headline)
                        
                        Text("We use SSL certificate pinning to ensure secure connections to our API endpoints.")
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
                    
                    Text("Last updated: July 28, 2024")
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
                        
                        Text("Limitation of Liability")
                            .font(.headline)
                        
                        Text("Cheffy is provided as-is. We are not responsible for any issues arising from recipe preparation.")
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
    }
} 