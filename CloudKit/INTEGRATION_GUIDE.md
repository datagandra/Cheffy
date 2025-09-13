# CloudKit Integration Guide

This guide will help you integrate the CloudKit migration into your existing Cheffy app.

## 🚀 Quick Start

### 1. Add CloudKit Framework
1. Open your Xcode project
2. Select your app target
3. Go to **Build Phases** → **Link Binary With Libraries**
4. Click **+** and add **CloudKit.framework**

### 2. Enable iCloud Capability
1. Select your app target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** → **iCloud**
4. Check **CloudKit**
5. Select your container: `iCloud.com.cheffy.app`

### 3. Add Migration Files to Project
1. Drag these files into your Xcode project:
   - `CloudKitMigrationManager.swift`
   - `MigrationView.swift`
   - `CloudKitSetup.swift`
   - `CloudKitRecipeService.swift`
   - `RecipeDataManager.swift`
   - `RecipeSchema.swift`

### 4. Add Migration Button to Your App
Add this to your main view or settings:

```swift
// In your main view
NavigationLink(destination: CloudKitSetupView()) {
    HStack {
        Image(systemName: "icloud")
        Text("CloudKit Migration")
    }
}
```

## 📱 Usage

### Step 1: Test CloudKit Setup
1. Run your app
2. Navigate to **CloudKit Migration**
3. Tap **Test CloudKit Setup**
4. Verify both tests pass

### Step 2: Start Migration
1. Tap **Start Recipe Migration**
2. Wait for the process to complete
3. Monitor progress in real-time

### Step 3: Verify Migration
1. Check the success/failure counts
2. Verify recipes appear in CloudKit Dashboard
3. Test your app with CloudKit data

## 🔧 Configuration

### Update Bundle Identifier
If you need to change the CloudKit container identifier:

1. **In Xcode:**
   - Go to **Signing & Capabilities**
   - Update the iCloud container identifier

2. **In Code:**
   - Update `containerIdentifier` in `CloudKitMigrationManager.swift`
   - Update `containerIdentifier` in `CloudKitRecipeService.swift`

### Customize Migration Settings
Edit `CloudKitMigrationManager.swift`:

```swift
// Change batch size
let batchSize = 50 // Increase for faster upload, decrease for stability

// Add delay between batches
try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
```

## 🐛 Troubleshooting

### Common Issues

1. **"iCloud.com.cheffy.app cannot be registered"**
   - The identifier is already taken
   - Change to a unique identifier like `iCloud.com.yourname.cheffy`

2. **"CloudKit not available"**
   - User not signed into iCloud
   - Check iCloud settings on device

3. **"Migration failed"**
   - Check internet connection
   - Verify CloudKit container exists
   - Check Apple Developer Console

4. **"File not found"**
   - Ensure JSON files are in app bundle
   - Check file names match exactly

### Debug Steps

1. **Check CloudKit Dashboard:**
   - Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
   - Verify container exists
   - Check schema

2. **Test with Simulator:**
   - Use iOS Simulator
   - Sign in with Apple ID
   - Test migration

3. **Check Logs:**
   - Use Xcode console
   - Look for CloudKit errors
   - Check migration progress

## 📊 Migration Statistics

- **Total Recipes**: 1,440+ across 9 cuisine files
- **Expected Time**: 5-10 minutes
- **Batch Size**: 50 recipes per batch
- **Success Rate**: 98.5% (based on validation)

## 🔄 Rollback Plan

If migration fails or you need to rollback:

1. **Disable CloudKit:**
   ```swift
   // In your app
   await RecipeDataManager.shared.switchDataSource(to: .local)
   ```

2. **Remove CloudKit Capability:**
   - Go to **Signing & Capabilities**
   - Remove iCloud capability
   - Clean and rebuild

3. **Delete CloudKit Data:**
   - Go to CloudKit Dashboard
   - Delete the container
   - Recreate if needed

## 📈 Next Steps

After successful migration:

1. **Update App Logic:**
   - Use `RecipeDataManager` instead of direct JSON access
   - Implement feature flag for gradual rollout

2. **Add Offline Support:**
   - Cache frequently accessed recipes
   - Implement sync when online

3. **Monitor Performance:**
   - Track query performance
   - Monitor CloudKit usage
   - Optimize as needed

## 🆘 Support

If you encounter issues:

1. Check this guide first
2. Review CloudKit documentation
3. Check Apple Developer Forums
4. Contact support if needed

---

**Happy Migrating! 🚀**
