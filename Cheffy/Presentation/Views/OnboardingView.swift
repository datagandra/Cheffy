import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var currentStep = 0
    @State private var userProfile = UserProfile()
    
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
            return !userProfile.name.isEmpty && !userProfile.email.isEmpty && userProfile.householdSize > 0
        case 2: // Cooking Experience
            return true // Always valid
        case 3: // Dietary Preferences
            return true // Optional
        case 4: // Cooking Goals
            return !userProfile.cookingGoals.isEmpty
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
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                        
                        TextField("Enter your name", text: $userProfile.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                        
                        TextField("Enter your email", text: $userProfile.email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Household Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Household Size")
                            .font(.headline)
                        
                        Stepper("\(userProfile.householdSize) people", value: $userProfile.householdSize, in: 1...10)
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

// MARK: - Cooking Experience Step
struct CookingExperienceStepView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("What's your cooking experience?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This helps us suggest recipes at the right difficulty level.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                ForEach(CookingExperience.allCases, id: \.self) { experience in
                    ExperienceCard(
                        experience: experience,
                        isSelected: userProfile.cookingExperience == experience
                    ) {
                        userProfile.cookingExperience = experience
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct ExperienceCard: View {
    let experience: CookingExperience
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: experience.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .orange)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(experience.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(experience.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding()
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
                        restriction: restriction,
                        isSelected: userProfile.dietaryPreferences.contains(restriction)
                    ) {
                        if userProfile.dietaryPreferences.contains(restriction) {
                            userProfile.dietaryPreferences.removeAll { $0 == restriction }
                        } else {
                            userProfile.dietaryPreferences.append(restriction)
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
    let restriction: DietaryNote
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(restriction.rawValue)
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

// MARK: - Cooking Goals Step
struct CookingGoalsStepView: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("What are your cooking goals?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select your primary cooking goals to help us recommend the perfect recipes.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(CookingGoal.allCases, id: \.self) { goal in
                    CookingGoalCard(
                        goal: goal,
                        isSelected: userProfile.cookingGoals.contains(goal)
                    ) {
                        if userProfile.cookingGoals.contains(goal) {
                            userProfile.cookingGoals.removeAll { $0 == goal }
                        } else {
                            userProfile.cookingGoals.append(goal)
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

struct CookingGoalCard: View {
    let goal: CookingGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .orange)
                
                VStack(spacing: 4) {
                    Text(goal.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.center)
                    
                    Text(goal.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 