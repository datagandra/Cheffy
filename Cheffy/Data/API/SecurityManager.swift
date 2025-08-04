import Foundation
import Security
import os.log
import KeychainAccess

// MARK: - Security Manager
class SecurityManager: NSObject {
    static let shared = SecurityManager()
    
    // Certificate pinning for Google APIs
    private let googleAPICertificateHashes = [
        // Google's root CA certificate hashes (example - should be updated with actual hashes)
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    ]
    
    // Security headers for API requests
    private let securityHeaders: [String: String] = [
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Referrer-Policy": "strict-origin-when-cross-origin"
    ]
    
    private override init() {
        super.init()
    }
    
    // MARK: - SSL Certificate Pinning
    func createSecureURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        
        // Add security headers to all requests
        config.httpAdditionalHeaders = securityHeaders
        
        let session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
        
        return session
    }
    
    // MARK: - Certificate Validation
    private func validateCertificate(_ serverTrust: SecTrust, domain: String) -> Bool {
        // Check if the domain is one we want to pin
        guard shouldPinCertificate(for: domain) else {
            return true // Allow default validation for non-pinned domains
        }
        
        // Get the certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        guard certificateCount > 0 else {
            os_log("Certificate validation failed: No certificates in chain", log: .default, type: .error)
            return false
        }
        
        // Validate each certificate in the chain
        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }
            
            if validateCertificateHash(certificate) {
                os_log("Certificate validation successful for domain: %{public}@", log: .default, type: .info, domain)
                return true
            }
        }
        
        os_log("Certificate validation failed for domain: %{public}@", log: .default, type: .error, domain)
        return false
    }
    
    private func shouldPinCertificate(for domain: String) -> Bool {
        let pinnedDomains = [
            "generativelanguage.googleapis.com",
            "googleapis.com"
        ]
        
        return pinnedDomains.contains { domain.contains($0) }
    }
    
    private func validateCertificateHash(_ certificate: SecCertificate) -> Bool {
        let data = SecCertificateCopyData(certificate) as Data
        let hash = SHA256(data: data)
        
        return googleAPICertificateHashes.contains(hash)
    }
    
    // MARK: - SHA256 Hash Function
    private func SHA256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        
        let hashData = Data(hash)
        return "sha256/" + hashData.base64EncodedString()
    }
    
    // MARK: - Data Anonymization
    func anonymizeUserData(_ data: String) -> String {
        // Remove or hash sensitive information
        var anonymized = data
        
        // Hash email addresses
        let emailPattern = #"([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"#
        anonymized = anonymized.replacingOccurrences(
            of: emailPattern,
            with: "[EMAIL_HASHED]",
            options: .regularExpression
        )
        
        // Hash API keys
        let apiKeyPattern = #"AIza[A-Za-z0-9_-]{35}"#
        anonymized = anonymized.replacingOccurrences(
            of: apiKeyPattern,
            with: "[API_KEY_HASHED]",
            options: .regularExpression
        )
        
        return anonymized
    }
    
    // MARK: - Secure Random Generation
    func generateSecureRandomString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
    
    // MARK: - Input Sanitization
    func sanitizeInput(_ input: String) -> String {
        // Remove potentially dangerous characters
        let dangerousChars = ["<", ">", "\"", "'", "&", "script", "javascript"]
        var sanitized = input
        
        for char in dangerousChars {
            sanitized = sanitized.replacingOccurrences(of: char, with: "")
        }
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - URLSessionDelegate for Certificate Pinning
extension SecurityManager: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let protectionSpace = challenge.protectionSpace
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let domain = protectionSpace.host
        
        if validateCertificate(serverTrust, domain: domain) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            os_log("Certificate pinning failed for domain: %{public}@", log: .default, type: .error, domain)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Privacy Manager
class PrivacyManager: ObservableObject {
    static let shared = PrivacyManager()
    
    @Published var analyticsEnabled: Bool = false
    @Published var crashReportingEnabled: Bool = false
    @Published var dataCollectionEnabled: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadPrivacySettings()
    }
    
    // MARK: - Privacy Settings Management
    func loadPrivacySettings() {
        analyticsEnabled = userDefaults.bool(forKey: "privacy_analytics_enabled")
        crashReportingEnabled = userDefaults.bool(forKey: "privacy_crash_reporting_enabled")
        dataCollectionEnabled = userDefaults.bool(forKey: "privacy_data_collection_enabled")
    }
    
    func updatePrivacySettings(
        analytics: Bool? = nil,
        crashReporting: Bool? = nil,
        dataCollection: Bool? = nil
    ) {
        if let analytics = analytics {
            analyticsEnabled = analytics
            userDefaults.set(analytics, forKey: "privacy_analytics_enabled")
        }
        
        if let crashReporting = crashReporting {
            crashReportingEnabled = crashReporting
            userDefaults.set(crashReporting, forKey: "privacy_crash_reporting_enabled")
        }
        
        if let dataCollection = dataCollection {
            dataCollectionEnabled = dataCollection
            userDefaults.set(dataCollection, forKey: "privacy_data_collection_enabled")
        }
        
        os_log("Privacy settings updated - analytics: %{public}@, crashReporting: %{public}@, dataCollection: %{public}@", 
               log: .default, type: .info, 
               analyticsEnabled ? "enabled" : "disabled",
               crashReportingEnabled ? "enabled" : "disabled",
               dataCollectionEnabled ? "enabled" : "disabled")
    }
    
    // MARK: - Anonymized Analytics
    func logAnalyticsEvent(_ event: String, parameters: [String: Any]? = nil) {
        guard analyticsEnabled else { return }
        
        var anonymizedParams: [String: Any] = [:]
        
        if let parameters = parameters {
            for (key, value) in parameters {
                if let stringValue = value as? String {
                    anonymizedParams[key] = SecurityManager.shared.anonymizeUserData(stringValue)
                } else {
                    anonymizedParams[key] = value
                }
            }
        }
        
        // Log anonymized event
        os_log("Analytics Event: %{public}@ - Parameters: %{public}@", 
               log: .default, type: .info, 
               event, anonymizedParams.description)
    }
    
    // MARK: - Crash Reporting
    func logCrashReport(_ error: Error, context: String? = nil) {
        guard crashReportingEnabled else { return }
        
        let anonymizedContext = context.map { SecurityManager.shared.anonymizeUserData($0) }
        
        os_log("Crash Report - Error: %{public}@, Context: %{public}@", 
               log: .default, type: .error, 
               error.localizedDescription, anonymizedContext ?? "none")
    }
    
    // MARK: - Data Collection
    func shouldCollectData() -> Bool {
        return dataCollectionEnabled
    }
    
    func collectUserData(_ data: [String: Any]) -> [String: Any] {
        guard dataCollectionEnabled else { return [:] }
        
        var anonymizedData: [String: Any] = [:]
        
        for (key, value) in data {
            if let stringValue = value as? String {
                anonymizedData[key] = SecurityManager.shared.anonymizeUserData(stringValue)
            } else {
                anonymizedData[key] = value
            }
        }
        
        return anonymizedData
    }
}

// MARK: - CommonCrypto Import (for SHA256)
import CommonCrypto 