import SwiftUI
import AVFoundation

struct EnhancedCookingModeView: View {
    let recipe: Recipe
    @StateObject private var voiceManager = VoiceManager()
    @State private var currentStepIndex = 0
    @State private var isTimerRunning = false
    @State private var remainingTime: Int = 0
    @State private var showingSettings = false
    @State private var showingVoiceControls = false
    @State private var timer: Timer?
    @State private var lastWarningTime: Int = 0
    @State private var isCookingModeActive = false
    @State private var cookingStartTime: Date?
    @State private var totalCookingTime: TimeInterval = 0
    @State private var showingStepDetails = false
    @State private var isAutoAdvance = true
    @State private var showingIngredientChecklist = false
    
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
                        // Recipe Header
                        recipeHeaderCard
                        
                        // Current Step Card
                        currentStepCard
                        
                        // Timer Card (if step has duration)
                        if let duration = currentStep.duration, duration > 0 {
                            timerCard(duration: duration)
                        }
                        
                        // Navigation Controls
                        navigationControls
                        
                        // All Steps Overview
                        allStepsOverview
                        
                        // Voice Controls
                        voiceControlsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Cooking Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingIngredientChecklist.toggle() }) {
                        Image(systemName: "checklist")
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
            .sheet(isPresented: $showingVoiceControls) {
                voiceControlsSheet
            }
            .sheet(isPresented: $showingIngredientChecklist) {
                ingredientChecklistSheet
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        BadgeView(text: recipe.cuisine.rawValue, color: .orange)
                        BadgeView(text: recipe.difficulty.rawValue, color: .blue)
                        BadgeView(text: "Step \(currentStepIndex + 1)/\(recipe.steps.count)", color: .green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(recipe.formattedTotalTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(recipe.servings) servings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(y: 2)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Current Step Card
    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(currentStep.stepNumber)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(currentStepIndex + 1) of \(recipe.steps.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingStepDetails.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            Text(currentStep.description)
                .font(.body)
                .lineLimit(nil)
                .lineSpacing(4)
                .foregroundColor(.primary)
            
            if let tips = currentStep.tips, !tips.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text(tips)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let temperature = currentStep.temperature {
                HStack {
                    Image(systemName: "thermometer")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("Temperature: \(Int(temperature))°C")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            voiceManager.narrateRecipeStep(currentStep, recipeName: recipe.name, stepNumber: currentStepIndex + 1, totalSteps: recipe.steps.count)
        }
    }
    
    // MARK: - Timer Card
    private func timerCard(duration: Int) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Timer")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formatTime(remainingTime))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            HStack(spacing: 12) {
                Button(action: startTimer) {
                    HStack {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Start")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: resetTimer) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onAppear {
            remainingTime = duration
        }
    }
    
    // MARK: - Navigation Controls
    private var navigationControls: some View {
        HStack(spacing: 16) {
            Button(action: previousStep) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            .disabled(currentStepIndex == 0)
            
            Button(action: nextStep) {
                HStack {
                    Text(currentStepIndex == recipe.steps.count - 1 ? "Finish" : "Next")
                    Image(systemName: currentStepIndex == recipe.steps.count - 1 ? "checkmark" : "chevron.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - All Steps Overview
    private var allStepsOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Steps")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack {
                        Circle()
                            .fill(index == currentStepIndex ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(index == currentStepIndex ? .white : .primary)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Step \(step.stepNumber)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(index == currentStepIndex ? .orange : .primary)
                            
                            Text(step.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        if let duration = step.duration, duration > 0 {
                            Text("\(duration)m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(index == currentStepIndex ? Color.orange.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                    .onTapGesture {
                        currentStepIndex = index
                        voiceManager.narrateRecipeStep(step, recipeName: recipe.name, stepNumber: index + 1, totalSteps: recipe.steps.count)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Voice Controls Card
    private var voiceControlsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Voice Controls")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingVoiceControls.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { voiceManager.toggleVoice() }) {
                    HStack {
                        Image(systemName: voiceManager.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        Text(voiceManager.voiceEnabled ? "Voice On" : "Voice Off")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(voiceManager.voiceEnabled ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: { voiceManager.stopSpeaking() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Sheets
    private var cookingSettingsSheet: some View {
        NavigationView {
            Form {
                Section("Cooking Settings") {
                    Toggle("Auto-advance steps", isOn: $isAutoAdvance)
                    Toggle("Voice guidance", isOn: $voiceManager.voiceEnabled)
                }
                
                Section("Voice Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speed: \(String(format: "%.1f", voiceManager.voiceSpeed))")
                        Slider(value: $voiceManager.voiceSpeed, in: 0.1...1.0)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Volume: \(String(format: "%.1f", voiceManager.voiceVolume))")
                        Slider(value: $voiceManager.voiceVolume, in: 0.0...1.0)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pitch: \(String(format: "%.1f", voiceManager.voicePitch))")
                        Slider(value: $voiceManager.voicePitch, in: 0.5...2.0)
                    }
                }
                
                if cookingStartTime != nil {
                    Section("Cooking Statistics") {
                        HStack {
                            Text("Total Cooking Time")
                            Spacer()
                            Text(formatCookingTime(totalCookingTime))
                        }
                    }
                }
            }
            .navigationTitle("Settings")
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
    
    private var voiceControlsSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("Voice Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text(String(format: "%.1f", voiceManager.voiceSpeed))
                        }
                        Slider(value: $voiceManager.voiceSpeed, in: 0.1...1.0)
                        
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text(String(format: "%.1f", voiceManager.voiceVolume))
                        }
                        Slider(value: $voiceManager.voiceVolume, in: 0.0...1.0)
                        
                        HStack {
                            Text("Pitch")
                            Spacer()
                            Text(String(format: "%.1f", voiceManager.voicePitch))
                        }
                        Slider(value: $voiceManager.voicePitch, in: 0.5...2.0)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Button("Test Voice") {
                    voiceManager.speak("This is a test of the voice settings. How does this sound?")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
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
    
    private var ingredientChecklistSheet: some View {
        NavigationView {
            List {
                Section("Ingredients Checklist") {
                    ForEach(recipe.ingredients, id: \.id) { ingredient in
                        HStack {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text("\(ingredient.amount, specifier: "%.1f") \(ingredient.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let notes = ingredient.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Equipment Needed") {
                    Text("• Chef's knife")
                    Text("• Cutting board")
                    Text("• Measuring cups and spoons")
                    Text("• Cooking pot/pan")
                    Text("• Stove/oven")
                }
            }
            .navigationTitle("Ingredients & Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingIngredientChecklist = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func startCookingMode() {
        isCookingModeActive = true
        cookingStartTime = Date()
        
        // Welcome message
        voiceManager.speak("Welcome to cooking mode for \(recipe.name). Let's get started with step \(currentStepIndex + 1).")
        
        // Narrate first step
        voiceManager.narrateRecipeStep(currentStep, recipeName: recipe.name, stepNumber: currentStepIndex + 1, totalSteps: recipe.steps.count)
    }
    
    private func stopCookingMode() {
        isCookingModeActive = false
        if let startTime = cookingStartTime {
            totalCookingTime = Date().timeIntervalSince(startTime)
        }
        voiceManager.stopSpeaking()
        stopTimer()
    }
    
    private func nextStep() {
        if currentStepIndex < recipe.steps.count - 1 {
            voiceManager.narrateStepTransition(fromStep: currentStepIndex + 1, toStep: currentStepIndex + 2, recipeName: recipe.name)
            currentStepIndex += 1
            
            if isAutoAdvance {
                voiceManager.narrateRecipeStep(currentStep, recipeName: recipe.name, stepNumber: currentStepIndex + 1, totalSteps: recipe.steps.count)
            }
        } else {
            // Recipe complete
            voiceManager.narrateRecipeComplete(recipeName: recipe.name)
        }
    }
    
    private func previousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            voiceManager.narrateRecipeStep(currentStep, recipeName: recipe.name, stepNumber: currentStepIndex + 1, totalSteps: recipe.steps.count)
        }
    }
    
    private func startTimer() {
        if isTimerRunning {
            pauseTimer()
        } else {
            isTimerRunning = true
            voiceManager.narrateTimerStart(duration: remainingTime, stepDescription: currentStep.description)
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                    
                    // Warning at 30 seconds
                    if remainingTime == 30 && lastWarningTime != 30 {
                        voiceManager.narrateTimerWarning(remainingTime: remainingTime)
                        lastWarningTime = 30
                    }
                    
                    // Warning at 10 seconds
                    if remainingTime == 10 && lastWarningTime != 10 {
                        voiceManager.narrateTimerWarning(remainingTime: remainingTime)
                        lastWarningTime = 10
                    }
                    
                    // Timer complete
                    if remainingTime == 0 {
                        voiceManager.narrateTimerComplete(stepDescription: currentStep.description)
                        stopTimer()
                    }
                }
            }
        }
    }
    
    private func pauseTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func resetTimer() {
        stopTimer()
        if let duration = currentStep.duration {
            remainingTime = duration
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func formatCookingTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 