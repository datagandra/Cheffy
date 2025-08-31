import Foundation
import CloudKit
import Combine
import CryptoKit

protocol CloudKitServiceProtocol: ObservableObject {
    var isCloudKitAvailable: Bool { get }
    var currentUserID: String? { get }
    var syncStatus: CloudKitSyncStatus { get }
    var syncStatusPublisher: Published<CloudKitSyncStatus>.Publisher { get }
    
    // Crash Reports
    func uploadCrashReport(_ crashReport: CrashReport) async throws
    func fetchCrashReports() async throws -> [CrashReport]
    
    // User Recipes
    func uploadUserRecipe(_ recipe: UserRecipe) async throws
    func fetchUserRecipes() async throws -> [UserRecipe]
    func fetchPublicRecipes() async throws -> [UserRecipe]
    func deleteUserRecipe(_ recipe: UserRecipe) async throws
    
    // User Analytics
    func uploadUserProfile(_ profile: UserProfile) async throws
    func fetchUserProfile(userID: String) async throws -> UserProfile?
    func uploadUserStats(_ stats: UserStats) async throws
    func fetchUserProfiles() async throws -> [UserProfile]
    func fetchUserStats(userID: String) async throws -> UserStats?
    func fetchAllUserStats() async throws -> [UserStats]
    func getAggregatedStats() async throws -> [String: Any]
    func deleteUserData(userID: String) async throws
    
    // General
    func checkCloudKitStatus() async
    func requestPermission() async throws
}

enum CloudKitSyncStatus {
    case notAvailable
    case checking
    case available
    case syncing
    case error(String)
}

