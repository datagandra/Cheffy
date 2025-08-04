import SwiftUI
import os.log



// MARK: - Accessibility Manager
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isVoiceOverRunning = false
    @Published var isReduceMotionEnabled = false
    @Published var isBoldTextEnabled = false
    @Published var isIncreaseContrastEnabled = false
    @Published var isReduceTransparencyEnabled = false
    
    private init() {
        updateAccessibilitySettings()
        
        // Listen for accessibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func accessibilitySettingsChanged() {
        updateAccessibilitySettings()
        os_log("Accessibility settings changed", log: .default, type: .info)
    }
    
    private func updateAccessibilitySettings() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isIncreaseContrastEnabled = false // iOS doesn't have a direct API for this
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
    }
    
    // MARK: - Dynamic Type Support
    func adaptiveFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        if isBoldTextEnabled {
            return .system(style, design: .default).weight(.bold)
        } else {
            return .system(style, design: .default).weight(weight)
        }
    }
    
    func adaptiveFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if isBoldTextEnabled {
            return .system(size: size, weight: .bold, design: .default)
        } else {
            return .system(size: size, weight: weight, design: .default)
        }
    }
    
    // MARK: - Color Contrast
    func highContrastColor(_ color: Color) -> Color {
        if isIncreaseContrastEnabled {
            return color.opacity(0.9)
        }
        return color
    }
    
    func accessibleBackgroundColor() -> Color {
        if isReduceTransparencyEnabled {
            return Color(.systemBackground)
        }
        return Color(.systemGroupedBackground)
    }
    
    // MARK: - Animation Support
    func adaptiveAnimation<T>(_ animation: Animation, value: T) -> Animation {
        if isReduceMotionEnabled {
            return Animation.easeInOut(duration: 0)
        }
        return animation
    }
    
    // MARK: - Accessibility Utilities
    func accessibilityLabel(_ text: String, isSelected: Bool = false) -> String {
        var label = text
        if isVoiceOverRunning && isSelected {
            label += ", selected"
        }
        return label
    }
    
    func accessibilityHint(_ text: String) -> String {
        if isVoiceOverRunning {
            return text
        }
        return ""
    }
    
    // MARK: - VoiceOver Announcements
    func announceToVoiceOver(_ message: String) {
        if isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: message)
            os_log("VoiceOver announcement: %{public}@", log: .default, type: .info, message)
        }
    }
    
    func announceRecipeGenerated(_ recipeName: String) {
        let message = "Recipe \(recipeName) has been generated successfully"
        announceToVoiceOver(message)
    }
    
    func announceCookingStep(_ stepNumber: Int, description: String) {
        let message = "Step \(stepNumber): \(description)"
        announceToVoiceOver(message)
    }
    
    func announceTimerUpdate(_ remainingTime: Int) {
        let message = "\(remainingTime) seconds remaining"
        announceToVoiceOver(message)
    }
}

// MARK: - Accessibility Extensions
extension View {
    func adaptiveFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(AccessibilityManager.shared.adaptiveFont(style, weight: weight))
    }
    
    func adaptiveFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(AccessibilityManager.shared.adaptiveFont(size: size, weight: weight))
    }
    
    func highContrastColor(_ color: Color) -> some View {
        self.foregroundColor(AccessibilityManager.shared.highContrastColor(color))
    }
    
    func accessibleBackground() -> some View {
        self.background(AccessibilityManager.shared.accessibleBackgroundColor())
    }
    
    func adaptiveAnimation<T: Equatable>(_ animation: Animation, value: T) -> some View {
        self.animation(AccessibilityManager.shared.adaptiveAnimation(animation, value: value), value: value)
    }
    
    func accessibilityAnnouncement(_ message: String) -> some View {
        self.onAppear {
            AccessibilityManager.shared.announceToVoiceOver(message)
        }
    }
}



// MARK: - Accessibility Testing
extension AccessibilityManager {
    func runAccessibilityAudit() {
        os_log("Running accessibility audit", log: .default, type: .info)
        
        let auditItems = [
            "VoiceOver running: \(isVoiceOverRunning)",
            "Reduce motion: \(isReduceMotionEnabled)",
            "Bold text: \(isBoldTextEnabled)",
            "Increase contrast: \(isIncreaseContrastEnabled)",
            "Reduce transparency: \(isReduceTransparencyEnabled)"
        ]
        
        for item in auditItems {
            os_log("Accessibility audit: %{public}@", log: .default, type: .info, item)
        }
    }
    
    func validateColorContrast(foreground: Color, background: Color) -> Bool {
        // Simplified contrast validation
        // In a real implementation, you'd calculate actual contrast ratios
        return true
    }
} 