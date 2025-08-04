import Foundation
import Speech
import AVFoundation
import Combine

class VoiceManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var error: String?
    @Published var voiceEnabled = true
    @Published var voiceSpeed: Float = 0.5
    @Published var voiceVolume: Float = 0.8
    @Published var voicePitch: Float = 1.0
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
        requestSpeechAuthorization()
    }
    
    // MARK: - Speech Authorization
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.error = nil
                case .denied:
                    self?.error = "Speech recognition permission denied"
                case .restricted:
                    self?.error = "Speech recognition restricted on this device"
                case .notDetermined:
                    self?.error = "Speech recognition not yet authorized"
                @unknown default:
                    self?.error = "Speech recognition authorization failed"
                }
            }
        }
    }
    
    // MARK: - Voice Narration Functions
    func narrateRecipeStep(_ step: CookingStep, recipeName: String, stepNumber: Int, totalSteps: Int) {
        guard voiceEnabled else { return }
        
        let narration = createDetailedStepNarration(step: step, recipeName: recipeName, stepNumber: stepNumber, totalSteps: totalSteps)
        speak(narration)
    }
    
    func narrateTimerStart(duration: Int, stepDescription: String) {
        guard voiceEnabled else { return }
        
        let minutes = duration / 60
        let seconds = duration % 60
        let timeString = minutes > 0 ? "\(minutes) minutes and \(seconds) seconds" : "\(seconds) seconds"
        
        let narration = "Timer started for \(timeString). \(stepDescription). I'll announce when the time is up."
        speak(narration)
    }
    
    func narrateTimerWarning(remainingTime: Int) {
        guard voiceEnabled else { return }
        
        let narration: String
        if remainingTime <= 30 {
            narration = "Warning: Only \(remainingTime) seconds remaining. Check your food now."
        } else if remainingTime <= 60 {
            narration = "One minute remaining. Start preparing for the next step."
        } else {
            let minutes = remainingTime / 60
            narration = "\(minutes) minutes remaining. Continue with the current step."
        }
        
        speak(narration)
    }
    
    func narrateTimerComplete(stepDescription: String) {
        guard voiceEnabled else { return }
        
        let narration = "Timer complete! \(stepDescription) is ready. You can now proceed to the next step."
        speak(narration)
    }
    
    func narrateStepTransition(fromStep: Int, toStep: Int, recipeName: String) {
        guard voiceEnabled else { return }
        
        let narration = "Moving from step \(fromStep) to step \(toStep) of \(recipeName). Get ready for the next instructions."
        speak(narration)
    }
    
    func narrateRecipeComplete(recipeName: String) {
        guard voiceEnabled else { return }
        
        let narration = "Congratulations! You've completed \(recipeName). Your dish is ready to serve. Enjoy your meal!"
        speak(narration)
    }
    
    func narrateCookingTip(_ tip: String) {
        guard voiceEnabled else { return }
        
        let narration = "Chef's tip: \(tip)"
        speak(narration)
    }
    
    func narrateTemperatureGuidance(temperature: Double) {
        guard voiceEnabled else { return }
        
        let narration = "Set your cooking temperature to \(Int(temperature)) degrees Celsius. This is crucial for proper cooking."
        speak(narration)
    }
    
    func narrateIngredientReminder(_ ingredient: String, amount: String) {
        guard voiceEnabled else { return }
        
        let narration = "Remember to have \(amount) of \(ingredient) ready for this step."
        speak(narration)
    }
    
    // MARK: - Private Helper Functions
    private func createDetailedStepNarration(step: CookingStep, recipeName: String, stepNumber: Int, totalSteps: Int) -> String {
        var narration = "Step \(stepNumber) of \(totalSteps) for \(recipeName). "
        
        // Add step description
        narration += step.description
        
        // Add timing information
        if let duration = step.duration {
            let minutes = duration / 60
            let seconds = duration % 60
            if minutes > 0 {
                narration += " This step will take approximately \(minutes) minutes"
                if seconds > 0 {
                    narration += " and \(seconds) seconds"
                }
            } else {
                narration += " This step will take approximately \(seconds) seconds"
            }
            narration += ". I'll start a timer for you."
        }
        
        // Add temperature guidance
        if let temperature = step.temperature {
            narration += " Set your cooking temperature to \(Int(temperature)) degrees Celsius."
        }
        
        // Add chef tips
        if let tips = step.tips, !tips.isEmpty {
            narration += " Chef's tip: \(tips)"
        }
        
        return narration
    }
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = voiceSpeed
        utterance.pitchMultiplier = voicePitch
        utterance.volume = voiceVolume
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Speech Recognition Functions
    func startListening() {
        guard !isListening else { return }
        
        // Reset any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }
        
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            error = "Unable to create speech recognition request"
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }
                if error != nil {
                    self?.stopListening()
                }
            }
        }
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            self.error = "Failed to start audio engine: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isListening = false
    }
    
    // MARK: - Voice Control Functions
    func toggleVoice() {
        voiceEnabled.toggle()
        if !voiceEnabled {
            stopSpeaking()
        }
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func adjustVoiceSpeed(_ speed: Float) {
        voiceSpeed = max(0.1, min(1.0, speed))
    }
    
    func adjustVoiceVolume(_ volume: Float) {
        voiceVolume = max(0.0, min(1.0, volume))
    }
    
    func adjustVoicePitch(_ pitch: Float) {
        voicePitch = max(0.5, min(2.0, pitch))
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension VoiceManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
} 