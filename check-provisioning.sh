#!/bin/bash

echo "🔍 Checking Provisioning Setup"
echo "=============================="

# Check code signing identities
echo "🔐 Checking code signing identities..."
IDENTITIES=$(security find-identity -v -p codesigning)
echo "$IDENTITIES"

# Check for distribution certificate
if echo "$IDENTITIES" | grep -q "Distribution"; then
    echo "✅ Distribution certificate found"
else
    echo "❌ Distribution certificate missing"
    echo "   Create one in Xcode → Preferences → Accounts → Manage Certificates"
fi

# Check for development certificate
if echo "$IDENTITIES" | grep -q "Development"; then
    echo "✅ Development certificate found"
else
    echo "❌ Development certificate missing"
fi

# Check project configuration
echo ""
echo "📋 Checking project configuration..."
if [ -f "Cheffy.xcodeproj/project.pbxproj" ]; then
    BUNDLE_ID=$(grep -A 1 "PRODUCT_BUNDLE_IDENTIFIER" Cheffy.xcodeproj/project.pbxproj | grep "com.cheffy.app" | head -1)
    if [ -n "$BUNDLE_ID" ]; then
        echo "✅ Bundle identifier: com.cheffy.app"
    else
        echo "❌ Bundle identifier not found or incorrect"
    fi
fi

# Check export options
echo ""
echo "📦 Checking export options..."
if [ -f "app-store-exportoptions.plist" ]; then
    TEAM_ID=$(grep -A 1 "teamID" app-store-exportoptions.plist | grep -o '[A-Z0-9]\{10\}' | head -1)
    if [ -n "$TEAM_ID" ]; then
        echo "✅ Team ID configured: $TEAM_ID"
    else
        echo "❌ Team ID not configured"
    fi
else
    echo "❌ Export options file not found"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Create App ID in Apple Developer Portal"
echo "2. Register your device (UDID: 00008130000E50AE3406001C)"
echo "3. Create distribution certificate in Xcode"
echo "4. Create App Store provisioning profile"
echo "5. Configure Xcode project signing"
echo "6. Test the export again"

echo ""
echo "🔗 Useful Links:"
echo "- App IDs: https://developer.apple.com/account/resources/identifiers/list"
echo "- Devices: https://developer.apple.com/account/resources/devices/list"
echo "- Provisioning Profiles: https://developer.apple.com/account/resources/profiles/list"
