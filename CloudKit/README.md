# CloudKit Recipe Migration

This directory contains the complete CloudKit migration solution for Cheffy's recipe data, designed to scale from static JSON files to a global, cloud-based recipe database.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   JSON Files    │───▶│  Migration Tool  │───▶│   CloudKit      │
│  (Local Data)   │    │   (Node.js)      │    │  (Global Data)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Swift Service   │
                       │ (CloudKit API)   │
                       └──────────────────┘
```

## 📁 File Structure

```
CloudKit/
├── RecipeSchema.swift           # CloudKit data model & schema
├── CloudKitRecipeService.swift  # CloudKit API service
├── RecipeDataManager.swift      # Unified data manager
├── migrate-recipes.js           # Node.js migration script
├── validate-schema.js           # Schema validation tool
├── package.json                 # Node.js dependencies
└── README.md                    # This file
```

## 🚀 Quick Start

### 1. Prerequisites

- Node.js 16+ installed
- Xcode with CloudKit framework
- Apple Developer account with CloudKit enabled
- iCloud container configured

### 2. Install Dependencies

```bash
cd CloudKit
npm install
```

### 3. Validate Current Data

```bash
npm run validate
```

### 4. Run Migration

```bash
npm run migrate
```

## 📊 CloudKit Schema

### Recipe Record Type

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `id` | String | ✅ | Unique identifier (UUID) |
| `name` | String | ✅ | Recipe name |
| `cuisine` | String | ✅ | Cuisine type |
| `mealType` | String | ✅ | "Kids" or "Regular" |
| `dietaryTags` | List<String> | ✅ | Dietary restrictions |
| `cookingTimeMinutes` | Int | ✅ | Cooking time in minutes |
| `servings` | Int | ✅ | Number of servings |
| `calories` | Int | ❌ | Calories per serving |
| `difficulty` | String | ✅ | "Easy", "Medium", "Hard" |
| `region` | String | ❌ | Regional origin |
| `ingredients` | List<String> | ❌ | Ingredient list |
| `utensils` | List<String> | ❌ | Required utensils |
| `steps` | List<String> | ❌ | Cooking instructions |
| `chefTips` | String | ❌ | Chef notes |
| `lunchboxPresentation` | String | ❌ | Kids presentation tips |
| `createdAt` | Date | ✅ | Creation timestamp |
| `updatedAt` | Date | ✅ | Update timestamp |
| `schemaVersion` | Int | ❌ | Schema version for migrations |

### Future-Proof Media Fields

| Field | Type | Description |
|-------|------|-------------|
| `coverImage` | Asset | Recipe thumbnail |
| `stepMedia` | List<Asset> | Step-by-step images/videos |
| `videoDemo` | Asset | Full cooking video |

## 🔧 Migration Process

### Phase 1: Data Validation
```bash
npm run validate
```
- Validates all JSON files
- Checks required fields
- Reports data quality issues
- Generates validation report

### Phase 2: Schema Conversion
```bash
npm run migrate
```
- Converts JSON recipes to CloudKit records
- Handles data type conversions
- Applies business logic transformations
- Uploads in batches to avoid rate limits

### Phase 3: Verification
- Compares record counts
- Validates data integrity
- Tests query performance
- Generates migration report

## 📱 iOS Integration

### 1. Add CloudKit Framework

```swift
import CloudKit
```

### 2. Configure CloudKit Container

```swift
// In your app's Info.plist
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.cheffy.app</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
    </dict>
</dict>
```

### 3. Use RecipeDataManager

```swift
// Switch to CloudKit
await RecipeDataManager.shared.switchDataSource(to: .cloudKit)

// Fetch recipes
let recipes = try await RecipeDataManager.shared.fetchRecipes(
    cuisine: .chinese,
    mealType: .kids,
    dietaryRestrictions: [.vegetarian],
    maxCookingTime: 30
)
```

## 🔍 Query Examples

### Basic Filtering
```swift
// Kids recipes only
let kidsRecipes = try await cloudKitService.fetchRecipes(
    mealType: "Kids",
    limit: 20
)

