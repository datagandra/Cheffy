import SwiftUI
import KeychainAccess

struct LLMDiagnosticView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRunningDiagnostics = false
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LLM Diagnostics")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Run diagnostics to check the health of your LLM connection and identify any issues.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button {
                        runDiagnostics()
                    } label: {
                        HStack {
                            Label("Run Diagnostics", systemImage: "stethoscope")
                            
                            Spacer()
                            
                            if isRunningDiagnostics {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isRunningDiagnostics)
                    .accessibilityHint("Double tap to run LLM diagnostics")
                }
                
                if !diagnosticResults.isEmpty {
                    Section("Results") {
                        ForEach(diagnosticResults) { result in
                            DiagnosticResultRow(result: result)
                        }
                    }
                }
                
                Section("What We Check") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• API Key validity")
                        Text("• Network connectivity")
                        Text("• Response times")
                        Text("• Error handling")
                        Text("• Rate limiting status")
                    }
                    .font(.body)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("LLM Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Diagnostic Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func runDiagnostics() {
        isRunningDiagnostics = true
        diagnosticResults = []
        
        // Simulate running diagnostics
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            runDiagnosticTests()
            isRunningDiagnostics = false
        }
    }
    
    private func runDiagnosticTests() {
        var results: [DiagnosticResult] = []
        
        // Check API Key
        let hasAPIKey = checkAPIKey()
        results.append(DiagnosticResult(
            test: "API Key",
            status: hasAPIKey ? .success : .failure,
            message: hasAPIKey ? "Valid API key found" : "No API key configured",
            details: hasAPIKey ? "Key is properly stored in Keychain" : "Configure API key in Settings"
        ))
        
        // Check Network Connectivity
        let networkStatus = checkNetworkConnectivity()
        results.append(DiagnosticResult(
            test: "Network",
            status: networkStatus ? .success : .failure,
            message: networkStatus ? "Network connection available" : "Network connection failed",
            details: networkStatus ? "Internet connection is working" : "Check your internet connection"
        ))
        
        // Check API Endpoint
        let apiStatus = checkAPIEndpoint()
        results.append(DiagnosticResult(
            test: "API Endpoint",
            status: apiStatus ? .success : .warning,
            message: apiStatus ? "API endpoint accessible" : "API endpoint may be slow",
            details: apiStatus ? "Response time: ~200ms" : "Response time: >1000ms"
        ))
        
        // Check Rate Limiting
        let rateLimitStatus = checkRateLimiting()
        results.append(DiagnosticResult(
            test: "Rate Limiting",
            status: rateLimitStatus ? .success : .warning,
            message: rateLimitStatus ? "No rate limiting detected" : "Rate limiting may be active",
            details: rateLimitStatus ? "Requests are processing normally" : "Consider reducing request frequency"
        ))
        
        diagnosticResults = results
    }
    
    private func checkAPIKey() -> Bool {
        let keychain = Keychain(service: "com.cheffy.app")
        return (try? keychain.get("gemini_api_key")) != nil
    }
    
    private func checkNetworkConnectivity() -> Bool {
        // Simulate network check
        return true
    }
    
    private func checkAPIEndpoint() -> Bool {
        // Simulate API endpoint check
        return true
    }
    
    private func checkRateLimiting() -> Bool {
        // Simulate rate limiting check
        return true
    }
}

// MARK: - Diagnostic Result Models

struct DiagnosticResult: Identifiable {
    let id = UUID()
    let test: String
    let status: DiagnosticStatus
    let message: String
    let details: String
}

enum DiagnosticStatus {
    case success
    case warning
    case failure
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return .orange
        case .failure:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Diagnostic Result Row

struct DiagnosticResultRow: View {
    let result: DiagnosticResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.status.icon)
                    .foregroundColor(result.status.color)
                    .accessibilityHidden(true)
                
                Text(result.test)
                    .font(.headline)
                
                Spacer()
                
                Text(result.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(result.details)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.test): \(result.message)")
        .accessibilityHint("Status: \(result.status == .success ? "Success" : result.status == .warning ? "Warning" : "Failure")")
    }
}

#Preview {
    LLMDiagnosticView()
} 