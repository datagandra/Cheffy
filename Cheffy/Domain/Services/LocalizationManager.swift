import Foundation
import SwiftUI

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLocale: Locale = .current
    @Published var isRTL: Bool = false
    
    private let numberFormatter = NumberFormatter()
    private let dateFormatter = DateFormatter()
    private let currencyFormatter = NumberFormatter()
    
    private override init() {
        super.init()
        updateLocale(.current)
    }
    
    // MARK: - Locale Management
    
    func updateLocale(_ locale: Locale) {
        currentLocale = locale
        isRTL = locale.characterDirection == .rightToLeft
        
        // Update formatters
        numberFormatter.locale = locale
        dateFormatter.locale = locale
        currencyFormatter.locale = locale
        
        // Configure formatters
        configureFormatters()
        
        os_log("Locale updated to: %{public}@, RTL: %{public}@", log: .default, type: .info, locale.identifier, isRTL ? "true" : "false")
    }
    
    private func configureFormatters() {
        // Number formatter
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        
        // Date formatter
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        // Currency formatter
        currencyFormatter.numberStyle = .currency
        currencyFormatter.minimumFractionDigits = 2
        currencyFormatter.maximumFractionDigits = 2
    }
    
    // MARK: - String Localization
    
    func localizedString(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, comment: comment)
    }
    
    func localizedString(_ key: String, arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - Number Formatting
    
    func formatNumber(_ number: Double) -> String {
        return numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    func formatNumber(_ number: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = currentLocale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }
    
    // MARK: - Date Formatting
    
    func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = currentLocale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return localizedString("duration_hours_minutes", arguments: hours, minutes)
        } else {
            return localizedString("duration_minutes", arguments: minutes)
        }
    }
    
    // MARK: - Currency Formatting
    
    func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        currencyFormatter.currencyCode = currencyCode
        return currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    // MARK: - RTL Support
    
    func layoutDirection() -> LayoutDirection {
        return isRTL ? .rightToLeft : .leftToRight
    }
    
    func textAlignment() -> TextAlignment {
        return isRTL ? .trailing : .leading
    }
    
    func edgeInsets() -> EdgeInsets {
        return isRTL ? EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0) : EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16)
    }
    
    // MARK: - Localization Testing
    
    func testLocalization() {
        os_log("Testing localization for locale: %{public}@", log: .default, type: .info, currentLocale.identifier)
        
        // Test number formatting
        let testNumber = 1234.56
        let formattedNumber = formatNumber(testNumber)
        os_log("Number formatting: %{public}@ -> %{public}@", log: .default, type: .info, "\(testNumber)", formattedNumber)
        
        // Test date formatting
        let testDate = Date()
        let formattedDate = formatDate(testDate)
        os_log("Date formatting: %{public}@", log: .default, type: .info, formattedDate)
        
        // Test currency formatting
        let testAmount = 99.99
        let formattedCurrency = formatCurrency(testAmount)
        os_log("Currency formatting: %{public}@ -> %{public}@", log: .default, type: .info, "\(testAmount)", formattedCurrency)
        
        // Test RTL
        os_log("RTL support: %{public}@", log: .default, type: .info, isRTL ? "Enabled" : "Disabled")
    }
    
    // MARK: - Locale Validation
    
    func validateLocale(_ locale: Locale) -> Bool {
        // Check if the locale is supported
        let supportedLocales = ["en", "es", "ar"]
        return supportedLocales.contains(locale.languageCode ?? "")
    }
    
    func getSupportedLocales() -> [Locale] {
        return [
            Locale(identifier: "en"),
            Locale(identifier: "es"),
            Locale(identifier: "ar")
        ]
    }
}

// MARK: - Localization Extensions

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, comment: "")
        return String(format: format, arguments: arguments)
    }
}

extension View {
    func localizedLayout() -> some View {
        self.environment(\.layoutDirection, LocalizationManager.shared.layoutDirection())
    }
    
    func localizedTextAlignment() -> some View {
        self.multilineTextAlignment(LocalizationManager.shared.textAlignment())
    }
    
    func rtlPadding() -> some View {
        self.padding(LocalizationManager.shared.edgeInsets())
    }
}

// MARK: - Localization Environment

struct LocalizationKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
}

// MARK: - Localization Utilities

struct LocalizedText: View {
    let key: String
    let arguments: [CVarArg]
    
    init(_ key: String, arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }
    
    var body: some View {
        if arguments.isEmpty {
            Text(key.localized)
        } else {
            Text(key.localized(with: arguments))
        }
    }
}

struct LocalizedLabel: View {
    let title: String
    let systemImage: String
    let arguments: [CVarArg]
    
    init(_ title: String, systemImage: String, arguments: CVarArg...) {
        self.title = title
        self.systemImage = systemImage
        self.arguments = arguments
    }
    
    var body: some View {
        if arguments.isEmpty {
            Label(title.localized, systemImage: systemImage)
        } else {
            Label(title.localized(with: arguments), systemImage: systemImage)
        }
    }
} 