// Chinese vegetarian recipes
let chineseVeg = try await cloudKitService.fetchRecipes(
    cuisine: "Chinese",
    dietaryTags: ["Vegetarian"],
    limit: 10
)
```

### Advanced Filtering
```swift
// Quick healthy meals
let quickHealthy = try await cloudKitService.fetchRecipes(
    maxCookingTime: 20,
    dietaryTags: ["Vegetarian", "Gluten-Free"],
    difficulty: "Easy",
    limit: 15
)
```

### Text Search
```swift
// Search by ingredient or name
let searchResults = try await cloudKitService.searchRecipes(
    query: "chicken",
    limit: 10
)
```

## 🚨 Error Handling

### Common Issues

1. **Rate Limiting**: CloudKit has rate limits
   - Solution: Implement exponential backoff
   - Use batch operations

2. **Network Connectivity**: CloudKit requires internet
   - Solution: Implement offline fallback
   - Cache frequently accessed data

3. **Data Validation**: Invalid records cause failures
   - Solution: Validate before upload
   - Use migration validation script

### Error Recovery

```swift
do {
    let recipes = try await cloudKitService.fetchRecipes()
} catch CloudKitRecipeService.CloudKitError.quotaExceeded {
    // Handle quota exceeded
    showQuotaExceededAlert()
} catch CloudKitRecipeService.CloudKitError.networkError {
    // Fallback to local data
    await RecipeDataManager.shared.switchDataSource(to: .local)
} catch {
    // Handle other errors
    logger.error("Failed to fetch recipes: \(error)")
}
```

## 📈 Performance Optimization

### Caching Strategy
- Cache frequently accessed recipes
- Implement cache invalidation
- Use background refresh

### Query Optimization
- Use indexed fields for filtering
- Limit result sets appropriately
- Implement pagination for large datasets

### Batch Operations
- Upload recipes in batches
- Use CloudKit batch APIs
- Implement retry logic

## 🔮 Future Enhancements

### Media Support
- Recipe cover images
- Step-by-step photos
- Cooking videos
- Interactive tutorials

### Advanced Features
- Recipe ratings and reviews
- User favorites
- Recipe sharing
- Offline sync

### Analytics
- Recipe popularity metrics
- User engagement tracking
- Performance monitoring

## 🛠️ Development Tools

### Validation Script
```bash
# Validate all recipes
npm run validate

# Validate specific file
node validate-schema.js --file indian_cuisines.json
```

### Migration Script
```bash
# Full migration
npm run migrate

# Dry run (no upload)
npm run migrate:dry-run

# Migrate specific cuisine
node migrate-recipes.js --cuisine indian
```

### Testing
```bash
# Run tests
npm test

# Test specific functionality
npm test -- --grep "migration"
```

## 📋 Migration Checklist

- [ ] Validate all JSON files
- [ ] Configure CloudKit container
- [ ] Set up CloudKit schema
- [ ] Run migration script
- [ ] Verify data integrity
- [ ] Test iOS integration
- [ ] Implement error handling
- [ ] Add offline fallback
- [ ] Performance testing
- [ ] Deploy to production

## 🆘 Troubleshooting

### Migration Issues
1. Check CloudKit container configuration
2. Verify API credentials
3. Review validation errors
4. Check network connectivity

### iOS Integration Issues
1. Ensure CloudKit framework is linked
2. Check container identifier
3. Verify user authentication
4. Review error logs

### Performance Issues
1. Optimize queries
2. Implement caching
3. Use batch operations
4. Monitor CloudKit usage

## 📞 Support

For issues or questions:
- Check the validation report
- Review CloudKit logs
- Test with small datasets first
- Contact the development team

---

**Note**: This migration is designed to be future-proof and extensible. The schema supports adding new fields without breaking existing functionality.
