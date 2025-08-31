import Foundation
import UIKit
import CloudKit

// MARK: - Subscription Tier
enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "Free"
    case premium = "Premium"
    case pro = "Pro"
}

struct UserProfile: Identifiable, Codable {
    let id: String
    let userID: String
    let deviceType: String
    var preferredCuisines: [String]
    var dietaryPreferences: [String]
    let appVersion: String
    let createdAt: Date
    var lastUpdatedAt: Date
    var isAnalyticsEnabled: Bool
    
    init(
        id: String = UUID().uuidString,
        userID: String,
        deviceType: String = UIDevice.current.model,
        preferredCuisines: [String] = [],
        dietaryPreferences: [String] = [],
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        isAnalyticsEnabled: Bool = true
    ) {
        self.id = id
        self.userID = userID
        self.deviceType = deviceType
        self.preferredCuisines = preferredCuisines
        self.dietaryPreferences = dietaryPreferences
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.isAnalyticsEnabled = isAnalyticsEnabled
    }
}

// MARK: - CloudKit Integration
extension UserProfile {
    init?(from record: CKRecord) {
        guard let userID = record["userID"] as? String,
              let deviceType = record["deviceType"] as? String,
              let appVersion = record["appVersion"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let lastUpdatedAt = record["lastUpdatedAt"] as? Date,
              let isAnalyticsEnabled = record["isAnalyticsEnabled"] as? Bool else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.userID = userID
        self.deviceType = deviceType
        self.preferredCuisines = record["preferredCuisines"] as? [String] ?? []
        self.dietaryPreferences = record["dietaryPreferences"] as? [String] ?? []
        self.appVersion = appVersion
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.isAnalyticsEnabled = isAnalyticsEnabled
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "UserProfile")
        record["userID"] = userID
        record["deviceType"] = deviceType
        record["preferredCuisines"] = preferredCuisines
        record["dietaryPreferences"] = dietaryPreferences
        record["appVersion"] = appVersion
        record["createdAt"] = createdAt
        record["lastUpdatedAt"] = lastUpdatedAt
        record["isAnalyticsEnabled"] = isAnalyticsEnabled
        return record
    }
}

// MARK: - Convenience Methods
extension UserProfile {
    var hasPreferences: Bool {
        !preferredCuisines.isEmpty || !dietaryPreferences.isEmpty
    }
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var formattedLastUpdatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdatedAt)
    }
    
    func updatePreferences(cuisines: [String]? = nil, dietary: [String]? = nil) -> UserProfile {
        var updated = self
        if let cuisines = cuisines {
            updated = UserProfile(
                id: id,
                userID: userID,
                deviceType: deviceType,
                preferredCuisines: cuisines,
                dietaryPreferences: dietaryPreferences,
                appVersion: appVersion,
                createdAt: createdAt,
                lastUpdatedAt: Date(),
                isAnalyticsEnabled: isAnalyticsEnabled
            )
        }
        if let dietary = dietary {
            updated = UserProfile(
                id: id,
                userID: userID,
                deviceType: deviceType,
                preferredCuisines: updated.preferredCuisines,
                dietaryPreferences: dietary,
                appVersion: appVersion,
                createdAt: createdAt,
                lastUpdatedAt: Date(),
                isAnalyticsEnabled: isAnalyticsEnabled
            )
        }
        return updated
    }
    
    func toggleAnalytics() -> UserProfile {
        return UserProfile(
            id: id,
            userID: userID,
            deviceType: deviceType,
            preferredCuisines: preferredCuisines,
            dietaryPreferences: dietaryPreferences,
            appVersion: appVersion,
            createdAt: createdAt,
            lastUpdatedAt: Date(),
            isAnalyticsEnabled: !isAnalyticsEnabled
        )
    }
}

// MARK: - Dictionary Conversion
extension UserProfile {
    var dictionary: [String: Any] {
        return [
            "id": id,
            "userID": userID,
            "deviceType": deviceType,
            "preferredCuisines": preferredCuisines,
            "dietaryPreferences": dietaryPreferences,
            "appVersion": appVersion,
            "createdAt": ISO8601DateFormatter().string(from: createdAt),
            "lastUpdatedAt": ISO8601DateFormatter().string(from: lastUpdatedAt),
            "isAnalyticsEnabled": isAnalyticsEnabled
        ]
    }
} 