import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var currentStep = 0
    @State private var userProfile = UserProfile(userID: UUID().uuidString)
    
    private let totalSteps = 5
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressView
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStepView(userProfile: $userProfile)
                        .tag(0)
                    
                    PersonalInfoStepView(userProfile: $userProfile)
                        .tag(1)
                    
                    CookingExperienceStepView(userProfile: $userProfile)
                        .tag(2)
                    
                    DietaryPreferencesStepView(userProfile: $userProfile)
                        .tag(3)
                    
                    CookingGoalsStepView(userProfile: $userProfile)
                        .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation buttons
                navigationButtons
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
    
    private var progressView: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            } else {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: // Welcome
            return true
        case 1: // Personal Info
            return true // Always valid for basic info
        case 2: // Cooking Experience
            return true // Always valid
        case 3: // Dietary Preferences
            return true // Optional
        case 4: // Cooking Goals
            return true // Optional
        default:
            return false
        }
    }
    
    private func completeOnboarding() {
        userManager.createUserProfile(userProfile)
        userManager.completeOnboarding()
    }
}

// MARK: - Welcome Step
struct WelcomeStepView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "chef.hat")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                VStack(spacing: 16) {
                    Text("Welcome to Cheffy!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Let's personalize your cooking experience by learning a bit about you.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Personal Info Step
struct PersonalInfoStepView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Tell us about yourself")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("This helps us recommend the perfect recipes for you.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 20) {
                    // Device Type (read-only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device Type")
                            .font(.headline)
                        
                        Text(userProfile.deviceType)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .foregroundColor(.secondary)
                    }
                    
                    // App Version (read-only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Version")
                            .font(.headline)
                        
                        Text(userProfile.appVersion)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .foregroundColor(.secondary)
                    }
                    
                    // Analytics Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analytics & Privacy")
                            .font(.headline)
                        
                        Toggle("Share anonymous usage data to improve Cheffy", isOn: $userProfile.isAnalyticsEnabled)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

// MARK: - Preferred Cuisines Step
struct CookingExperienceStepView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("What cuisines do you prefer?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select your favorite cuisines to get personalized recipe recommendations.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(Cuisine.allCases, id: \.self) { cuisine in
                        CuisineCard(
                            cuisine: cuisine,
                            isSelected: userProfile.preferredCuisines.contains(cuisine.rawValue)
                        ) {
                            if userProfile.preferredCuisines.contains(cuisine.rawValue) {
                                userProfile.preferredCuisines.removeAll { $0 == cuisine.rawValue }
                            } else {
                                userProfile.preferredCuisines.append(cuisine.rawValue)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct CuisineCard: View {
    let cuisine: Cuisine
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(cuisine.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Dietary Preferences Step
struct DietaryPreferencesStepView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Any dietary preferences?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select any dietary restrictions or preferences you have.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(DietaryNote.allCases, id: \.self) { restriction in
                    DietaryRestrictionCard(
                        restriction: restriction.rawValue,
                        isSelected: userProfile.dietaryPreferences.contains(restriction.rawValue)
                    ) {
                        if userProfile.dietaryPreferences.contains(restriction.rawValue) {
                            userProfile.dietaryPreferences.removeAll { $0 == restriction.rawValue }
                        } else {
                            userProfile.dietaryPreferences.append(restriction.rawValue)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct DietaryRestrictionCard: View {
    let restriction: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(restriction)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Final Step
struct CookingGoalsStepView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("You're all set!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("We'll use your preferences to provide personalized recipe recommendations and improve the app based on anonymous usage data.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 20) {
                // Summary of preferences
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Preferences:")
                        .font(.headline)
                    
                    if !userProfile.preferredCuisines.isEmpty {
                        Text("• Preferred cuisines: \(userProfile.preferredCuisines.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !userProfile.dietaryPreferences.isEmpty {
                        Text("• Dietary preferences: \(userProfile.dietaryPreferences.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("• Analytics enabled: \(userProfile.isAnalyticsEnabled ? "Yes" : "No")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

 