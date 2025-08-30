import SwiftUI

/// Kindle-style reading view for recipes with voice narration and auto-scroll
struct KindleReadingView: View {
    let recipe: Recipe
    @StateObject private var speechService = TextToSpeechService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Reading preferences
    @State private var fontSize: CGFloat = 18
    @State private var lineSpacing: CGFloat = 8
    @State private var backgroundColor: Color = .systemBackground
    @State private var textColor: Color = .primary
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
                // Background
                backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    header
                    
                    // Main content
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                ForEach(contentSections) { section in
                                    sectionView(section)
                                        .id(section.id)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100) // Space for controls
                        }
                        .onAppear {

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
        .onReceive(speechService.$currentCharacterIndex) { characterIndex in

        }
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
            
            Spacer()
            
            Text("Recipe Reading")
                .font(.headline)
                .foregroundColor(textColor)
            
            Spacer()
            
            Button(action: toggleControls) {
                Image(systemName: showControls ? "eye.slash" : "eye")
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(backgroundColor.opacity(0.95))
    }
    
    // MARK: - Section View
    private func sectionView(_ section: ReadingSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            if section.type != .title {
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(textColor)
                    .padding(.top, section.type == .overview ? 0 : 20)
            }
            
            // Section content with highlighting
            highlightedText(section.content, section: section)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Highlighted Text
    private func highlightedText(_ text: String, section: ReadingSection) -> some View {
        let attributedString = createAttributedString(text, section: section)
        
        return Text(AttributedString(attributedString))
            .font(section.type == .title ? .largeTitle : .system(size: fontSize))
            .lineSpacing(lineSpacing)
            .foregroundColor(textColor)
            .multilineTextAlignment(.leading)
            .animation(.easeInOut(duration: 0.3), value: speechService.currentCharacterIndex)
    }
    
    private func createAttributedString(_ text: String, section: ReadingSection) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // Base attributes
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: fontSize), range: range)
        attributedString.addAttribute(.foregroundColor, value: UIColor(textColor), range: range)
        
        // Highlight current reading position
        if speechService.isPlaying, let currentRange = speechService.currentWordRange {
            // Simple highlighting - in a real implementation, you'd need to map global position to section position
            let highlightRange = NSRange(location: min(currentRange.location, text.count - 1), 
                                       length: min(currentRange.length, text.count - currentRange.location))
            
            if highlightRange.location >= 0 && highlightRange.location < text.count {
                attributedString.addAttribute(.backgroundColor, 
                                            value: UIColor.systemYellow.withAlphaComponent(0.3), 
                                            range: highlightRange)
                attributedString.addAttribute(.foregroundColor, 
                                            value: UIColor.black, 
                                            range: highlightRange)
            }
        }
        
        return attributedString
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
                .padding(.horizontal, 20)
            }
            
            // Main controls
            HStack(spacing: 24) {
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
                        .font(.system(size: 44))
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
                        .frame(width: 100)
                        .accentColor(.orange)
                }
                
                HStack {
                    Text("Line Spacing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Slider(value: $lineSpacing, in: 4...16, step: 2)
                        .frame(width: 100)
                        .accentColor(.orange)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor.opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
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
    

    
    private func getCurrentSection() -> ReadingSection {
        // Simplified logic - in reality, you'd track character positions more precisely
        let progress = speechService.speechProgress
        let sectionIndex = Int(progress * Double(contentSections.count))
        return contentSections[min(sectionIndex, contentSections.count - 1)]
    }
}

// MARK: - Supporting Types
struct ReadingSection: Identifiable {
    let id: String
    let title: String
    let content: String
    let type: SectionType
    
    enum SectionType {
        case title, overview, ingredients, instructions, notes
    }
}

// MARK: - Extensions
extension Color {
    static let systemBackground = Color(UIColor.systemBackground)
    static let primary = Color(UIColor.label)
    static let secondary = Color(UIColor.secondaryLabel)
}

// MARK: - Preview
#Preview {
    KindleReadingView(recipe: Recipe(
        id: UUID(),
        title: "Sample Recipe",
        name: "Sample Recipe",
        cuisine: .italian,
        difficulty: .medium,
        prepTime: 15,
        cookTime: 30,
        servings: 4,
        ingredients: [
            Ingredient(id: UUID(), name: "Sample Ingredient", amount: 1.0, unit: "cup", notes: nil)
        ],
        steps: [
            CookingStep(id: UUID(), stepNumber: 1, description: "Sample cooking step", duration: 5, temperature: nil, tips: nil)
        ],
        winePairings: [],
        dietaryNotes: [],
        platingTips: "Sample plating tips",
        chefNotes: "Sample chef notes",
        imageURL: nil,
        stepImages: [],
        createdAt: Date(),
        isFavorite: false
    ))
}