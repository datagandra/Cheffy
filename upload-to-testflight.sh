#!/bin/bash

echo "🚀 Uploading Cheffy to TestFlight"
echo "=================================="

# Configuration
SCHEME="Cheffy"
CONFIGURATION="Release"
ARCHIVE_PATH="./Cheffy.xcarchive"
EXPORT_PATH="./Cheffy-Export"
EXPORT_OPTIONS="./app-store-exportoptions.plist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Creating Archive...${NC}"
xcodebuild -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -destination 'generic/platform=iOS' \
           -archivePath "$ARCHIVE_PATH" \
           archive

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Archive created successfully!${NC}"
    
    echo -e "${YELLOW}Step 2: Exporting IPA...${NC}"
    xcodebuild -exportArchive \
               -archivePath "$ARCHIVE_PATH" \
               -exportPath "$EXPORT_PATH" \
               -exportOptionsPlist "$EXPORT_OPTIONS"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ IPA exported successfully!${NC}"
        
        echo -e "${YELLOW}Step 3: Uploading to App Store Connect...${NC}"
        
        # Upload using xcrun altool (older method)
        if command -v xcrun &> /dev/null; then
            echo "Uploading with xcrun altool..."
            xcrun altool --upload-app \
                        --type ios \
                        --file "$EXPORT_PATH/Cheffy.ipa" \
                        --username "$APPLE_ID" \
                        --password "$APP_SPECIFIC_PASSWORD"
        else
            echo -e "${RED}❌ xcrun not found${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✅ Upload completed!${NC}"
        echo ""
        echo "📱 Next Steps:"
        echo "1. Go to App Store Connect: https://appstoreconnect.apple.com"
        echo "2. Navigate to My Apps → Cheffy → TestFlight"
        echo "3. Your build should appear within 5-30 minutes"
        echo "4. Submit for review if needed"
        
    else
        echo -e "${RED}❌ IPA export failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Archive creation failed${NC}"
    exit 1
fi
