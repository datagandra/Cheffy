import Foundation
import CloudKit
import SwiftUI

// MARK: - CloudKit Setup Helper
// Simple setup and testing for CloudKit integration

class CloudKitSetup {
    static let shared = CloudKitSetup()
    
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.cheffy.app")
        self.database = container.privateCloudDatabase
    }
    
    // MARK: - Setup Methods
    
    /// Check if CloudKit is available and user is signed in
    func checkCloudKitAvailability() async -> Bool {
        do {
            let accountStatus = try await container.accountStatus()
            return accountStatus == .available
        } catch {
            print("❌ CloudKit not available: \(error)")
            return false
        }
    }
    
    /// Test CloudKit connection by creating a simple record
    func testCloudKitConnection() async -> Bool {
        do {
            // Create a test record
            let testRecord = CKRecord(recordType: "TestRecord")
            testRecord["testField"] = "Hello CloudKit!"
            
            // Try to save it
            _ = try await database.save(testRecord)
            
            // Delete the test record
            try await database.deleteRecord(withID: testRecord.recordID)
            
            print("✅ CloudKit connection test successful")
            return true
        } catch {
            print("❌ CloudKit connection test failed: \(error)")
            return false
        }
    }
    
    /// Get CloudKit container information
    func getContainerInfo() async -> String {
        let containerIdentifier = container.containerIdentifier
        let accountStatus = try? await container.accountStatus()
        
        return """
        Container ID: \(containerIdentifier)
        Account Status: \(accountStatus?.description ?? "Unknown")
        Database: \(database.databaseScope.description)
        """
    }
}

// MARK: - CloudKit Account Status Extension

extension CKAccountStatus {
    var description: String {
        switch self {
        case .available:
            return "Available"
        case .noAccount:
            return "No Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Could Not Determine"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - CloudKit Database Scope Extension

extension CKDatabase.Scope {
    var description: String {
        switch self {
        case .public:
            return "Public"
        case .private:
            return "Private"
        case .shared:
            return "Shared"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Quick Setup View

struct CloudKitSetupView: View {
    @State private var isCloudKitAvailable = false
    @State private var connectionTestPassed = false
    @State private var containerInfo = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "icloud")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("CloudKit Setup")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)
                
                // Status Cards
                VStack(spacing: 15) {
                    // CloudKit Availability
                    HStack {
                        Image(systemName: isCloudKitAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isCloudKitAvailable ? .green : .red)
                        Text("CloudKit Available")
                            .font(.headline)
                        Spacer()
                        Text(isCloudKitAvailable ? "Yes" : "No")
                            .font(.subheadline)
                            .foregroundColor(isCloudKitAvailable ? .green : .red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Connection Test
                    HStack {
                        Image(systemName: connectionTestPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(connectionTestPassed ? .green : .red)
                        Text("Connection Test")
                            .font(.headline)
                        Spacer()
                        Text(connectionTestPassed ? "Passed" : "Failed")
                            .font(.subheadline)
                            .foregroundColor(connectionTestPassed ? .green : .red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Container Info
                if !containerInfo.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Container Information")
                            .font(.headline)
                        
                        Text(containerInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Test Button
                Button(action: runTests) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Test CloudKit Setup")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoading ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                // Migration Button
                if isCloudKitAvailable && connectionTestPassed {
                    NavigationLink(destination: MigrationView()) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Start Recipe Migration")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("CloudKit Setup")
            .onAppear {
                runTests()
            }
        }
    }
    
    private func runTests() {
        isLoading = true
        
        Task {
            // Test CloudKit availability
            isCloudKitAvailable = await CloudKitSetup.shared.checkCloudKitAvailability()
            
            // Test connection if available
            if isCloudKitAvailable {
                connectionTestPassed = await CloudKitSetup.shared.testCloudKitConnection()
            }
            
            // Get container info
            containerInfo = await CloudKitSetup.shared.getContainerInfo()
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

struct CloudKitSetupView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitSetupView()
    }
}
