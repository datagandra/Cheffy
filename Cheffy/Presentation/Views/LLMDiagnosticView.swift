import SwiftUI
import os.log

struct LLMDiagnosticView: View {
    @StateObject private var diagnosticService = LLMDiagnosticService.shared
    @State private var showingAPIKeyInput = false
    @State private var apiKeyInput = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Header Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                            Text("LLM Connection Diagnostics")
                                .font(.headline)
                        }
                        
                        Text("This tool helps diagnose and fix LLM connection issues")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // API Key Section
                Section("API Key Configuration") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Gemini API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if SecureConfigManager.shared.hasValidAPIKey {
                                Text("✅ Configured")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("❌ Not configured")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Configure") {
                            showingAPIKeyInput = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Diagnostic Results
                if !diagnosticService.diagnosticResults.isEmpty {
                    Section("Diagnostic Results") {
                        ForEach(diagnosticService.diagnosticResults, id: \.timestamp) { result in
                            DiagnosticResultRow(result: result)
                        }
                    }
                }
                
                // Fix Suggestions
                if !diagnosticService.getFixSuggestions().isEmpty {
                    Section("Recommended Fixes") {
                        ForEach(diagnosticService.getFixSuggestions(), id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Actions Section
                Section {
                    Button(action: {
                        Task {
                            await diagnosticService.runFullDiagnostics()
                        }
                    }) {
                        HStack {
                            if diagnosticService.isRunningDiagnostics {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "stethoscope")
                            }
                            Text(diagnosticService.isRunningDiagnostics ? "Running Diagnostics..." : "Run Full Diagnostics")
                        }
                    }
                    .disabled(diagnosticService.isRunningDiagnostics)
                    
                    Button("Test API Connection") {
                        Task {
                            await testAPIConnection()
                        }
                    }
                    .disabled(diagnosticService.isRunningDiagnostics)
                    
                    Button("Clear Diagnostic Results") {
                        diagnosticService.diagnosticResults.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("LLM Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAPIKeyInput) {
                APIKeyInputView(apiKey: $apiKeyInput, isPresented: $showingAPIKeyInput)
            }
            .alert("API Key", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func testAPIConnection() async {
        let client = OpenAIClient()
        
        do {
            let success = await client.testAPIKey()
            await MainActor.run {
                if success {
                    alertMessage = "✅ API connection test successful!"
                } else {
                    alertMessage = "❌ API connection test failed. Check your API key and network connection."
                }
                showingAlert = true
            }
        } catch {
            await MainActor.run {
                alertMessage = "❌ API test error: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

struct DiagnosticResultRow: View {
    let result: LLMDiagnosticService.DiagnosticResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusIcon
                VStack(alignment: .leading) {
                    Text(result.test)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(result.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(result.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(result.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
        .padding(.vertical, 2)
    }
    
    private var statusIcon: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .frame(width: 20)
    }
    
    private var iconName: String {
        switch result.status {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch result.status {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

struct APIKeyInputView: View {
    @Binding var apiKey: String
    @Binding var isPresented: Bool
    @State private var tempAPIKey = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gemini API Key")
                        .font(.headline)
                    
                    Text("Enter your Gemini API key to enable LLM functionality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                SecureField("AIza...", text: $tempAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to get your API key:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Go to Google AI Studio")
                        Text("2. Create a new API key")
                        Text("3. Copy the key (starts with 'AIza')")
                        Text("4. Paste it here")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("API Key Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(tempAPIKey.isEmpty)
                }
            }
        }
    }
    
    private func saveAPIKey() {
        let secureConfig = SecureConfigManager.shared
        
        if secureConfig.validateAPIKey(tempAPIKey) {
            secureConfig.storeAPIKey(tempAPIKey)
            apiKey = tempAPIKey
            isPresented = false
        } else {
            // Show error
        }
    }
}

#Preview {
    LLMDiagnosticView()
} 