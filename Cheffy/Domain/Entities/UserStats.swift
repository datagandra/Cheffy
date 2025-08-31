import Foundation
import UIKit
import CloudKit

struct UserStats: Identifiable, Codable {
    let id: String
    let hashedUserID: String
    let recipesViewed: Int
    let recipesSaved: Int
    let timeSpent: TimeInterval
    let searchesPerformed: Int
    let featureUsage: [String: Int]
    let lastActiveAt: Date
    let sessionCount: Int
    let appVersion: String
    let deviceType: String
    
    init(
        id: String = UUID().uuidString,
        hashedUserID: String,
        recipesViewed: Int = 0,
        recipesSaved: Int = 0,
        timeSpent: TimeInterval = 0,
        searchesPerformed: Int = 0,
        featureUsage: [String: Int] = [:],
        lastActiveAt: Date = Date(),
        sessionCount: Int = 1,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        deviceType: String = UIDevice.current.model
    ) {
        self.id = id
        self.hashedUserID = hashedUserID
        self.recipesViewed = recipesViewed
        self.recipesSaved = recipesSaved
        self.timeSpent = timeSpent
        self.searchesPerformed = searchesPerformed
        self.featureUsage = featureUsage
        self.lastActiveAt = lastActiveAt
        self.sessionCount = sessionCount
        self.appVersion = appVersion
        self.deviceType = deviceType
    }
}

// MARK: - Feature Usage Tracking
extension UserStats {
    enum Feature: String, CaseIterable {
        case recipeView = "recipe_view"
        case recipeSave = "recipe_save"
        case search = "search"
        case imageGeneration = "image_generation"
        case recipeUpload = "recipe_upload"
        case favorites = "favorites"
        case cookingMode = "cooking_mode"
        case filterUsage = "filter_usage"
        case crashReporting = "crash_reporting"
        
        var displayName: String {
            switch self {
            case .recipeView: return "Recipe Views"
            case .recipeSave: return "Recipe Saves"
            case .search: return "Searches"
            case .imageGeneration: return "Image Generation"
            case .recipeUpload: return "Recipe Uploads"
            case .favorites: return "Favorites"
            case .cookingMode: return "Cooking Mode"
            case .filterUsage: return "Filter Usage"
            case .crashReporting: return "Crash Reporting"
            }
        }
        
        var icon: String {
            switch self {
            case .recipeView: return "eye"
            case .recipeSave: return "bookmark"
            case .search: return "magnifyingglass"
            case .imageGeneration: return "photo"
            case .recipeUpload: return "plus.circle"
            case .favorites: return "heart"
            case .cookingMode: return "play.circle"
            case .filterUsage: return "line.3.horizontal.decrease.circle"
            case .crashReporting: return "exclamationmark.triangle"
            }
        }
    }
    
    func incrementFeature(_ feature: Feature, by amount: Int = 1) -> UserStats {
        let currentCount = featureUsage[feature.rawValue] ?? 0
        var updatedUsage = featureUsage
        updatedUsage[feature.rawValue] = currentCount + amount
        
        return UserStats(
            id: id,
            hashedUserID: hashedUserID,
            recipesViewed: recipesViewed,
            recipesSaved: recipesSaved,
            timeSpent: timeSpent,
            searchesPerformed: searchesPerformed,
            featureUsage: updatedUsage,
            lastActiveAt: Date(),
            sessionCount: sessionCount,
            appVersion: appVersion,
            deviceType: deviceType
        )
    }
    
    func incrementRecipesViewed(by amount: Int = 1) -> UserStats {
        return UserStats(
            id: id,
            hashedUserID: hashedUserID,
            recipesViewed: recipesViewed + amount,
            recipesSaved: recipesSaved,
            timeSpent: timeSpent,
            searchesPerformed: searchesPerformed,
            featureUsage: featureUsage,
            lastActiveAt: Date(),
            sessionCount: sessionCount,
            appVersion: appVersion,
            deviceType: deviceType
        )
    }
    
    func incrementRecipesSaved(by amount: Int = 1) -> UserStats {
        return UserStats(
            id: id,
            hashedUserID: hashedUserID,
            recipesViewed: recipesViewed,
            recipesSaved: recipesSaved + amount,
            timeSpent: timeSpent,
            searchesPerformed: searchesPerformed,
            featureUsage: featureUsage,
            lastActiveAt: Date(),
            sessionCount: sessionCount,
            appVersion: appVersion,
            deviceType: deviceType
        )
    }
    
