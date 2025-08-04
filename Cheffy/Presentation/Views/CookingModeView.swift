import SwiftUI
import AVFoundation

struct CookingModeView: View {
    let recipe: Recipe
    @StateObject private var voiceManager = VoiceManager()
    @State private var currentStepIndex = 0
    @State private var isTimerRunning = false
    @State private var remainingTime: Int = 0
    @State private var isAutoAdvance = false
    @State private var showingSettings = false
    @State private var showingRecipeDetails = false
    @State private var showingVoiceControls = false
    @State private var timer: Timer?
    @State private var lastWarningTime: Int = 0
    @State private var isCookingModeActive = false
    @State private var cookingStartTime: Date?
    @State private var totalCookingTime: TimeInterval = 0
    @State private var detailedInstructions: String = ""
    @State private var isLoadingDetailedInstructions = false
    @State private var showingDetailedInstructions = false
    @State private var showingAllIngredients = false
    
    var currentStep: CookingStep {
        recipe.steps[currentStepIndex]
    }
    
    var progress: Double {
        Double(currentStepIndex + 1) / Double(recipe.steps.count)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.red.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Recipe Header with Details
                        recipeHeaderCard
                        
                        // Quick Recipe Info
                        quickRecipeInfoCard
                        
                        // Detailed Cooking Instructions Section
                        detailedCookingInstructionsSection
                        
                        // Navigation Controls
                        navigationControls
                        
                        // Timer Card (using recipe cook time)
                        timerCard(duration: recipe.cookTime)
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Cooking Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingRecipeDetails.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                cookingSettingsSheet
            }
            .sheet(isPresented: $showingRecipeDetails) {
                detailedRecipeSheet
            }
            .sheet(isPresented: $showingVoiceControls) {
                voiceControlsSheet
            }
            .onAppear {
                startCookingMode()
            }
            .onDisappear {
                stopCookingMode()
            }
        }
    }
    
    // MARK: - Recipe Header Card
    private var recipeHeaderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        BadgeView(text: recipe.cuisine.rawValue, color: .orange)
                        BadgeView(text: recipe.difficulty.rawValue, color: .blue)
                    }
                }
                
                Spacer()
            }
            
            // Progress Bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Quick Recipe Info Card
    private var quickRecipeInfoCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Recipe Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.caloriesPerServing)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 4) {
                    Text("Prep")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.prepTime)m")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 4) {
                    Text("Cook")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.cookTime)m")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.prepTime + recipe.cookTime)m")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 4) {
                    Text("Servings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.servings)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
            
            // Ingredients Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingredients (\(recipe.ingredients.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(showingAllIngredients ? Array(recipe.ingredients) : Array(recipe.ingredients.prefix(6))) { ingredient in
                        HStack {
                            Circle()
                                .fill(Color.orange.opacity(0.3))
                                .frame(width: 6, height: 6)
                            
                            Text("\(ingredient.amount, specifier: "%.1f") \(ingredient.unit) \(ingredient.name)")
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                }
                
                if recipe.ingredients.count > 6 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingAllIngredients.toggle()
                        }
                    }) {
                        HStack {
                            Text(showingAllIngredients ? "Show Less" : "+ \(recipe.ingredients.count - 6) more ingredients")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .italic()
                            
                            Image(systemName: showingAllIngredients ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Current Step Card
    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Step Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 40, height: 40)
                    
                    Text("\(currentStep.stepNumber)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(currentStep.stepNumber)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let duration = currentStep.duration {
                        Text("\(duration) minutes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Voice control
                Button(action: { showingVoiceControls.toggle() }) {
                    Image(systemName: voiceManager.isSpeaking ? "speaker.wave.3.fill" : (voiceManager.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"))
                        .font(.title2)
                        .foregroundColor(voiceManager.voiceEnabled ? .blue : .gray)
                        .scaleEffect(voiceManager.isSpeaking ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: voiceManager.isSpeaking)
                }
            }
            
            // Generated Image Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                
                VStack(spacing: 12) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("AI-Generated Visual Guide")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Custom image for this cooking step")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Step Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Detailed Instructions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(currentStep.description)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
            }
            
            // Step Details
            if let temperature = currentStep.temperature {
                HStack {
                    Image(systemName: "thermometer")
                        .foregroundColor(.red)
                    Text("Temperature: \(Int(temperature))°C")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Chef Tips
            if let tips = currentStep.tips, !tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("Chef's Pro Tips")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(tips)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Step Techniques
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.green)
                    Text("Cooking Techniques")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text("• Follow the timing precisely for best results")
                Text("• Use the recommended temperature settings")
                Text("• Pay attention to visual cues and doneness indicators")
                Text("• Keep your workspace clean and organized")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Timer Card
    private func timerCard(duration: Int) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Step Timer")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isTimerRunning {
                    Text(timeString(from: remainingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                } else {
                    Text(timeString(from: duration * 60))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                Button(action: startTimer) {
                    HStack {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Start")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(isTimerRunning ? Color.orange : Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: resetTimer) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Navigation Controls
    private var navigationControls: some View {
        HStack(spacing: 16) {
            Button(action: previousStep) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(currentStepIndex > 0 ? Color.blue : Color.gray)
                .cornerRadius(8)
            }
            .disabled(currentStepIndex == 0)
            
            Spacer()
            
            Button(action: nextStep) {
                HStack {
                    Text(currentStepIndex == recipe.steps.count - 1 ? "Finish" : "Next")
                    Image(systemName: currentStepIndex == recipe.steps.count - 1 ? "checkmark" : "chevron.right")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Detailed Cooking Instructions Section
    private var detailedCookingInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.book.closed.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("Detailed Cooking Instructions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: loadDetailedInstructions) {
                    HStack {
                        if isLoadingDetailedInstructions {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isLoadingDetailedInstructions ? "Loading..." : "Refresh")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .disabled(isLoadingDetailedInstructions)
            }
            
            if isLoadingDetailedInstructions {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Generating detailed instructions...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if !detailedInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(detailedInstructions)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundColor(.primary)
                        .lineLimit(8)
                    
                    Button("Read Full Instructions") {
                        showingDetailedInstructions = true
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    
                    Text("Get AI-Generated Detailed Instructions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Tap the refresh button to generate comprehensive cooking instructions with professional tips, timing guidance, and step-by-step details.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingDetailedInstructions) {
            detailedInstructionsSheet
        }
    }
    
    // MARK: - Detailed Instructions Sheet
    private var detailedInstructionsSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recipe.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            BadgeView(text: recipe.cuisine.rawValue, color: .orange)
                            BadgeView(text: recipe.difficulty.rawValue, color: .blue)
                        }
                        
                        Text("AI-Generated Detailed Cooking Instructions")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.bottom, 10)
                    
                    // Detailed Instructions
                    if !detailedInstructions.isEmpty {
                        Text(detailedInstructions)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundColor(.primary)
                    } else {
                        Text("No detailed instructions available. Please generate them first.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Detailed Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDetailedInstructions = false
                    }
                }
            }
        }
    }
    
    // MARK: - All Steps Overview
    private var allStepsOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Complete Recipe Steps")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(index == currentStepIndex ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                            
                            Text("\(step.stepNumber)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(index == currentStepIndex ? .white : .primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.description)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundColor(index == currentStepIndex ? .primary : .secondary)
                            
                            if let duration = step.duration {
                                Text("\(duration) min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if index < currentStepIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Detailed Recipe Sheet
    private var detailedRecipeSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Recipe Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text(recipe.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            BadgeView(text: recipe.cuisine.rawValue, color: .orange)
                            BadgeView(text: recipe.difficulty.rawValue, color: .blue)
                        }
                        
                        // Time breakdown
                        HStack(spacing: 20) {
                            VStack {
                                Text("Prep")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(recipe.prepTime)m")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack {
                                Text("Cook")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(recipe.cookTime)m")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(recipe.prepTime + recipe.cookTime)m")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack {
                                Text("Servings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(recipe.servings)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ingredients")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            ForEach(recipe.ingredients) { ingredient in
                                HStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                    
                                    Text("\(ingredient.amount, specifier: "%.1f") \(ingredient.unit)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                    
                                    Text(ingredient.name)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    if let notes = ingredient.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    // Wine Pairings
                    if !recipe.winePairings.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Wine Pairings")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                ForEach(recipe.winePairings) { wine in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(wine.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Spacer()
                                            
                                            BadgeView(text: wine.type.rawValue, color: .purple)
                                        }
                                        
                                        Text(wine.region)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(wine.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                    
                    // Chef Notes
                    if !recipe.chefNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Chef's Notes")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(recipe.chefNotes)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                    
                    // Plating Tips
                    if !recipe.platingTips.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Plating Tips")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(recipe.platingTips)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingRecipeDetails = false
                    }
                }
            }
        }
    }
    
    // MARK: - Voice Controls Sheet
    private var voiceControlsSheet: some View {
        NavigationView {
            Form {
                Section("Voice Settings") {
                    Toggle("Voice Narration", isOn: $voiceManager.voiceEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Speed")
                        Slider(value: $voiceManager.voiceSpeed, in: 0.1...1.0) {
                            Text("Voice Speed")
                        } minimumValueLabel: {
                            Text("Slow")
                        } maximumValueLabel: {
                            Text("Fast")
                        }
                        Text("Current: \(String(format: "%.1f", voiceManager.voiceSpeed))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Volume")
                        Slider(value: $voiceManager.voiceVolume, in: 0.0...1.0) {
                            Text("Voice Volume")
                        } minimumValueLabel: {
                            Text("Quiet")
                        } maximumValueLabel: {
                            Text("Loud")
                        }
                        Text("Current: \(String(format: "%.1f", voiceManager.voiceVolume))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Pitch")
                        Slider(value: $voiceManager.voicePitch, in: 0.5...2.0) {
                            Text("Voice Pitch")
                        } minimumValueLabel: {
                            Text("Low")
                        } maximumValueLabel: {
                            Text("High")
                        }
                        Text("Current: \(String(format: "%.1f", voiceManager.voicePitch))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Voice Commands") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Voice Features:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("• Step-by-step narration with timing")
                        Text("• Timer announcements and warnings")
                        Text("• Temperature guidance")
                        Text("• Chef tips and techniques")
                        Text("• Step transitions")
                        Text("• Recipe completion celebration")
                        Text("• Ingredient reminders")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section("Test Voice") {
                    Button("Test Current Settings") {
                        voiceManager.narrateRecipeStep(
                            currentStep,
                            recipeName: recipe.name,
                            stepNumber: currentStep.stepNumber,
                            totalSteps: recipe.steps.count
                        )
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Voice Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingVoiceControls = false
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Sheet
    private var cookingSettingsSheet: some View {
        NavigationView {
            Form {
                Section("Voice & Audio") {
                    Toggle("Voice Narration", isOn: $voiceManager.voiceEnabled)
                    Toggle("Auto-advance Steps", isOn: $isAutoAdvance)
                }
                
                Section("Timer Settings") {
                    Text("Timer will automatically pause when switching steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Cooking Statistics") {
                    if isCookingModeActive {
                        Text("Cooking Time: \(formatCookingTime(totalCookingTime))")
                    }
                }
                
                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enhanced Cooking Mode Features:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("• Detailed voice narration with timing")
                        Text("• Smart timer with voice announcements")
                        Text("• Temperature and technique guidance")
                        Text("• Real-time cooking progress tracking")
                        Text("• Chef tips and professional techniques")
                        Text("• Step-by-step visual and audio guidance")
                        Text("• Wine pairings and plating tips")
                        Text("• Hands-free cooking experience")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Cooking Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func loadDetailedInstructions() {
        guard !isLoadingDetailedInstructions else { return }
        
        isLoadingDetailedInstructions = true
        
        Task {
            do {
                let openAIClient = OpenAIClient()
                let instructions = try await openAIClient.generateDetailedCookingInstructions(for: recipe)
                
                await MainActor.run {
                    self.detailedInstructions = instructions
                    self.isLoadingDetailedInstructions = false
                }
            } catch {
                await MainActor.run {
                    self.detailedInstructions = "Error generating detailed instructions: \(error.localizedDescription)"
                    self.isLoadingDetailedInstructions = false
                }
            }
        }
    }
    
    private func nextStep() {
        if currentStepIndex < recipe.steps.count - 1 {
            let fromStep = currentStepIndex + 1
            let toStep = currentStepIndex + 2
            
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStepIndex += 1
            }
            
            // Announce step transition
            voiceManager.narrateStepTransition(fromStep: fromStep, toStep: toStep, recipeName: recipe.name)
            
            // Start detailed narration for new step
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startDetailedVoiceNarration()
            }
        } else {
            // Recipe completed
            voiceManager.narrateRecipeComplete(recipeName: recipe.name)
        }
    }
    
    private func previousStep() {
        if currentStepIndex > 0 {
            let fromStep = currentStepIndex + 1
            let toStep = currentStepIndex
            
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStepIndex -= 1
            }
            
            // Announce step transition
            voiceManager.narrateStepTransition(fromStep: fromStep, toStep: toStep, recipeName: recipe.name)
            
            // Start detailed narration for new step
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startDetailedVoiceNarration()
            }
        }
    }
    
    private func startTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            if remainingTime == 0 {
                remainingTime = currentStep.duration ?? 0
                remainingTime *= 60 // Convert to seconds
            }
            
            isTimerRunning = true
            lastWarningTime = remainingTime
            
            // Announce timer start
            if let duration = currentStep.duration {
                voiceManager.narrateTimerStart(duration: duration * 60, stepDescription: currentStep.description)
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                    
                    // Voice warnings at specific intervals
                    if remainingTime == 30 || remainingTime == 60 || 
                       (remainingTime <= 300 && remainingTime % 60 == 0 && remainingTime != lastWarningTime) {
                        voiceManager.narrateTimerWarning(remainingTime: remainingTime)
                        lastWarningTime = remainingTime
                    }
                } else {
                    stopTimer()
                    // Announce timer completion
                    voiceManager.narrateTimerComplete(stepDescription: currentStep.description)
                    // Auto-advance if enabled
                    if isAutoAdvance {
                        nextStep()
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func resetTimer() {
        stopTimer()
        remainingTime = 0
    }
    
    private func toggleVoice() {
        voiceManager.voiceEnabled.toggle()
        if voiceManager.voiceEnabled {
            startDetailedVoiceNarration()
        } else {
            voiceManager.stopSpeaking()
        }
    }
    
    private func startDetailedVoiceNarration() {
        voiceManager.narrateRecipeStep(
            currentStep,
            recipeName: recipe.name,
            stepNumber: currentStep.stepNumber,
            totalSteps: recipe.steps.count
        )
        
        // Announce temperature if available
        if let temperature = currentStep.temperature {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.voiceManager.narrateTemperatureGuidance(temperature: temperature)
            }
        }
        
        // Announce chef tips if available
        if let tips = currentStep.tips, !tips.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                self.voiceManager.narrateCookingTip(tips)
            }
        }
    }
    
    private func startCookingMode() {
        isCookingModeActive = true
        cookingStartTime = Date()
        
        // Welcome message
        let welcomeMessage = "Welcome to cooking mode for \(recipe.name). I'll guide you through each step with detailed instructions, timers, and chef tips. Let's begin with step 1."
        voiceManager.speak(welcomeMessage)
        
        // Start first step narration
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.startDetailedVoiceNarration()
        }
    }
    
    private func stopCookingMode() {
        isCookingModeActive = false
        if let startTime = cookingStartTime {
            totalCookingTime = Date().timeIntervalSince(startTime)
        }
        voiceManager.stopSpeaking()
        stopTimer()
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func formatCookingTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
} 