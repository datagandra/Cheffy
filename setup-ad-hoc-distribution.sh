#!/bin/bash

echo "🚀 Cheffy Ad-Hoc Distribution Setup"
echo "=================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed or not in PATH"
    exit 1
fi

echo "✅ Xcode found: $(xcodebuild -version | head -n 1)"

# Check for code signing identities
echo ""
echo "🔍 Checking code signing identities..."
security find-identity -v -p codesigning

echo ""
echo "📋 Next Steps:"
echo "1. Open Xcode and configure code signing for the Cheffy target"
echo "2. Create distribution certificate in Xcode → Preferences → Accounts"
echo "3. Create ad-hoc provisioning profile in Apple Developer Portal"
echo "4. Update the Team ID in ad-hoc-exportoptions.plist"
echo "5. Run the archive and export commands"

echo ""
echo "🔧 Commands to run after setup:"
echo ""
echo "# Create archive:"
echo "xcodebuild -scheme Cheffy -configuration Release -destination 'generic/platform=iOS' -archivePath ./Cheffy.xcarchive archive"
echo ""
echo "# Export for ad-hoc distribution:"
echo "xcodebuild -exportArchive -archivePath ./Cheffy.xcarchive -exportPath ./ad-hoc-export -exportOptionsPlist ./ad-hoc-exportoptions.plist"
echo ""
echo "📱 The exported .ipa file will be in ./ad-hoc-export/"