    func incrementSearches(by amount: Int = 1) -> UserStats {
        return UserStats(
            id: id,
            hashedUserID: hashedUserID,
            recipesViewed: recipesViewed,
            recipesSaved: recipesSaved,
            timeSpent: timeSpent,
            searchesPerformed: searchesPerformed + amount,
            featureUsage: featureUsage,
            lastActiveAt: Date(),
            sessionCount: sessionCount,
            appVersion: appVersion,
            deviceType: deviceType
        )
    }
    
    func addTimeSpent(_ time: TimeInterval) -> UserStats {
        return UserStats(
            id: id,
            hashedUserID: hashedUserID,
            recipesViewed: recipesViewed,
            recipesSaved: recipesSaved,
            timeSpent: timeSpent + time,
            searchesPerformed: searchesPerformed,
            featureUsage: featureUsage,
            lastActiveAt: Date(),
            sessionCount: sessionCount,
            appVersion: appVersion,
            deviceType: deviceType
        )
    }
    
    func incrementSession() -> UserStats {
        return UserStats(
            id: id,
            hashedUserID: hashedUserID,
            recipesViewed: recipesViewed,
            recipesSaved: recipesSaved,
            timeSpent: timeSpent,
            searchesPerformed: searchesPerformed,
            featureUsage: featureUsage,
            lastActiveAt: Date(),
            sessionCount: sessionCount + 1,
            appVersion: appVersion,
            deviceType: deviceType
        )
    }
}

// MARK: - CloudKit Integration
extension UserStats {
    init?(from record: CKRecord) {
        guard let hashedUserID = record["hashedUserID"] as? String,
              let lastActiveAt = record["lastActiveAt"] as? Date,
              let appVersion = record["appVersion"] as? String,
              let deviceType = record["deviceType"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.hashedUserID = hashedUserID
        self.recipesViewed = record["recipesViewed"] as? Int ?? 0
        self.recipesSaved = record["recipesSaved"] as? Int ?? 0
        self.timeSpent = record["timeSpent"] as? TimeInterval ?? 0
        self.searchesPerformed = record["searchesPerformed"] as? Int ?? 0
        // Convert featureUsage from JSON string back to dictionary
        if let featureUsageData = record["featureUsage"] as? Data,
           let featureUsageDict = try? JSONSerialization.jsonObject(with: featureUsageData) as? [String: Int] {
            self.featureUsage = featureUsageDict
        } else {
            self.featureUsage = [:]
        }
        self.lastActiveAt = lastActiveAt
        self.sessionCount = record["sessionCount"] as? Int ?? 1
        self.appVersion = appVersion
        self.deviceType = deviceType
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "UserStats")
        record["hashedUserID"] = hashedUserID
        record["recipesViewed"] = recipesViewed
        record["recipesSaved"] = recipesSaved
        record["timeSpent"] = timeSpent
        record["searchesPerformed"] = searchesPerformed
        // Convert featureUsage dictionary to Data for CloudKit storage
        if let featureUsageData = try? JSONSerialization.data(withJSONObject: featureUsage) {
            record["featureUsage"] = featureUsageData
        } else {
            record["featureUsage"] = Data()
        }
        record["lastActiveAt"] = lastActiveAt
        record["sessionCount"] = sessionCount
        record["appVersion"] = appVersion
        record["deviceType"] = deviceType
        return record
    }
}

// MARK: - Convenience Methods
extension UserStats {
    var formattedTimeSpent: String {
        let hours = Int(timeSpent) / 3600
        let minutes = Int(timeSpent) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var formattedLastActive: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActiveAt, relativeTo: Date())
    }
    
    var totalFeatureUsage: Int {
        featureUsage.values.reduce(0, +)
    }
    
    var mostUsedFeature: (Feature, Int)? {
        guard let maxEntry = featureUsage.max(by: { $0.value < $1.value }) else {
            return nil
        }
        
        guard let feature = Feature(rawValue: maxEntry.key) else {
            return nil
        }
        
        return (feature, maxEntry.value)
    }
    
    var engagementScore: Double {
        let baseScore = Double(recipesViewed + recipesSaved + searchesPerformed)
        let timeBonus = timeSpent / 3600 // 1 point per hour
        let featureBonus = Double(totalFeatureUsage) * 0.5
        return baseScore + timeBonus + featureBonus
    }
}

// MARK: - Dictionary Conversion
extension UserStats {
    var dictionary: [String: Any] {
        return [
            "id": id,
            "hashedUserID": hashedUserID,
            "recipesViewed": recipesViewed,
            "recipesSaved": recipesSaved,
            "timeSpent": timeSpent,
            "searchesPerformed": searchesPerformed,
            "featureUsage": featureUsage,
            "lastActiveAt": ISO8601DateFormatter().string(from: lastActiveAt),
            "sessionCount": sessionCount,
            "appVersion": appVersion,
            "deviceType": deviceType
        ]
    }
}
