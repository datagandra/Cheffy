import Foundation
import CloudKit
import Combine

@MainActor
class DeveloperAnalyticsViewModel: ObservableObject {
    @Published var totalUsers: Int = 0
    @Published var analyticsEnabledUsers: Int = 0
    @Published var dataCollectionRate: Double = 0.0
    @Published var privateDBStatus: Bool = false
    @Published var publicDBStatus: Bool = false
    @Published var lastSyncTime: String?
    @Published var topCuisines: [CuisineData] = []
    @Published var featureUsage: [FeatureData] = []
    @Published var userProfiles: [UserProfile] = []
    @Published var userStats: [UserStats] = []
    @Published var crashReports: [CrashReport] = []
    
    private let cloudKitService: any CloudKitServiceProtocol
    private let userAnalyticsService: any UserAnalyticsServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        cloudKitService: any CloudKitServiceProtocol = CloudKitService(),
        userAnalyticsService: any UserAnalyticsServiceProtocol = UserAnalyticsService(cloudKitService: CloudKitService())
    ) {
        self.cloudKitService = cloudKitService
        self.userAnalyticsService = userAnalyticsService
    }
    
    // MARK: - Data Refresh
    
    func refreshData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadUserProfiles() }
            group.addTask { await self.loadUserStats() }
            group.addTask { await self.loadCrashReports() }
            group.addTask { await self.loadAnalyticsOverview() }
            group.addTask { await self.loadCloudKitStatus() }
            group.addTask { await self.loadDataInsights() }
        }
    }
    
    // MARK: - User Profiles
    
    func loadUserProfiles() async {
        do {
            let profiles = try await cloudKitService.fetchUserProfiles()
            userProfiles = profiles
            totalUsers = profiles.count
            analyticsEnabledUsers = profiles.filter { $0.isAnalyticsEnabled }.count
            dataCollectionRate = totalUsers > 0 ? Double(analyticsEnabledUsers) / Double(totalUsers) * 100.0 : 0.0
        } catch {
            print("Error loading user profiles: \(error)")
        }
    }
    
    // MARK: - User Stats
    
    func loadUserStats() async {
        do {
            let stats = try await cloudKitService.fetchAllUserStats()
            userStats = stats
        } catch {
            print("Error loading user stats: \(error)")
        }
    }
    
    // MARK: - Crash Reports
    
    func loadCrashReports() async {
        do {
            let reports = try await cloudKitService.fetchCrashReports()
            crashReports = reports
        } catch {
            print("Error loading crash reports: \(error)")
        }
    }
    
    // MARK: - Analytics Overview
    
    func loadAnalyticsOverview() async {
        // This would typically aggregate data from CloudKit
        // For now, we'll use the data loaded from user profiles
        // In a real implementation, you might want to query aggregated stats
    }
    
    // MARK: - CloudKit Status
    
    func loadCloudKitStatus() async {
        do {
            // Check private database access
            let _ = try await cloudKitService.fetchUserProfiles()
            privateDBStatus = true
        } catch {
            privateDBStatus = false
        }
        
        do {
            // Check public database access
            let _ = try await cloudKitService.fetchAllUserStats()
            publicDBStatus = true
        } catch {
            publicDBStatus = false
        }
        
        // Set last sync time
        lastSyncTime = Date().formatted(date: .abbreviated, time: .shortened)
    }
    
    // MARK: - Data Insights
    
    func loadDataInsights() async {
        // Analyze user profiles for cuisine preferences
        var cuisineCounts: [String: Int] = [:]
        for profile in userProfiles {
            for cuisine in profile.preferredCuisines {
                cuisineCounts[cuisine, default: 0] += 1
            }
        }
        
        topCuisines = cuisineCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { CuisineData(key: $0.key, value: $0.value) }
        
        // Analyze user stats for feature usage
        var featureCounts: [String: Int] = [:]
        for stats in userStats {
            for (feature, count) in stats.featureUsage {
                featureCounts[feature, default: 0] += count
            }
        }
        
        featureUsage = featureCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { FeatureData(key: $0.key, value: $0.value) }
    }
    
    // MARK: - Data Export
    
    func exportAnalyticsData() {
        let exportData = AnalyticsExportData(
            exportDate: Date(),
            totalUsers: totalUsers,
            analyticsEnabledUsers: analyticsEnabledUsers,
            dataCollectionRate: dataCollectionRate,
            topCuisines: topCuisines,
            featureUsage: featureUsage,
            userProfiles: userProfiles,
            userStats: userStats,
            crashReports: crashReports
        )
        
        // Convert to JSON for export
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(exportData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            // In a real app, you might want to share this data or save it to files
            print("Analytics Export Data:")
            print(jsonString)
            
            // You could also implement sharing via UIActivityViewController
            // or save to Documents directory for later access
        } catch {
            print("Error exporting analytics data: \(error)")
        }
    }
}

// MARK: - Export Data Structure

struct AnalyticsExportData: Codable {
    let exportDate: Date
    let totalUsers: Int
    let analyticsEnabledUsers: Int
    let dataCollectionRate: Double
    let topCuisines: [CuisineData]
    let featureUsage: [FeatureData]
    let userProfiles: [UserProfile]
    let userStats: [UserStats]
    let crashReports: [CrashReport]
}

struct CuisineData: Codable {
    let key: String
    let value: Int
}

struct FeatureData: Codable {
    let key: String
    let value: Int
}

// MARK: - Extensions for Display

extension CrashReport {
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
