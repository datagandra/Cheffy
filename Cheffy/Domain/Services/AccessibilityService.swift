import Foundation
import SwiftUI
import os.log

@MainActor
class AccessibilityService: ObservableObject {
    static let shared = AccessibilityService()
    
    private let logger = Logger(subsystem: "com.cheffy.app", category: "Accessibility")
    
    // Accessibility settings
    @Published var isVoiceOverEnabled: Bool = false
    @Published var isDynamicTypeEnabled: Bool = false
    @Published var isReduceMotionEnabled: Bool = false
    @Published var isReduceTransparencyEnabled: Bool = false
    @Published var isHighContrastEnabled: Bool = false
    @Published var isBoldTextEnabled: Bool = false
    @Published var isLargerTextEnabled: Bool = false
    
    // Accessibility preferences
    @Published var preferredTextSize: DynamicTypeSize = .large
    @Published var preferredColorScheme: ColorScheme = .light
    @Published var preferredContrast: UIContrast = .normal
    
    // Accessibility features
    @Published var supportsVoiceControl: Bool = false
    @Published var supportsSwitchControl: Bool = false
    @Published var supportsAssistiveTouch: Bool = false
    
    private init() {
        setupAccessibilityMonitoring()
        updateAccessibilitySettings()
    }
    
    // MARK: - Setup
    
    private func setupAccessibilityMonitoring() {
        // Monitor accessibility changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.assistiveTechnologyDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.contrastStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
    }
    
    // MARK: - Settings Update
    
    private func updateAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isDynamicTypeEnabled = true // Always enabled in SwiftUI
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isHighContrastEnabled = UIAccessibility.isHighContrastEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isLargerTextEnabled = UIAccessibility.isLargerTextEnabled
        
        // Update text size preference
        let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        preferredTextSize = DynamicTypeSize(contentSizeCategory)
        
