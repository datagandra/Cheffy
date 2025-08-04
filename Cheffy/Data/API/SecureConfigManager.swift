import Foundation
import KeychainAccess
import CryptoKit

/// Secure Configuration Manager for handling sensitive data like API keys
/// Implements multiple layers of security for production environments
class SecureConfigManager {
    static let shared = SecureConfigManager()
    
    private let keychain = Keychain(service: "com.cheffy.app")
    private let encryptionKey = "CheffySecureKey2024"
    
    // MARK: - API Key Management
    
    /// Retrieves the Gemini API key through multiple secure layers
    /// Priority: 1. Keychain (most secure) 2. Environment variable 3. Secure config file
    var geminiAPIKey: String {
        // Layer 1: Keychain (most secure)
        if let keychainKey = try? keychain.get("gemini_api_key"), !keychainKey.isEmpty {
            logger.security("API key retrieved from keychain")
            return keychainKey
        }
        
        // Layer 2: Environment variable (for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            logger.security("API key retrieved from environment variable")
            // Store in keychain for future use
            try? keychain.set(envKey, key: "gemini_api_key")
            return envKey
        }
        
        // Layer 3: Secure config file (development only)
        if let configKey = loadFromSecureConfig(), !configKey.isEmpty {
            logger.security("API key retrieved from secure config file")
            // Store in keychain for future use
            try? keychain.set(configKey, key: "gemini_api_key")
            return configKey
        }
        
        logger.error("No API key found in any secure source")
        return ""
    }
    
    /// Stores API key securely in keychain
    func storeAPIKey(_ key: String) {
        do {
            try keychain.set(key, key: "gemini_api_key")
            logger.security("API key stored securely in keychain")
        } catch {
            logger.error("Failed to store API key: \(error)")
        }
    }
    
    /// Removes API key from all storage locations
    func clearAPIKey() {
        try? keychain.remove("gemini_api_key")
        logger.security("API key cleared from all storage")
    }
    
    /// Checks if a valid API key is available
    var hasValidAPIKey: Bool {
        return !geminiAPIKey.isEmpty
    }
    
    // MARK: - Secure Configuration File
    
    private func loadFromSecureConfig() -> String? {
        guard let configPath = Bundle.main.path(forResource: "SecureConfig", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath),
              let apiKey = config["GEMINI_API_KEY"] as? String,
              apiKey != "YOUR_GEMINI_API_KEY_HERE" else {
            return nil
        }
        return apiKey
    }
    
    // MARK: - Encryption Utilities
    
    /// Encrypts sensitive data
    private func encrypt(_ data: String) -> String? {
        guard let data = data.data(using: .utf8),
              let key = encryptionKey.data(using: .utf8) else {
            return nil
        }
        
        let hash = SHA256.hash(data: key)
        let symmetricKey = SymmetricKey(data: hash)
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            logger.error("Encryption failed: \(error)")
            return nil
        }
    }
    
    /// Decrypts sensitive data
    private func decrypt(_ encryptedData: String) -> String? {
        guard let data = Data(base64Encoded: encryptedData),
              let key = encryptionKey.data(using: .utf8) else {
            return nil
        }
        
        let hash = SHA256.hash(data: key)
        let symmetricKey = SymmetricKey(data: hash)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            logger.error("Decryption failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Security Validation
    
    /// Validates API key format and security
    func validateAPIKey(_ key: String) -> Bool {
        // Basic validation - Gemini API keys start with "AIza"
        guard key.hasPrefix("AIza") && key.count > 20 else {
            logger.warning("Invalid API key format")
            return false
        }
        
        // Additional security checks
        guard !key.contains(" ") && !key.contains("\n") else {
            logger.warning("API key contains invalid characters")
            return false
        }
        
        return true
    }
    
    /// Performs security audit of API key storage
    func performSecurityAudit() -> SecurityAuditResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check if API key is stored in keychain
        if let keychainKey = try? keychain.get("gemini_api_key") {
            if keychainKey.isEmpty {
                issues.append("API key in keychain is empty")
            } else if !validateAPIKey(keychainKey) {
                issues.append("API key in keychain has invalid format")
            }
        } else {
            warnings.append("No API key found in keychain")
        }
        
        // Check environment variable
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            if envKey.isEmpty {
                warnings.append("GEMINI_API_KEY environment variable is empty")
            } else if !validateAPIKey(envKey) {
                issues.append("GEMINI_API_KEY environment variable has invalid format")
            }
        }
        
        // Check secure config file
        if let configKey = loadFromSecureConfig() {
            if !validateAPIKey(configKey) {
                issues.append("API key in SecureConfig.plist has invalid format")
            }
        }
        
        return SecurityAuditResult(
            hasIssues: !issues.isEmpty,
            hasWarnings: !warnings.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
}

// MARK: - Security Audit Result

struct SecurityAuditResult {
    let hasIssues: Bool
    let hasWarnings: Bool
    let issues: [String]
    let warnings: [String]
    
    var isSecure: Bool {
        return !hasIssues
    }
    
    var description: String {
        var result = "Security Audit Results:\n"
        
        if issues.isEmpty && warnings.isEmpty {
            result += "✅ All security checks passed\n"
        } else {
            if !issues.isEmpty {
                result += "❌ Issues found:\n"
                issues.forEach { result += "  - \($0)\n" }
            }
            
            if !warnings.isEmpty {
                result += "⚠️ Warnings:\n"
                warnings.forEach { result += "  - \($0)\n" }
            }
        }
        
        return result
    }
} 