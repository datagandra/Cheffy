import SwiftUI
import CloudKit

struct QuickMigrationView: View {
    @StateObject private var migration = QuickCloudKitMigration()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Quick CloudKit Migration")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Upload all JSON recipes to CloudKit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Status Card
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: migration.isRunning ? "arrow.clockwise" : "checkmark.circle")
                            .foregroundColor(migration.isRunning ? .blue : .green)
                        Text("Migration Status")
                            .font(.headline)
                        Spacer()
                        Text(migration.isRunning ? "Running..." : "Ready")
                            .font(.subheadline)
                            .foregroundColor(migration.isRunning ? .blue : .green)
                    }
                    
                    if migration.isRunning {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: migration.progress)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text(migration.currentStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("\(migration.processedRecipes) / \(migration.totalRecipes) recipes")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(migration.progress * 100))%")
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
                if migration.totalRecipes > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Migration Statistics")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Recipes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(migration.totalRecipes)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Successful")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(migration.successfulUploads)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Failed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(migration.failedUploads)")
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
                Button(action: {
                    Task {
                        await migration.startMigration()
                    }
                }) {
                    HStack {
                        Image(systemName: migration.isRunning ? "stop.fill" : "play.fill")
                        Text(migration.isRunning ? "Migration in Progress..." : "Start Migration")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(migration.isRunning ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(migration.isRunning)
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instructions:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Make sure you're signed into iCloud")
                        Text("2. Ensure you have internet connection")
                        Text("3. The migration will upload all 1,440+ recipes")
                        Text("4. This process may take 5-10 minutes")
                        Text("5. You can monitor progress in real-time")
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
        }
    }
}

#Preview {
    QuickMigrationView()
}
