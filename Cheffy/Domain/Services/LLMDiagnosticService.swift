import Foundation
import Network
import os.log
import KeychainAccess

/// Diagnostic service for troubleshooting LLM connection issues
class LLMDiagnosticService: ObservableObject {
    static let shared = LLMDiagnosticService()
    
    @Published var diagnosticResults: [DiagnosticResult] = []
    @Published var isRunningDiagnostics = false
    
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "LLMDiagnosticQueue")
    
    struct DiagnosticResult {
        let category: String
        let test: String
        let status: Status
        let message: String
        let timestamp: Date
        
        enum Status {
            case success
            case warning
            case error
        }
    }
    
    init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.checkNetworkConnectivity(path: path)
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    private func checkNetworkConnectivity(path: NWPath) {
        let result = DiagnosticResult(
            category: "Network",
            test: "Internet Connectivity",
            status: path.status == .satisfied ? .success : .error,
            message: path.status == .satisfied ? "Internet connection available" : "No internet connection",
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.diagnosticResults.append(result)
        }
    }
    
    // MARK: - Diagnostic Tests
    
    func runFullDiagnostics() async {
        await MainActor.run {
            isRunningDiagnostics = true
            diagnosticResults.removeAll()
        }
        
        // Test 1: API Key Configuration
        await testAPIKeyConfiguration()
        
        // Test 2: Network Connectivity
        await testNetworkConnectivity()
        
        // Test 3: API Endpoint Reachability
        await testAPIEndpointReachability()
        
        // Test 4: Secure Configuration
        await testSecureConfiguration()
        
        // Test 5: Keychain Access
        await testKeychainAccess()
        
        await MainActor.run {
            isRunningDiagnostics = false
        }
    }
    
    private func testAPIKeyConfiguration() async {
        let secureConfig = SecureConfigManager.shared
        let hasKey = secureConfig.hasValidAPIKey
        let key = secureConfig.geminiAPIKey
        
        let result = DiagnosticResult(
            category: "API Key",
            test: "Configuration",
            status: hasKey ? .success : .error,
            message: hasKey ? "Valid API key found" : "No valid API key configured",
            timestamp: Date()
        )
        
        await MainActor.run {
            diagnosticResults.append(result)
        }
        
        // Additional key format validation
        if !key.isEmpty {
            let isValidFormat = secureConfig.validateAPIKey(key)
            let formatResult = DiagnosticResult(
                category: "API Key",
                test: "Format Validation",
                status: isValidFormat ? .success : .error,
                message: isValidFormat ? "API key format is valid" : "API key format is invalid",
                timestamp: Date()
            )
            
            await MainActor.run {
                diagnosticResults.append(formatResult)
            }
        }
    }
    
    private func testNetworkConnectivity() async {
        let url = URL(string: "https://generativelanguage.googleapis.com")!
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                let result = DiagnosticResult(
                    category: "Network",
                    test: "Google API Reachability",
                    status: httpResponse.statusCode == 200 ? .success : .warning,
                    message: "Google API endpoint reachable (Status: \(httpResponse.statusCode))",
                    timestamp: Date()
                )
                
                await MainActor.run {
                    diagnosticResults.append(result)
                }
            }
        } catch {
            let result = DiagnosticResult(
                category: "Network",
                test: "Google API Reachability",
                status: .error,
                message: "Failed to reach Google API: \(error.localizedDescription)",
                timestamp: Date()
            )
            
            await MainActor.run {
                diagnosticResults.append(result)
            }
        }
    }
    
    private func testAPIEndpointReachability() async {
        let secureConfig = SecureConfigManager.shared
        guard let apiKey = secureConfig.geminiAPIKey.isEmpty ? nil : secureConfig.geminiAPIKey else {
            let result = DiagnosticResult(
                category: "API",
                test: "Endpoint Test",
                status: .error,
                message: "Cannot test endpoint without API key",
                timestamp: Date()
            )
            
            await MainActor.run {
                diagnosticResults.append(result)
            }
            return
        }
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Simple test request
        let testRequest = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: "Hello")])],
            generationConfig: GeminiGenerationConfig(temperature: 0.1, maxOutputTokens: 10)
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(testRequest)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let status: DiagnosticResult.Status
                let message: String
                
                switch httpResponse.statusCode {
                case 200:
                    status = .success
                    message = "API endpoint responding correctly"
                case 401:
                    status = .error
                    message = "API key authentication failed"
                case 403:
                    status = .error
                    message = "API key lacks required permissions"
                case 429:
                    status = .warning
                    message = "API rate limit exceeded"
                default:
                    status = .error
                    message = "API endpoint error (Status: \(httpResponse.statusCode))"
                }
                
                let result = DiagnosticResult(
                    category: "API",
                    test: "Endpoint Test",
                    status: status,
                    message: message,
                    timestamp: Date()
                )
                
                await MainActor.run {
                    diagnosticResults.append(result)
                }
            }
        } catch {
            let result = DiagnosticResult(
                category: "API",
                test: "Endpoint Test",
                status: .error,
                message: "Failed to test API endpoint: \(error.localizedDescription)",
                timestamp: Date()
            )
            
            await MainActor.run {
                diagnosticResults.append(result)
            }
        }
    }
    
    private func testSecureConfiguration() async {
        let secureConfig = SecureConfigManager.shared
        let audit = secureConfig.performSecurityAudit()
        
        let result = DiagnosticResult(
            category: "Security",
            test: "Configuration Audit",
            status: audit.isSecure ? .success : .error,
            message: audit.description,
            timestamp: Date()
        )
        
        await MainActor.run {
            diagnosticResults.append(result)
        }
    }
    
    private func testKeychainAccess() async {
        let keychain = Keychain(service: "com.cheffy.app")
        
        do {
            _ = try keychain.get("gemini_api_key")
            let result = DiagnosticResult(
                category: "Security",
                test: "Keychain Access",
                status: .success,
                message: "Keychain access working correctly",
                timestamp: Date()
            )
            
            await MainActor.run {
                diagnosticResults.append(result)
            }
        } catch {
            let result = DiagnosticResult(
                category: "Security",
                test: "Keychain Access",
                status: .error,
                message: "Keychain access failed: \(error.localizedDescription)",
                timestamp: Date()
            )
            
            await MainActor.run {
                diagnosticResults.append(result)
            }
        }
    }
    
    // MARK: - Fix Suggestions
    
    func getFixSuggestions() -> [String] {
        var suggestions: [String] = []
        
        let apiKeyResults = diagnosticResults.filter { $0.category == "API Key" }
        let networkResults = diagnosticResults.filter { $0.category == "Network" }
        let apiResults = diagnosticResults.filter { $0.category == "API" }
        
        // API Key suggestions
        if apiKeyResults.contains(where: { $0.status == .error }) {
            suggestions.append("1. Add your Gemini API key to SecureConfig.plist")
            suggestions.append("2. Set GEMINI_API_KEY environment variable")
            suggestions.append("3. Store API key in keychain using SecureConfigManager")
        }
        
        // Network suggestions
        if networkResults.contains(where: { $0.status == .error }) {
            suggestions.append("4. Check your internet connection")
            suggestions.append("5. Verify firewall settings")
            suggestions.append("6. Try using a different network")
        }
        
        // API suggestions
        if apiResults.contains(where: { $0.status == .error }) {
            suggestions.append("7. Verify API key permissions in Google Cloud Console")
            suggestions.append("8. Check API quota and billing status")
            suggestions.append("9. Ensure Gemini API is enabled in your project")
        }
        
        return suggestions
    }
    
    // MARK: - Cleanup
    
    deinit {
        networkMonitor.cancel()
    }
} 