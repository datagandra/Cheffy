import Foundation
import AVFoundation
import SwiftUI

@MainActor
class CookingGuideViewModel: NSObject, ObservableObject {
    @Published var currentStepIndex = 0
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentStepDescription = ""
    
    private let synthesizer = AVSpeechSynthesizer()
    let recipe: Recipe
    
    init(recipe: Recipe) {
        self.recipe = recipe
        super.init()
        setupSpeechSynthesizer()
        updateCurrentStepDescription()
    }
    
    // MARK: - Speech Synthesizer Setup
    
    private func setupSpeechSynthesizer() {
        synthesizer.delegate = self
    }
    
    // MARK: - Cooking Guide Controls
    
    func startCooking() {
        isPlaying = true
        isPaused = false
        speakCurrentStep()
    }
    
    func pauseCooking() {
        isPaused = true
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func resumeCooking() {
        isPaused = false
        synthesizer.continueSpeaking()
    }
    
    func stopCooking() {
        isPlaying = false
        isPaused = false
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    func nextStep() {
        guard currentStepIndex < recipe.steps.count - 1 else {
            stopCooking()
            return
        }
        
        currentStepIndex += 1
        updateCurrentStepDescription()
        
        if isPlaying && !isPaused {
            speakCurrentStep()
        }
    }
    
    func previousStep() {
        guard currentStepIndex > 0 else { return }
        
        currentStepIndex -= 1
        updateCurrentStepDescription()
        
        if isPlaying && !isPaused {
            speakCurrentStep()
        }
    }
    
    func repeatCurrentStep() {
        speakCurrentStep()
    }
    
    // MARK: - Speech Generation
    
    private func speakCurrentStep() {
        guard currentStepIndex < recipe.steps.count else { return }
        
        let step = recipe.steps[currentStepIndex]
        let stepText = generateStepText(for: step)
        
        let utterance = AVSpeechUtterance(string: stepText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        utterance.preUtteranceDelay = 0.5
        utterance.postUtteranceDelay = 1.0
        
        synthesizer.speak(utterance)
    }
    
    private func generateStepText(for step: CookingStep) -> String {
        var text = "Step \(step.stepNumber). \(step.description)"
        
        if let duration = step.duration {
            text += " This step takes approximately \(duration) minutes."
        }
        
        if let temperature = step.temperature {
            text += " Set the temperature to \(Int(temperature)) degrees Celsius."
        }
        
        if let tips = step.tips {
            text += " Chef's tip: \(tips)"
        }
        
        return text
    }
    
    func updateCurrentStepDescription() {
        guard currentStepIndex < recipe.steps.count else {
            currentStepDescription = "Cooking complete!"
            return
        }
        
        let step = recipe.steps[currentStepIndex]
        currentStepDescription = step.description
    }
    
    // MARK: - Computed Properties
    
    var currentStep: CookingStep? {
        guard currentStepIndex < recipe.steps.count else { return nil }
        return recipe.steps[currentStepIndex]
    }
    
    var totalSteps: Int {
        recipe.steps.count
    }
    
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStepIndex + 1) / Double(totalSteps)
    }
    
    var isFirstStep: Bool {
        currentStepIndex == 0
    }
    
    var isLastStep: Bool {
        currentStepIndex == totalSteps - 1
    }
    
    var stepNumberText: String {
        "Step \(currentStepIndex + 1) of \(totalSteps)"
    }
    
    // MARK: - Accessibility
    
    var cookingGuideAccessibilityLabel: String {
        "Cooking guide for \(recipe.name)"
    }
    
    var currentStepAccessibilityLabel: String {
        guard let step = currentStep else { return "Cooking complete" }
        return "Step \(step.stepNumber) of \(totalSteps): \(step.description)"
    }
    
    var playButtonAccessibilityLabel: String {
        if isPlaying {
            return isPaused ? "Resume cooking instructions" : "Pause cooking instructions"
        } else {
            return "Start cooking instructions"
        }
    }
    
    var nextButtonAccessibilityLabel: String {
        isLastStep ? "Finish cooking" : "Next step"
    }
    
    var previousButtonAccessibilityLabel: String {
        isFirstStep ? "First step" : "Previous step"
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension CookingGuideViewModel: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Auto-advance to next step if playing and not paused
        Task { @MainActor in
            if self.isPlaying && !self.isPaused && !self.isLastStep {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.nextStep()
                }
            } else if self.isLastStep {
                self.stopCooking()
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // Handle pause if needed
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        // Handle resume if needed
    }
} 