enum CloudKitError: LocalizedError {
    case notAvailable
    case permissionDenied
    case networkError
    case quotaExceeded
    case recordNotFound
    case invalidRecord
    case serverError(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "CloudKit is not available on this device"
        case .permissionDenied:
            return "Permission to access CloudKit was denied"
        case .networkError:
            return "Network error occurred while syncing"
        case .quotaExceeded:
            return "CloudKit storage quota exceeded"
        case .recordNotFound:
            return "Record not found in CloudKit"
        case .invalidRecord:
            return "Invalid record data"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

@MainActor
@preconcurrency
class CloudKitService: @preconcurrency CloudKitServiceProtocol {
    @Published var isCloudKitAvailable = false
    @Published var currentUserID: String?
    @Published var syncStatus: CloudKitSyncStatus = .notAvailable
    
    var syncStatusPublisher: Published<CloudKitSyncStatus>.Publisher {
        $syncStatus
    }
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let publicDatabase: CKDatabase
    private let logger = Logger.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        
        setupCloudKitStatusMonitoring()
        Task {
            await checkCloudKitStatus()
        }
    }
    
    // MARK: - Setup & Status
    
    private func setupCloudKitStatusMonitoring() {
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkCloudKitStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    func checkCloudKitStatus() async {
        syncStatus = .checking
        
        do {
            let status = try await container.accountStatus()
            
            switch status {
            case .available:
                isCloudKitAvailable = true
                syncStatus = .available
                await fetchCurrentUserID()
            case .noAccount:
                isCloudKitAvailable = false
                syncStatus = .error("No iCloud account found")
            case .restricted:
                isCloudKitAvailable = false
                syncStatus = .error("iCloud access is restricted")
            case .couldNotDetermine:
                isCloudKitAvailable = false
                syncStatus = .error("Could not determine iCloud status")
            case .temporarilyUnavailable:
                isCloudKitAvailable = false
                syncStatus = .error("iCloud temporarily unavailable")
            @unknown default:
                isCloudKitAvailable = false
                syncStatus = .error("Unknown iCloud status")
            }
        } catch {
            isCloudKitAvailable = false
            syncStatus = .error("Failed to check iCloud status: \(error.localizedDescription)")
        }
    }
    
    private func fetchCurrentUserID() async {
        do {
            let userRecord = try await container.userRecordID()
            currentUserID = userRecord.recordName
        } catch {
            logger.error("Failed to fetch user record ID: \(error)")
            currentUserID = nil
        }
    }
    
    func requestPermission() async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                throw CloudKitError.notAvailable
            }
            
            // Request permission by attempting a simple operation
            let userRecord = try await container.userRecordID()
            currentUserID = userRecord.recordName
            syncStatus = .available
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    // MARK: - Crash Reports
    
    func uploadCrashReport(_ crashReport: CrashReport) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        syncStatus = .syncing
        
        do {
            let record = crashReport.toCKRecord()
            let savedRecord = try await privateDatabase.save(record)
            
            logger.info("Successfully uploaded crash report: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            syncStatus = .available
            throw handleCKError(error)
        } catch {
            syncStatus = .available
            throw CloudKitError.unknown(error)
        }
        syncStatus = .available
    }
    
    func fetchCrashReports() async throws -> [CrashReport] {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        let query = CKQuery(recordType: "CrashReport", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let result = try await privateDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            let crashReports = records.compactMap { CrashReport(from: $0) }
            
            logger.info("Successfully fetched \(crashReports.count) crash reports")
            return crashReports
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    // MARK: - User Recipes
    
    func uploadUserRecipe(_ recipe: UserRecipe) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        syncStatus = .syncing
        
        do {
            let record = recipe.toCKRecord()
            let savedRecord = try await publicDatabase.save(record)
            
            logger.info("Successfully uploaded user recipe: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            syncStatus = .available
            throw handleCKError(error)
        } catch {
            syncStatus = .available
            throw CloudKitError.unknown(error)
        }
        syncStatus = .available
    }
    
    func fetchUserRecipes() async throws -> [UserRecipe] {
        guard isCloudKitAvailable, let userID = currentUserID else {
            throw CloudKitError.notAvailable
        }
        
        let predicate = NSPredicate(format: "authorID == %@", userID)
        let query = CKQuery(recordType: "UserRecipe", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let result = try await privateDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            let recipes = records.compactMap { UserRecipe(from: $0) }
            
            logger.info("Successfully fetched \(recipes.count) user recipes")
            return recipes
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    func fetchPublicRecipes() async throws -> [UserRecipe] {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        let predicate = NSPredicate(format: "isPublic == %@", NSNumber(value: true))
        let query = CKQuery(recordType: "UserRecipe", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            let recipes = records.compactMap { UserRecipe(from: $0) }
            
            logger.info("Successfully fetched \(recipes.count) public recipes")
            return recipes
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    func deleteUserRecipe(_ recipe: UserRecipe) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        syncStatus = .syncing
        
        do {
            let recordID = CKRecord.ID(recordName: recipe.id)
            try await publicDatabase.deleteRecord(withID: recordID)
            
            logger.info("Successfully deleted user recipe: \(recipe.id)")
        } catch let error as CKError {
            syncStatus = .available
            throw handleCKError(error)
        } catch {
            syncStatus = .available
            throw CloudKitError.unknown(error)
        }
        syncStatus = .available
    }
    
    // MARK: - User Analytics
    
    func uploadUserProfile(_ profile: UserProfile) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        syncStatus = .syncing
        
        do {
            let record = profile.toCKRecord()
            let savedRecord = try await privateDatabase.save(record)
            
            logger.info("Successfully uploaded user profile: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            syncStatus = .available
            throw handleCKError(error)
        } catch {
            syncStatus = .available
            throw CloudKitError.unknown(error)
        }
        syncStatus = .available
    }
    
    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        do {
            let result = try await privateDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            let profile = records.first.flatMap { UserProfile(from: $0) }
            
            logger.info("Successfully fetched user profile for user: \(userID)")
            return profile
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    func fetchUserProfiles() async throws -> [UserProfile] {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        let predicate = NSPredicate(value: true) // Get all user profiles
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        do {
            let result = try await privateDatabase.records(matching: query)
            let profiles = result.matchResults.compactMap { try? $0.1.get() }
                .compactMap { UserProfile(from: $0) }
            
            logger.info("Successfully fetched \(profiles.count) user profiles")
            return profiles
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    func uploadUserStats(_ stats: UserStats) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        syncStatus = .syncing
        
        do {
            let record = stats.toCKRecord()
            let savedRecord = try await publicDatabase.save(record)
            
            logger.info("Successfully uploaded user stats: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            syncStatus = .available
            throw handleCKError(error)
        } catch {
            syncStatus = .available
            throw CloudKitError.unknown(error)
        }
        syncStatus = .available
    }
    
    func fetchUserStats(userID: String) async throws -> UserStats? {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        let hashedUserID = hashUserID(userID)
        let predicate = NSPredicate(format: "hashedUserID == %@", hashedUserID)
        let query = CKQuery(recordType: "UserStats", predicate: predicate)
        
        do {
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            let stats = records.first.flatMap { UserStats(from: $0) }
            
            logger.info("Successfully fetched user stats for user: \(userID)")
            return stats
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    func fetchAllUserStats() async throws -> [UserStats] {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        do {
            let query = CKQuery(recordType: "UserStats", predicate: NSPredicate(value: true))
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            let stats = records.compactMap { UserStats(from: $0) }
            
            logger.info("Successfully fetched all user stats: \(stats.count) records")
            return stats
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    func getAggregatedStats() async throws -> [String: Any] {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        do {
            let query = CKQuery(recordType: "UserStats", predicate: NSPredicate(value: true))
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            let stats = records.compactMap { UserStats(from: $0) }
            
            // Calculate aggregated statistics
            let totalUsers = stats.count
            let totalRecipesViewed = stats.reduce(0) { $0 + $1.recipesViewed }
            let totalRecipesSaved = stats.reduce(0) { $0 + $1.recipesSaved }
            let totalSearches = stats.reduce(0) { $0 + $1.searchesPerformed }
            let totalTimeSpent = stats.reduce(0.0) { $0 + $1.timeSpent }
            
            // Feature usage aggregation
            var featureUsage: [String: Int] = [:]
            for stat in stats {
                for (feature, count) in stat.featureUsage {
                    featureUsage[feature, default: 0] += count
                }
            }
            
            // Device type distribution
            let deviceTypes = Dictionary(grouping: stats, by: { $0.deviceType })
                .mapValues { $0.count }
            
            // App version distribution
            let appVersions = Dictionary(grouping: stats, by: { $0.appVersion })
                .mapValues { $0.count }
            
            let aggregatedStats: [String: Any] = [
                "totalUsers": totalUsers,
                "totalRecipesViewed": totalRecipesViewed,
                "totalRecipesSaved": totalRecipesSaved,
                "totalSearches": totalSearches,
                "totalTimeSpent": totalTimeSpent,
                "averageTimeSpent": totalUsers > 0 ? totalTimeSpent / Double(totalUsers) : 0,
                "featureUsage": featureUsage,
                "deviceTypes": deviceTypes,
                "appVersions": appVersions,
                "lastUpdated": ISO8601DateFormatter().string(from: Date())
            ]
            
            logger.info("Successfully generated aggregated stats")
            return aggregatedStats
        } catch let error as CKError {
            throw handleCKError(error)
        } catch {
            throw CloudKitError.unknown(error)
        }
    }
    
    func deleteUserData(userID: String) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        syncStatus = .syncing
        
        do {
            // Delete user profile
            if let profile = try await fetchUserProfile(userID: userID) {
                let profileRecordID = CKRecord.ID(recordName: profile.id)
                try await privateDatabase.deleteRecord(withID: profileRecordID)
                logger.info("Deleted user profile for user: \(userID)")
            }
            
            // Delete user stats
            if let stats = try await fetchUserStats(userID: userID) {
                let statsRecordID = CKRecord.ID(recordName: stats.id)
                try await publicDatabase.deleteRecord(withID: statsRecordID)
                logger.info("Deleted user stats for user: \(userID)")
            }
            
            logger.info("Successfully deleted all user data for user: \(userID)")
        } catch let error as CKError {
            syncStatus = .available
            throw handleCKError(error)
        } catch {
            syncStatus = .available
            throw CloudKitError.unknown(error)
        }
        syncStatus = .available
    }
    
    // MARK: - Helper Methods
    
    private func hashUserID(_ userID: String) -> String {
        let hash = SHA256.hash(data: userID.data(using: .utf8) ?? Data())
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Error Handling
    
    private func handleCKError(_ error: CKError) -> CloudKitError {
        switch error.code {
        case .notAuthenticated:
            return .permissionDenied
        case .networkUnavailable, .networkFailure:
            return .networkError
        case .quotaExceeded:
            return .quotaExceeded
        case .unknownItem:
            return .recordNotFound
        case .invalidArguments:
            return .invalidRecord
        case .serverResponseLost, .serverRecordChanged, .serverRejectedRequest:
            return .serverError(error.localizedDescription)
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Mock Implementation for Testing
class MockCloudKitService: CloudKitServiceProtocol {
    @Published var isCloudKitAvailable = true
    @Published var currentUserID: String? = "mock-user-id"
    @Published var syncStatus: CloudKitSyncStatus = .available
    
    var syncStatusPublisher: Published<CloudKitSyncStatus>.Publisher {
        $syncStatus
    }
    
    private var crashReports: [CrashReport] = []
    private var userRecipes: [UserRecipe] = []
    private var userProfiles: [String: UserProfile] = [:]
    private var userStats: [String: UserStats] = [:]
    
    func uploadCrashReport(_ crashReport: CrashReport) async throws {
        crashReports.append(crashReport)
    }
    
    func fetchCrashReports() async throws -> [CrashReport] {
        return crashReports
    }
    
    func uploadUserRecipe(_ recipe: UserRecipe) async throws {
        userRecipes.append(recipe)
    }
    
    func fetchUserRecipes() async throws -> [UserRecipe] {
        return userRecipes
    }
    
    func fetchPublicRecipes() async throws -> [UserRecipe] {
        return userRecipes.filter { $0.isPublic }
    }
    
    func deleteUserRecipe(_ recipe: UserRecipe) async throws {
        userRecipes.removeAll { $0.id == recipe.id }
    }
    
    func checkCloudKitStatus() async {
        // Mock implementation
    }
    
    func requestPermission() async throws {
        // Mock implementation
    }
    
    func uploadUserProfile(_ profile: UserProfile) async throws {
        userProfiles[profile.userID] = profile
    }
    
    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        return userProfiles[userID]
    }
    
    func fetchUserProfiles() async throws -> [UserProfile] {
        return Array(userProfiles.values)
    }
    
    func uploadUserStats(_ stats: UserStats) async throws {
        userStats[stats.hashedUserID] = stats
    }
    
    func fetchUserStats(userID: String) async throws -> UserStats? {
        return userStats[userID]
    }
    
    func fetchAllUserStats() async throws -> [UserStats] {
        return Array(userStats.values)
    }
    
    func getAggregatedStats() async throws -> [String: Any] {
        return [
            "totalUsers": userProfiles.count,
            "totalStats": userStats.count,
            "totalRecipes": userRecipes.count,
            "totalCrashReports": crashReports.count
        ]
    }
    
    func deleteUserData(userID: String) async throws {
        userProfiles.removeValue(forKey: userID)
        userStats.removeValue(forKey: userID)
    }
}
