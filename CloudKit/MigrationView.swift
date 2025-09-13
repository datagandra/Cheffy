import SwiftUI
import CloudKit

// MARK: - Migration View
// Simple UI to trigger and monitor CloudKit migration

struct MigrationView: View {
    @StateObject private var migrationManager = CloudKitMigrationManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("CloudKit Migration")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Upload all recipes to CloudKit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Status Card
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        Text("Migration Status")
                            .font(.headline)
                        Spacer()
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundColor(statusColor)
                    }
                    
                    if migrationManager.migrationStatus == .inProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: migrationManager.progress)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text(migrationManager.currentOperation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("\(migrationManager.processedRecipes) / \(migrationManager.totalRecipes) recipes")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(migrationManager.progress * 100))%")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Statistics
                if migrationManager.totalRecipes > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Migration Statistics")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Recipes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(migrationManager.totalRecipes)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Successful")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(migrationManager.successfulUploads)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Failed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(migrationManager.failedUploads)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Action Button
                Button(action: startMigration) {
                    HStack {
                        Image(systemName: buttonIcon)
                        Text(buttonText)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonColor)
                    .cornerRadius(12)
                }
                .disabled(migrationManager.migrationStatus == .inProgress)
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instructions:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Ensure you're signed into iCloud")
                        Text("2. Make sure you have internet connection")
                        Text("3. The migration will upload all 1,440+ recipes")
                        Text("4. This process may take several minutes")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("CloudKit Migration")
            .alert("Migration Result", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch migrationManager.migrationStatus {
        case .notStarted:
            return "circle"
        case .inProgress:
            return "arrow.clockwise"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch migrationManager.migrationStatus {
        case .notStarted:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch migrationManager.migrationStatus {
        case .notStarted:
            return "Ready to start"
        case .inProgress:
            return "In progress..."
        case .completed:
            return "Completed successfully"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
    
    private var buttonIcon: String {
        switch migrationManager.migrationStatus {
        case .notStarted:
            return "play.fill"
        case .inProgress:
            return "stop.fill"
        case .completed:
            return "arrow.clockwise"
        case .failed:
            return "arrow.clockwise"
        }
    }
    
    private var buttonText: String {
        switch migrationManager.migrationStatus {
        case .notStarted:
            return "Start Migration"
        case .inProgress:
            return "Migration in Progress..."
        case .completed:
            return "Migrate Again"
        case .failed:
            return "Retry Migration"
        }
    }
    
    private var buttonColor: Color {
        switch migrationManager.migrationStatus {
        case .notStarted:
            return .blue
        case .inProgress:
            return .gray
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func startMigration() {
        Task {
            await migrationManager.startMigration()
            
            // Show completion alert
            DispatchQueue.main.async {
                switch migrationManager.migrationStatus {
                case .completed:
                    alertMessage = "Migration completed successfully!\n\nUploaded: \(migrationManager.successfulUploads) recipes\nFailed: \(migrationManager.failedUploads) recipes"
                case .failed(let error):
                    alertMessage = "Migration failed: \(error.localizedDescription)"
                default:
                    break
                }
                showingAlert = true
            }
        }
    }
}

// MARK: - Preview

struct MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationView()
    }
}
