import SwiftUI
import AVFoundation

struct CookingGuideView: View {
    @StateObject private var viewModel: CookingGuideViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(recipe: Recipe) {
        self._viewModel = StateObject(wrappedValue: CookingGuideViewModel(recipe: recipe))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                progressBar
                
                // Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Recipe Header
                        recipeHeader
                        
                        // Current Step Display
                        currentStepView
                        
                        // Cooking Controls
                        cookingControlsView
                        
                        // All Steps List
                        allStepsView
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cooking Guide")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        viewModel.stopCooking()
                        dismiss()
                    }
                    .accessibilityLabel("Close cooking guide")
                }
            }
        }
        .onDisappear {
            viewModel.stopCooking()
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text(viewModel.stepNumberText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            ProgressView(value: viewModel.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cooking progress: \(viewModel.stepNumberText), \(Int(viewModel.progress * 100))% complete")
    }
    
    // MARK: - Recipe Header
    
    private var recipeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.recipe.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                CookingBadgeView(text: viewModel.recipe.cuisine.rawValue, color: .orange)
                CookingBadgeView(text: viewModel.recipe.difficulty.rawValue, color: .blue)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.recipe.name), \(viewModel.recipe.cuisine.rawValue) cuisine, \(viewModel.recipe.difficulty.rawValue) difficulty")
    }
    
    // MARK: - Current Step View
    
    private var currentStepView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Step")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let step = viewModel.currentStep {
                    Text("\(step.stepNumber) of \(viewModel.totalSteps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let step = viewModel.currentStep {
                VStack(alignment: .leading, spacing: 12) {
                    Text(step.description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                    
                    // Step Details
                    if let duration = step.duration {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("\(duration) minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let temperature = step.temperature {
                        HStack {
                            Image(systemName: "thermometer")
                                .foregroundColor(.red)
                            Text("\(Int(temperature))°C")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let tips = step.tips {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Chef's Tip")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            Text(tips)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("Cooking complete!")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.currentStepAccessibilityLabel)
    }
    
    // MARK: - Cooking Controls
    
    private var cookingControlsView: some View {
        VStack(spacing: 16) {
            // Main Play/Pause Button
            Button(action: {
                if viewModel.isPlaying {
                    if viewModel.isPaused {
                        viewModel.resumeCooking()
                    } else {
                        viewModel.pauseCooking()
                    }
                } else {
                    viewModel.startCooking()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.isPlaying ? (viewModel.isPaused ? "play.fill" : "pause.fill") : "play.fill")
                        .font(.title2)
                    
                    Text(viewModel.isPlaying ? (viewModel.isPaused ? "Resume" : "Pause") : "Start Cooking")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isPlaying ? (viewModel.isPaused ? Color.orange : Color.red) : Color.green)
                .cornerRadius(12)
            }
            .accessibilityLabel(viewModel.playButtonAccessibilityLabel)
            
            // Navigation Buttons
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.previousStep()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "backward.fill")
                        Text("Previous")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isFirstStep)
                .accessibilityLabel(viewModel.previousButtonAccessibilityLabel)
                
                Button(action: {
                    viewModel.repeatCurrentStep()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Repeat")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(8)
                }
                .accessibilityLabel("Repeat current step")
                
                Button(action: {
                    viewModel.nextStep()
                }) {
                    HStack(spacing: 8) {
                        Text("Next")
                        Image(systemName: "forward.fill")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isLastStep)
                .accessibilityLabel(viewModel.nextButtonAccessibilityLabel)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - All Steps View
    
    private var allStepsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Steps")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.recipe.steps.enumerated()), id: \.element.id) { index, step in
                    StepRowView(
                        step: step,
                        isCurrentStep: index == viewModel.currentStepIndex,
                        isCompleted: index < viewModel.currentStepIndex
                    ) {
                        viewModel.currentStepIndex = index
                        viewModel.updateCurrentStepDescription()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Step Row View

struct StepRowView: View {
    let step: CookingStep
    let isCurrentStep: Bool
    let isCompleted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Step Number Circle
                ZStack {
                    Circle()
                        .fill(isCurrentStep ? Color.orange : (isCompleted ? Color.green : Color.gray.opacity(0.3)))
                        .frame(width: 32, height: 32)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Text("\(step.stepNumber)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isCurrentStep ? .white : .primary)
                    }
                }
                
                // Step Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.description)
                        .font(.body)
                        .foregroundColor(isCurrentStep ? .primary : .secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    if let duration = step.duration {
                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isCurrentStep {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding(12)
            .background(isCurrentStep ? Color.orange.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.stepNumber): \(step.description)")
        .accessibilityHint(isCurrentStep ? "Current step" : "Tap to select this step")
    }
}

// MARK: - Badge View

struct CookingBadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

#Preview {
    // Create a sample recipe for preview
    let sampleRecipe = Recipe(
        name: "Sample Recipe",
        cuisine: .italian,
        difficulty: .medium,
        prepTime: 15,
        cookTime: 30,
        servings: 4,
        ingredients: [],
        steps: [
            CookingStep(stepNumber: 1, description: "Preheat the oven to 350°F", duration: 5),
            CookingStep(stepNumber: 2, description: "Mix all ingredients in a bowl", duration: 10),
            CookingStep(stepNumber: 3, description: "Bake for 25 minutes", duration: 25, temperature: 175)
        ]
    )
    
    return CookingGuideView(recipe: sampleRecipe)
} 