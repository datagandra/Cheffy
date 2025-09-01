# 🚀 Cheffy Ad-Hoc Distribution Guide

## Overview
This guide will help you create an ad-hoc distribution of the Cheffy app for testing on specific devices.

## Prerequisites
- ✅ Paid Apple Developer Account ($99/year)
- ✅ Xcode installed
- ✅ Cheffy project ready for distribution

## Step-by-Step Setup

### 1. Configure Code Signing in Xcode

1. **Open Xcode** and open your Cheffy project
2. **Select the "Cheffy" target** in the project navigator
3. **Go to "Signing & Capabilities" tab**
4. **Check "Automatically manage signing"**
5. **Select your Team** from the dropdown
6. **Verify Bundle Identifier** is set to `com.cheffy.app`

### 2. Create Distribution Certificate

1. In Xcode, go to **Xcode → Preferences → Accounts**
2. **Select your Apple ID** (the one with your paid developer account)
3. Click **"Manage Certificates"**
4. Click **"+"** and select **"Apple Distribution"**
5. **Download and install** the certificate

### 3. Create Ad-Hoc Provisioning Profile

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list)
2. Click **"+"** to create new profile
3. Select **"Ad Hoc"** distribution
4. Select your **App ID** (com.cheffy.app)
5. Select the **distribution certificate** you just created
6. **Add device UDIDs** for testing (up to 100 devices)
7. **Name the profile** (e.g., "Cheffy Ad Hoc Distribution")
8. **Download and install** the profile

### 4. Get Your Team ID

1. In **Xcode → Preferences → Accounts**
2. Select your Apple ID
3. **Copy the Team ID** (it's a 10-character string)

### 5. Update Export Options

1. **Open** `ad-hoc-exportoptions.plist`
2. **Replace** `YOUR_ACTUAL_TEAM_ID_HERE` with your actual Team ID
3. **Save** the file

### 6. Create Archive

```bash
xcodebuild -scheme Cheffy -configuration Release -destination 'generic/platform=iOS' -archivePath ./Cheffy.xcarchive archive
```

### 7. Export for Ad-Hoc Distribution

```bash
xcodebuild -exportArchive -archivePath ./Cheffy.xcarchive -exportPath ./ad-hoc-export -exportOptionsPlist ./ad-hoc-exportoptions.plist
```

## Expected Output

After successful export, you'll find:
- `./ad-hoc-export/Cheffy.ipa` - The distributable app
- `./ad-hoc-export/Cheffy.xcarchive` - The archive (can be deleted)

## Distribution Methods

### Method 1: TestFlight (Recommended)
1. Upload the .ipa to App Store Connect
2. Add testers via TestFlight
3. Testers receive email invitation

### Method 2: Direct Installation
1. Use tools like **Diawi** or **TestFlight** for direct distribution
2. Upload .ipa to the service
3. Share the download link with testers

### Method 3: Manual Installation
1. Use **Xcode** to install directly on connected devices
2. Use **Apple Configurator** for bulk installation

## Troubleshooting

### Common Issues

1. **"No valid identities found"**
   - Solution: Create distribution certificate in Xcode

2. **"Signing for requires a development team"**
   - Solution: Configure team in project settings

3. **"Provisioning profile not found"**
   - Solution: Download and install provisioning profile

4. **"Device not registered"**
   - Solution: Add device UDID to provisioning profile

### Getting Device UDIDs

1. **Connect device** to Mac
2. **Open Xcode** → Window → Devices and Simulators
3. **Select device** and copy the Identifier
4. **Add to provisioning profile** in Apple Developer Portal

## Security Notes

- ⚠️ **Ad-hoc builds expire** after 1 year
- ⚠️ **Limited to 100 devices** per provisioning profile
- ⚠️ **Requires device registration** in Apple Developer Portal
- ✅ **No App Store review** required
- ✅ **Perfect for beta testing**

## Next Steps

After successful ad-hoc distribution:
1. **Test thoroughly** on target devices
2. **Collect feedback** from testers
3. **Fix any issues** found
4. **Prepare for App Store submission** when ready

---

**Need Help?** Check the console output for specific error messages and refer to Apple's documentation.
