#!/bin/bash

echo "📱 Creating IPA for Cheffy"
echo "=========================="

# Set variables
SCHEME="Cheffy"
CONFIGURATION="Release"
ARCHIVE_PATH="./Cheffy.xcarchive"
EXPORT_PATH="./Cheffy-Export"
EXPORT_OPTIONS="./ad-hoc-exportoptions.plist"

echo "🔨 Step 1: Creating Archive..."
xcodebuild -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -destination 'generic/platform=iOS' \
           -archivePath "$ARCHIVE_PATH" \
           archive

if [ $? -eq 0 ]; then
    echo "✅ Archive created successfully!"
    
    echo "📦 Step 2: Exporting IPA..."
    xcodebuild -exportArchive \
               -archivePath "$ARCHIVE_PATH" \
               -exportPath "$EXPORT_PATH" \
               -exportOptionsPlist "$EXPORT_OPTIONS"
    
    if [ $? -eq 0 ]; then
        echo "✅ IPA exported successfully!"
        echo "📱 IPA location: $EXPORT_PATH/Cheffy.ipa"
        echo ""
        echo "🚀 Next Steps:"
        echo "1. Open Transporter app"
        echo "2. Drag and drop the IPA file"
        echo "3. Click 'Upload'"
    else
        echo "❌ IPA export failed"
        exit 1
    fi
else
    echo "❌ Archive creation failed"
    exit 1
fi
