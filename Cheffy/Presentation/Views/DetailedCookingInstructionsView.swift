import SwiftUI
import AVFoundation
import Combine

struct DetailedCookingInstructionsView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var showingIngredients = true
    @State private var showingWinePairings = false
    @State private var showingChefNotes = false
    @State private var showingPlatingTips = false
    @State private var showingKindleReading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // Recipe Header
                    recipeHeader
                    
                    // Ingredients Section
                    ingredientsSection
                    
                    // Cooking Instructions Section
                    cookingInstructionsSection
                    
                    // Chef Notes Section
                    if !recipe.chefNotes.isEmpty {
                        chefNotesSection
                    }
                    
                    // Wine Pairings Section
                    if !recipe.winePairings.isEmpty {
                        winePairingsSection
                    }
                    
                    // Plating Tips Section
                    if !recipe.platingTips.isEmpty {
                        platingTipsSection
                    }
                    
                    // Action Buttons
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cooking Instructions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingKindleReading) {
            InlineKindleReadingView(recipe: recipe)
        }
    }
    
    // MARK: - Recipe Header
    private var recipeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and badges
            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    BadgeView(text: recipe.cuisine.rawValue, color: .orange)
                    BadgeView(text: recipe.difficulty.rawValue, color: .blue)
                }
            }
            
            // Time and servings info
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.caloriesPerServing)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 4) {
                    Text("Prep Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.prepTime) min")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 4) {
                    Text("Cook Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.cookTime) min")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 4) {
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.prepTime + recipe.cookTime) min")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 4) {
                    Text("Servings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.servings)")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Ingredients")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(recipe.ingredients.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(recipe.ingredients) { ingredient in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(ingredient.amount, specifier: "%.1f") \(ingredient.unit)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                
                                Text(ingredient.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                            
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
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Cooking Instructions Section
    private var cookingInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "number.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Cooking Instructions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(recipe.steps.count) steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                ForEach(recipe.steps) { step in
                    VStack(alignment: .leading, spacing: 12) {
                        // Step header
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                
                                Text("\(step.stepNumber)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Step \(step.stepNumber)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                if let duration = step.duration {
                                    Text("\(duration) minutes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Step description
                        Text(step.description)
                            .font(.body)
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                        
                        // Step details
                        VStack(alignment: .leading, spacing: 8) {
                            if let temperature = step.temperature {
                                HStack {
                                    Image(systemName: "thermometer")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text("Temperature: \(Int(temperature))°C")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let tips = step.tips, !tips.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Chef's Tip")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        
                                        Text(tips)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                                .padding(12)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Chef Notes Section
    private var chefNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Chef's Notes")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(recipe.chefNotes)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Wine Pairings Section
    private var winePairingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wineglass")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("Wine Pairings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(recipe.winePairings) { wine in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(wine.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            BadgeView(text: wine.type.rawValue, color: .purple)
                        }
                        
                        Text(wine.region)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(wine.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
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
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Plating Tips Section
    private var platingTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("Plating Tips")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(recipe.platingTips)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Reading Mode Button
            Button(action: {
                showingKindleReading = true
            }) {
                HStack {
                    Image(systemName: "book.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Kindle Reading Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "speaker.wave.2")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Interactive Cooking Mode Button
            NavigationLink(destination: CookingModeView(recipe: recipe)) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Interactive Cooking Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange, Color.red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    let sampleRecipe = Recipe(
        title: "Coq au Vin",
        cuisine: .french,
        difficulty: .medium,
        prepTime: 30,
        cookTime: 90,
        servings: 4,
        ingredients: [
            Ingredient(name: "Chicken thighs", amount: 4, unit: "pieces"),
            Ingredient(name: "Red wine", amount: 750, unit: "ml"),
            Ingredient(name: "Bacon", amount: 200, unit: "g")
        ],
        steps: [
            CookingStep(stepNumber: 1, description: "Marinate the chicken in red wine with aromatics for at least 4 hours or overnight.", duration: 240),
            CookingStep(stepNumber: 2, description: "Brown the bacon in a large Dutch oven over medium heat until crispy.", duration: 10),
            CookingStep(stepNumber: 3, description: "Remove bacon and brown the chicken pieces in the rendered fat until golden brown on all sides.", duration: 15)
        ],
        platingTips: "Serve in a deep bowl with the sauce generously spooned over the chicken. Garnish with fresh parsley and serve with crusty bread.",
        chefNotes: "This classic French dish requires patience and attention to detail. The key is to develop deep flavors through proper browning and slow cooking."
    )
    
    DetailedCookingInstructionsView(recipe: sampleRecipe)
}

// MARK: - Inline TextToSpeech Service
/// Service for handling text-to-speech functionality with scroll synchronization
@MainActor
class InlineTextToSpeechService: NSObject, ObservableObject {
    static let shared = InlineTextToSpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentWordRange: NSRange?
    @Published var currentCharacterIndex: Int = 0
    @Published var speechProgress: Double = 0.0
    
    // Text content and tracking
    private var fullText: String = ""
    private var textComponents: [TextComponent] = []
    private var currentComponentIndex: Int = 0
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    /// Start reading the recipe with automatic scrolling
    func startReading(recipe: Recipe) {
        stopReading()
        
        fullText = buildRecipeText(recipe)
        textComponents = parseTextComponents(fullText)
        currentComponentIndex = 0
        currentCharacterIndex = 0
        
        readNextComponent()
    }
    
    /// Build formatted text from recipe
    private func buildRecipeText(_ recipe: Recipe) -> String {
        var text = "\(recipe.title). "
        
        text += "This recipe serves \(recipe.servings) people. "
        text += "Preparation time: \(recipe.prepTime) minutes. "
        text += "Cooking time: \(recipe.cookTime) minutes. "
        
        text += "Ingredients needed: "
        for ingredient in recipe.ingredients {
            text += "\(ingredient.amount) \(ingredient.unit) of \(ingredient.name). "
        }
        
        text += "Cooking instructions: "
        for (index, step) in recipe.steps.enumerated() {
            text += "Step \(index + 1): \(step.description). "
        }
        
        if !recipe.chefNotes.isEmpty {
            text += "Chef's notes: \(recipe.chefNotes). "
        }
        
        return text
    }
    
    /// Parse text into components for tracking
    private func parseTextComponents(_ text: String) -> [TextComponent] {
        let sentences = text.components(separatedBy: ". ").filter { !$0.isEmpty }
        var components: [TextComponent] = []
        var currentIndex = 0
        
        for sentence in sentences {
            let range = NSRange(location: currentIndex, length: sentence.count + 2) // +2 for ". "
            components.append(TextComponent(text: sentence + ". ", range: range))
            currentIndex += sentence.count + 2
        }
        
        return components
    }
    
    /// Read the next text component
    private func readNextComponent() {
        guard currentComponentIndex < textComponents.count else {
            finishReading()
            return
        }
        
        let component = textComponents[currentComponentIndex]
        let utterance = AVSpeechUtterance(string: component.text)
        
        // Configure speech parameters
        utterance.rate = 0.5 // Slower rate for better comprehension
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        currentUtterance = utterance
        isPlaying = true
        isPaused = false
        
        synthesizer.speak(utterance)
    }
    
    /// Pause speech
    func pauseReading() {
        guard isPlaying else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
    }
    
    /// Resume speech
    func resumeReading() {
        guard isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
    }
    
    /// Stop speech completely
    func stopReading() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentWordRange = nil
        currentCharacterIndex = 0
        speechProgress = 0.0
        currentComponentIndex = 0
    }
    
    /// Skip to next section
    func skipToNext() {
        synthesizer.stopSpeaking(at: .immediate)
        currentComponentIndex += 1
        readNextComponent()
    }
    
    /// Go back to previous section
    func skipToPrevious() {
        synthesizer.stopSpeaking(at: .immediate)
        currentComponentIndex = max(0, currentComponentIndex - 1)
        readNextComponent()
    }
    
    private func finishReading() {
        isPlaying = false
        isPaused = false
        speechProgress = 1.0
        currentCharacterIndex = fullText.count
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension InlineTextToSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = true
            self.isPaused = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentComponentIndex += 1
            self.readNextComponent()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            // Update current word range for highlighting
            self.currentWordRange = characterRange
            
            // Calculate global character index
            let componentStartIndex = self.textComponents.prefix(self.currentComponentIndex)
                .reduce(0) { $0 + $1.text.count }
            self.currentCharacterIndex = componentStartIndex + characterRange.location
            
            // Update progress
            self.speechProgress = Double(self.currentCharacterIndex) / Double(self.fullText.count)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = false
        }
    }
}

// MARK: - Supporting Types
struct TextComponent {
    let text: String
    let range: NSRange
}

// MARK: - Inline Kindle Reading View
/// Kindle-style reading view for recipes with voice narration and auto-scroll
struct InlineKindleReadingView: View {
    let recipe: Recipe
    @StateObject private var speechService = InlineTextToSpeechService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Reading preferences
    @State private var fontSize: CGFloat = 18
    @State private var lineSpacing: CGFloat = 8
    @State private var backgroundColor: Color = .kindleBackground
    @State private var textColor: Color = .kindleText
    @State private var showControls = true
    
    // Auto-scroll
    @State private var autoScrollTimer: Timer?
    
    // Content sections for navigation
    private var contentSections: [ReadingSection] {
        var sections: [ReadingSection] = []
        
        // Title section
        sections.append(ReadingSection(
            id: "title",
            title: "Recipe Title",
            content: recipe.title,
            type: .title
        ))
        
        // Overview section
        let overview = """
        This recipe serves \(recipe.servings) people.
        Preparation time: \(recipe.prepTime) minutes.
        Cooking time: \(recipe.cookTime) minutes.
        Difficulty: \(recipe.difficulty.rawValue.capitalized)
        """
        sections.append(ReadingSection(
            id: "overview",
            title: "Overview",
            content: overview,
            type: .overview
        ))
        
        // Ingredients section
        let ingredientsText = recipe.ingredients.enumerated().map { index, ingredient in
            "\(index + 1). \(ingredient.amount) \(ingredient.unit) \(ingredient.name)"
        }.joined(separator: "\n")
        
        sections.append(ReadingSection(
            id: "ingredients",
            title: "Ingredients",
            content: ingredientsText,
            type: .ingredients
        ))
        
        // Instructions section
        let instructionsText = recipe.steps.enumerated().map { index, step in
            "Step \(index + 1): \(step.description)"
        }.joined(separator: "\n\n")
        
        sections.append(ReadingSection(
            id: "instructions",
            title: "Cooking Instructions",
            content: instructionsText,
            type: .instructions
        ))
        
        // Chef's notes (if available)
        if !recipe.chefNotes.isEmpty {
            sections.append(ReadingSection(
                id: "notes",
                title: "Chef's Notes",
                content: recipe.chefNotes,
                type: .notes
            ))
        }
        
        return sections
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Kindle-like background
                backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    header
                    
                    // Main content
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                ForEach(contentSections) { section in
                                    sectionView(section)
                                        .id(section.id)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 120) // Space for controls
                        }
                        .onReceive(speechService.$currentCharacterIndex) { _ in
                            autoScrollToCurrentSection(proxy: proxy)
                        }
                    }
                    
                    Spacer()
                }
                
                // Floating controls
                if showControls {
                    VStack {
                        Spacer()
                        readingControls
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.light) // Kindle-like light mode
        .onAppear {
            setupAutoHideTimer()
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    toggleControls()
                }
        )
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button("Done") {
                speechService.stopReading()
                dismiss()
            }
            .foregroundColor(.orange)
            .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            Text("Recipe Reading")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textColor)
            
            Spacer()
            
            Button(action: toggleControls) {
                Image(systemName: showControls ? "eye.slash" : "eye")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(backgroundColor.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.kindleText.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    // MARK: - Section View
    private func sectionView(_ section: ReadingSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            if section.type != .title {
                Text(section.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.top, section.type == .overview ? 0 : 24)
            }
            
            // Section content with highlighting
            highlightedText(section.content, section: section)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Highlighted Text
    private func highlightedText(_ text: String, section: ReadingSection) -> some View {
        Text(text)
            .font(.system(size: section.type == .title ? 28 : fontSize, weight: section.type == .title ? .bold : .regular))
            .lineSpacing(lineSpacing)
            .foregroundColor(textColor)
            .multilineTextAlignment(.leading)
            .animation(.easeInOut(duration: 0.3), value: speechService.currentCharacterIndex)
    }
    
    // MARK: - Reading Controls
    private var readingControls: some View {
        VStack(spacing: 16) {
            // Progress bar
            if speechService.isPlaying || speechService.isPaused {
                VStack(spacing: 8) {
                    ProgressView(value: speechService.speechProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    
                    Text("\(Int(speechService.speechProgress * 100))% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
            }
            
            // Main controls
            HStack(spacing: 32) {
                // Previous section
                Button(action: speechService.skipToPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .disabled(!speechService.isPlaying && !speechService.isPaused)
                
                // Play/Pause
                Button(action: togglePlayback) {
                    Image(systemName: speechService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                }
                
                // Next section
                Button(action: speechService.skipToNext) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .disabled(!speechService.isPlaying && !speechService.isPaused)
            }
            
            // Reading preferences
            VStack(spacing: 12) {
                HStack {
                    Text("Font Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Slider(value: $fontSize, in: 14...24, step: 1)
                        .frame(width: 120)
                        .accentColor(.orange)
                }
                
                HStack {
                    Text("Line Spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Slider(value: $lineSpacing, in: 4...16, step: 2)
                        .frame(width: 120)
                        .accentColor(.orange)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor.opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -6)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    private func togglePlayback() {
        if speechService.isPlaying {
            speechService.pauseReading()
        } else if speechService.isPaused {
            speechService.resumeReading()
        } else {
            speechService.startReading(recipe: recipe)
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        
        if showControls {
            setupAutoHideTimer()
        }
    }
    
    private func setupAutoHideTimer() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            if !speechService.isPlaying {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
    }
    
    private func autoScrollToCurrentSection(proxy: ScrollViewProxy) {
        guard speechService.isPlaying else { return }
        
        // Calculate which section we're currently in based on character index
        let currentSection = getCurrentSection()
        
        withAnimation(.easeInOut(duration: 0.8)) {
            proxy.scrollTo(currentSection.id, anchor: .top)
        }
    }
    
    private func getCurrentSection() -> ReadingSection {
        // Simplified logic - in reality, you'd track character positions more precisely
        let progress = speechService.speechProgress
        let sectionIndex = Int(progress * Double(contentSections.count))
        return contentSections[min(sectionIndex, contentSections.count - 1)]
    }
}

// MARK: - Supporting Types for Kindle View
struct ReadingSection: Identifiable {
    let id: String
    let title: String
    let content: String
    let type: SectionType
    
    enum SectionType {
        case title, overview, ingredients, instructions, notes
    }
}

// MARK: - Kindle Color Extensions
extension Color {
    static let kindleBackground = Color(red: 0.98, green: 0.97, blue: 0.95) // Warm off-white
    static let kindleText = Color(red: 0.2, green: 0.2, blue: 0.2) // Dark gray for better reading
} 