        // Update color scheme preference
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            preferredColorScheme = windowScene.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        }
        
        // Update contrast preference
        preferredContrast = UIAccessibility.isHighContrastEnabled ? .high : .normal
        
        // Update accessibility features support
        supportsVoiceControl = UIAccessibility.isVoiceControlRunning
        supportsSwitchControl = UIAccessibility.isSwitchControlRunning
        supportsAssistiveTouch = UIAccessibility.isAssistiveTouchRunning
        
        logger.info("Accessibility settings updated - VoiceOver: \(isVoiceOverEnabled), DynamicType: \(isDynamicTypeEnabled)")
    }
    
    // MARK: - Accessibility Helpers
    
    func getAccessibilityLabel(for element: String, context: String = "") -> String {
        var label = element
        
        if isVoiceOverEnabled {
            if !context.isEmpty {
                label = "\(element), \(context)"
            }
            
            // Add additional context for VoiceOver users
            if element.lowercased().contains("recipe") {
                label += ". Tap to view recipe details"
            } else if element.lowercased().contains("generate") {
                label += ". Tap to generate new recipe"
            } else if element.lowercased().contains("favorite") {
                label += ". Tap to add or remove from favorites"
            }
        }
        
        return label
    }
    
    func getAccessibilityHint(for element: String, action: String) -> String {
        guard isVoiceOverEnabled else { return "" }
        
        return "\(action) \(element)"
    }
    
    func getAccessibilityTraits(for element: String) -> AccessibilityTraits {
        var traits: AccessibilityTraits = []
        
        if element.lowercased().contains("button") || element.lowercased().contains("tap") {
            traits.insert(.isButton)
        }
        
        if element.lowercased().contains("image") {
            traits.insert(.isImage)
        }
        
        if element.lowercased().contains("header") {
            traits.insert(.isHeader)
        }
        
        if element.lowercased().contains("search") {
            traits.insert(.isSearchField)
        }
        
        return traits
    }
    
    // MARK: - Dynamic Type Support
    
    func getScaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let baseSize = size
        
        switch preferredTextSize {
        case .xSmall:
            return .system(size: baseSize * 0.8, weight: weight)
        case .small:
            return .system(size: baseSize * 0.9, weight: weight)
        case .medium:
            return .system(size: baseSize, weight: weight)
        case .large:
            return .system(size: baseSize * 1.1, weight: weight)
        case .xLarge:
            return .system(size: baseSize * 1.2, weight: weight)
        case .xxLarge:
            return .system(size: baseSize * 1.3, weight: weight)
        case .xxxLarge:
            return .system(size: baseSize * 1.4, weight: weight)
        @unknown default:
            return .system(size: baseSize, weight: weight)
        }
    }
    
    func getScaledPadding() -> CGFloat {
        switch preferredTextSize {
        case .xSmall, .small:
            return 8
        case .medium:
            return 12
        case .large:
            return 16
        case .xLarge:
            return 20
        case .xxLarge, .xxxLarge:
            return 24
        @unknown default:
            return 12
        }
    }
    
    // MARK: - Motion and Animation
    
    func shouldReduceMotion() -> Bool {
        return isReduceMotionEnabled
    }
    
    func getAnimationDuration() -> Double {
        return shouldReduceMotion() ? 0.1 : 0.3
    }
    
    func getAnimationCurve() -> Animation {
        return shouldReduceMotion() ? .linear(duration: 0.1) : .easeInOut(duration: 0.3)
    }
    
    // MARK: - Color and Contrast
    
    func getAccessibleColor(_ color: Color, forBackground background: Color) -> Color {
        guard isHighContrastEnabled else { return color }
        
        // Ensure sufficient contrast ratio
        // This is a simplified implementation - in production, you'd want proper contrast calculation
        if background == .white || background == .clear {
            return color.opacity(0.9)
        } else {
            return color.opacity(0.8)
        }
    }
    
    func getAccessibleBackgroundColor(_ color: Color) -> Color {
        guard isHighContrastEnabled else { return color }
        
        // Ensure sufficient contrast with text
        if color == .clear {
            return .white.opacity(0.95)
        } else {
            return color.opacity(0.9)
        }
    }
    
    // MARK: - VoiceOver Specific
    
    func announceToVoiceOver(_ message: String) {
        guard isVoiceOverEnabled else { return }
        
        UIAccessibility.post(notification: .announcement, argument: message)
        logger.info("VoiceOver announcement: \(message)")
    }
    
    func setVoiceOverFocus(to element: String) {
        guard isVoiceOverEnabled else { return }
        
        // This would typically be handled by the UI framework
        // In SwiftUI, you'd use accessibilityFocusState
        logger.info("VoiceOver focus set to: \(element)")
    }
    
    // MARK: - Accessibility Testing
    
    func runAccessibilityAudit() -> AccessibilityAuditResult {
        var issues: [AccessibilityIssue] = []
        var recommendations: [String] = []
        
        // Check for common accessibility issues
        if !isVoiceOverEnabled {
            recommendations.append("Test with VoiceOver enabled to ensure proper navigation")
        }
        
        if !isDynamicTypeEnabled {
            recommendations.append("Test with different text sizes to ensure readability")
        }
        
        if !isReduceMotionEnabled {
            recommendations.append("Test with reduced motion to ensure accessibility")
        }
        
        if !isHighContrastEnabled {
            recommendations.append("Test with high contrast to ensure visibility")
        }
        
        // Check for potential issues
        if preferredTextSize == .xxxLarge {
            issues.append(.largeTextSize)
        }
        
        if preferredContrast == .high {
            issues.append(.highContrastMode)
        }
        
        return AccessibilityAuditResult(
            timestamp: Date(),
            issues: issues,
            recommendations: recommendations,
            accessibilityFeatures: getAccessibilityFeatures()
        )
    }
    
    private func getAccessibilityFeatures() -> [String: Bool] {
        return [
            "VoiceOver": isVoiceOverEnabled,
            "DynamicType": isDynamicTypeEnabled,
            "ReduceMotion": isReduceMotionEnabled,
            "ReduceTransparency": isReduceTransparencyEnabled,
            "HighContrast": isHighContrastEnabled,
            "BoldText": isBoldTextEnabled,
            "LargerText": isLargerTextEnabled,
            "VoiceControl": supportsVoiceControl,
            "SwitchControl": supportsSwitchControl,
            "AssistiveTouch": supportsAssistiveTouch
        ]
    }
}

// MARK: - Supporting Types

enum AccessibilityIssue: String, CaseIterable {
    case largeTextSize = "Large Text Size"
    case highContrastMode = "High Contrast Mode"
    case reducedMotion = "Reduced Motion"
    case voiceOverNavigation = "VoiceOver Navigation"
}

struct AccessibilityAuditResult {
    let timestamp: Date
    let issues: [AccessibilityIssue]
    let recommendations: [String]
    let accessibilityFeatures: [String: Bool]
}
