#!/bin/bash

echo "🔍 Verifying Cheffy Setup"
echo "========================="

# Check Xcode installation
echo "📱 Checking Xcode..."
if command -v xcodebuild &> /dev/null; then
    echo "✅ Xcode found: $(xcodebuild -version | head -n 1)"
else
    echo "❌ Xcode not found"
    exit 1
fi

# Check code signing identities
echo ""
echo "🔐 Checking code signing identities..."
IDENTITIES=$(security find-identity -v -p codesigning)
if [ -n "$IDENTITIES" ]; then
    echo "✅ Code signing identities found:"
    echo "$IDENTITIES"
else
    echo "❌ No code signing identities found"
    echo "   You need to create certificates in Xcode → Preferences → Accounts"
fi

# Check connected devices
echo ""
echo "📱 Checking connected devices..."
DEVICES=$(xcrun devicectl list devices 2>/dev/null)
if [ -n "$DEVICES" ]; then
    echo "✅ Connected devices found:"
    echo "$DEVICES"
else
    echo "ℹ️  No devices connected"
    echo "   Connect your iPhone/iPad to get the UDID"
fi

# Check project configuration
echo ""
echo "📋 Checking project configuration..."
if [ -f "Cheffy.xcodeproj/project.pbxproj" ]; then
    echo "✅ Cheffy project found"
    
    # Check bundle identifier
    BUNDLE_ID=$(grep -A 1 "PRODUCT_BUNDLE_IDENTIFIER" Cheffy.xcodeproj/project.pbxproj | grep "com.cheffy.app" | head -1)
    if [ -n "$BUNDLE_ID" ]; then
        echo "✅ Bundle identifier: com.cheffy.app"
    else
        echo "❌ Bundle identifier not found or incorrect"
    fi
    
    # Check version
    VERSION=$(grep "INFOPLIST_KEY_CFBundleShortVersionString" Cheffy.xcodeproj/project.pbxproj | head -1)
    if [ -n "$VERSION" ]; then
        echo "✅ Version info found: $VERSION"
    else
        echo "❌ Version info not found"
    fi
else
    echo "❌ Cheffy project not found"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Connect your device and get the UDID"
echo "2. Create App ID in Apple Developer Portal"
echo "3. Create distribution certificate"
echo "4. Register your device"
echo "5. Create provisioning profiles"
echo "6. Configure Xcode project"
echo "7. Test on device"
echo "8. Archive and upload to TestFlight"

echo ""
echo "🔗 Useful Links:"
echo "- Apple Developer Portal: https://developer.apple.com/account"
echo "- App Store Connect: https://appstoreconnect.apple.com"
echo "- Certificates: https://developer.apple.com/account/resources/certificates/list"
echo "- Devices: https://developer.apple.com/account/resources/devices/list"
echo "- Provisioning Profiles: https://developer.apple.com/account/resources/profiles/list"
