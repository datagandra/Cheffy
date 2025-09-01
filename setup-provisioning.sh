#!/bin/bash

echo "🚀 Cheffy Provisioning Setup Guide"
echo "=================================="
echo ""

# Check current status
echo "📋 Current Status Check:"
./check-provisioning.sh

echo ""
echo "🔧 Setup Instructions:"
echo "======================"
echo ""

echo "Step 1: Create App ID"
echo "---------------------"
echo "1. Open: https://developer.apple.com/account/resources/identifiers/list"
echo "2. Click '+' to register new identifier"
echo "3. Select 'App IDs' → 'Continue'"
echo "4. Select 'App' → 'Continue'"
echo "5. Fill in:"
echo "   - Description: Cheffy AI Recipe Generator"
echo "   - Bundle ID: com.cheffy.app"
echo "6. Click 'Continue' → 'Register'"
echo ""

echo "Step 2: Create Distribution Certificate"
echo "---------------------------------------"
echo "1. In Xcode: Xcode → Preferences → Accounts"
echo "2. Select your Apple ID (Naveen Gandra)"
echo "3. Click 'Manage Certificates'"
echo "4. Click '+' → 'Apple Distribution'"
echo "5. Download and install"
echo ""

echo "Step 3: Register Your Device"
echo "----------------------------"
echo "1. Open: https://developer.apple.com/account/resources/devices/list"
echo "2. Click '+' to register new device"
echo "3. Select device type: iPhone"
echo "4. Enter UDID: 00008130000E50AE3406001C"
echo "5. Name: Naveen's iPhone"
echo "6. Click 'Continue' → 'Register'"
echo ""

echo "Step 4: Create Provisioning Profile"
echo "-----------------------------------"
echo "1. Open: https://developer.apple.com/account/resources/profiles/list"
echo "2. Click '+' to create new profile"
echo "3. Select 'Ad Hoc' (for testing) or 'App Store' (for TestFlight)"
echo "4. Select App ID: com.cheffy.app"
echo "5. Select your distribution certificate"
echo "6. Select your device: 00008130000E50AE3406001C"
echo "7. Name: Cheffy Ad Hoc Distribution (or App Store Distribution)"
echo "8. Click 'Continue' → 'Generate'"
echo "9. Download and install"
echo ""

echo "Step 5: Configure Xcode Project"
echo "-------------------------------"
echo "1. Open Cheffy.xcodeproj in Xcode"
echo "2. Select 'Cheffy' target"
echo "3. Go to 'Signing & Capabilities' tab"
echo "4. Check 'Automatically manage signing'"
echo "5. Select Team: 7KXZ82TP32"
echo "6. Verify Bundle ID: com.cheffy.app"
echo ""

echo "Step 6: Test Setup"
echo "------------------"
echo "After completing all steps above, run:"
echo "./check-provisioning.sh"
echo ""

echo "Step 7: Create IPA"
echo "------------------"
echo "Once everything is set up, run:"
echo "./create-ipa.sh"
echo ""

echo "📱 Quick Commands:"
echo "=================="
echo "Check status: ./check-provisioning.sh"
echo "Create IPA: ./create-ipa.sh"
echo "Upload to TestFlight: ./upload-to-testflight.sh"
echo ""

echo "🔗 Quick Links:"
echo "==============="
echo "App IDs: https://developer.apple.com/account/resources/identifiers/list"
echo "Devices: https://developer.apple.com/account/resources/devices/list"
echo "Profiles: https://developer.apple.com/account/resources/profiles/list"
echo ""

echo "⚠️  Important Notes:"
echo "==================="
echo "- Bundle ID must be exactly: com.cheffy.app"
echo "- Team ID: 7KXZ82TP32"
echo "- Device UDID: 00008130000E50AE3406001C"
echo "- Make sure to download and install certificates/profiles"
echo ""

read -p "Press Enter when you've completed Step 1 (App ID creation)..."

echo ""
echo "✅ Step 1 completed! Now proceed with Step 2 (Distribution Certificate)..."

read -p "Press Enter when you've completed Step 2 (Distribution Certificate)..."

echo ""
echo "✅ Step 2 completed! Now proceed with Step 3 (Device Registration)..."

read -p "Press Enter when you've completed Step 3 (Device Registration)..."

echo ""
echo "✅ Step 3 completed! Now proceed with Step 4 (Provisioning Profile)..."

read -p "Press Enter when you've completed Step 4 (Provisioning Profile)..."

echo ""
echo "✅ Step 4 completed! Now proceed with Step 5 (Xcode Configuration)..."

read -p "Press Enter when you've completed Step 5 (Xcode Configuration)..."

echo ""
echo "🎉 All steps completed! Let's verify the setup..."

./check-provisioning.sh

echo ""
echo "🚀 Ready to create IPA? Run: ./create-ipa.sh"
