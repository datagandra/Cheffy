import Foundation
import CloudKit
import UIKit

struct UserRecipe: Identifiable, Codable {
    let id: String
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let createdAt: Date
    let authorID: String
    let imageData: Data?
    let cuisine: String?
    let difficulty: String?
    let prepTime: Int?
    let cookTime: Int?
    let servings: Int?
    let dietaryNotes: [String]?
    let isPublic: Bool
    let syncStatus: SyncStatus
    
    init(
        id: String = UUID().uuidString,
        title: String,
        ingredients: [String],
        instructions: [String],
        createdAt: Date = Date(),
        authorID: String,
        imageData: Data? = nil,
        cuisine: String? = nil,
        difficulty: String? = nil,
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        servings: Int? = nil,
        dietaryNotes: [String]? = nil,
        isPublic: Bool = true,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.createdAt = createdAt
        self.authorID = authorID
        self.imageData = imageData
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.dietaryNotes = dietaryNotes
        self.isPublic = isPublic
        self.syncStatus = syncStatus
    }
}

enum SyncStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case uploading = "Uploading"
    case synced = "Synced"
    case failed = "Failed"
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .uploading: return "arrow.up.circle"
        case .synced: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .uploading: return "blue"
        case .synced: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - CloudKit Integration
extension UserRecipe {
    init?(from record: CKRecord) {
        guard let title = record["title"] as? String,
              let ingredients = record["ingredients"] as? [String],
              let instructions = record["instructions"] as? [String],
              let createdAt = record["createdAt"] as? Date,
              let authorID = record["authorID"] as? String else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.createdAt = createdAt
        self.authorID = authorID
        self.imageData = record["imageData"] as? Data
        self.cuisine = record["cuisine"] as? String
        self.difficulty = record["difficulty"] as? String
        self.prepTime = record["prepTime"] as? Int
        self.cookTime = record["cookTime"] as? Int
        self.servings = record["servings"] as? Int
        self.dietaryNotes = record["dietaryNotes"] as? [String]
        self.isPublic = record["isPublic"] as? Bool ?? true
        self.syncStatus = .synced
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "UserRecipe")
        record["title"] = title
        record["ingredients"] = ingredients
        record["instructions"] = instructions
        record["createdAt"] = createdAt
        record["authorID"] = authorID
        record["imageData"] = imageData
        record["cuisine"] = cuisine
        record["difficulty"] = difficulty
        record["prepTime"] = prepTime
        record["cookTime"] = cookTime
        record["servings"] = servings
        record["dietaryNotes"] = dietaryNotes
        record["isPublic"] = isPublic
        return record
    }
}

// MARK: - Convenience Methods
extension UserRecipe {
    var totalTime: Int {
        (prepTime ?? 0) + (cookTime ?? 0)
    }
    
    var displayImage: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var ingredientsText: String {
        ingredients.joined(separator: "\n")
    }
    
    var instructionsText: String {
        instructions.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n\n")
    }
}
