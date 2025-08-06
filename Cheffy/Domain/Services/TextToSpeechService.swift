import Foundation
import AVFoundation
import Combine

/// Service for handling text-to-speech functionality with scroll synchronization
class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()
    
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
extension TextToSpeechService: AVSpeechSynthesizerDelegate {
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