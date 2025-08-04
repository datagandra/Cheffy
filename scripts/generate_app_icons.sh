#!/bin/bash

# App Icon Generator Script for Cheffy
# This script generates all required app icon sizes from a base 1024x1024 icon

echo "🎨 Generating App Icons for Cheffy..."

# Check if base icon exists
if [ ! -f "AppStore/base_icon_1024.png" ]; then
    echo "❌ Error: base_icon_1024.png not found in AppStore/ directory"
    echo "Please create a 1024x1024 PNG icon and place it in AppStore/base_icon_1024.png"
    exit 1
fi

# Create output directory
mkdir -p "Cheffy/Assets.xcassets/AppIcon.appiconset"

# iPhone Icons
echo "📱 Generating iPhone icons..."

# iPhone 20pt @2x (40x40)
convert "AppStore/base_icon_1024.png" -resize 40x40 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-40@2x.png"

# iPhone 20pt @3x (60x60)
convert "AppStore/base_icon_1024.png" -resize 60x60 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-60@3x.png"

# iPhone 29pt @2x (58x58)
convert "AppStore/base_icon_1024.png" -resize 58x58 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-58@2x.png"

# iPhone 29pt @3x (87x87)
convert "AppStore/base_icon_1024.png" -resize 87x87 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-87@3x.png"

# iPhone 40pt @2x (80x80)
convert "AppStore/base_icon_1024.png" -resize 80x80 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-80@2x.png"

# iPhone 40pt @3x (120x120)
convert "AppStore/base_icon_1024.png" -resize 120x120 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-120@3x.png"

# iPhone 60pt @2x (120x120)
convert "AppStore/base_icon_1024.png" -resize 120x120 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-120@2x.png"

# iPhone 60pt @3x (180x180)
convert "AppStore/base_icon_1024.png" -resize 180x180 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-180@3x.png"

# iPad Icons
echo "📱 Generating iPad icons..."

# iPad 20pt @1x (20x20)
convert "AppStore/base_icon_1024.png" -resize 20x20 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-20@1x.png"

# iPad 20pt @2x (40x40)
convert "AppStore/base_icon_1024.png" -resize 40x40 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-40@2x.png"

# iPad 29pt @1x (29x29)
convert "AppStore/base_icon_1024.png" -resize 29x29 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-29@1x.png"

# iPad 29pt @2x (58x58)
convert "AppStore/base_icon_1024.png" -resize 58x58 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-58@2x.png"

# iPad 40pt @1x (40x40)
convert "AppStore/base_icon_1024.png" -resize 40x40 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-40@1x.png"

# iPad 40pt @2x (80x80)
convert "AppStore/base_icon_1024.png" -resize 80x80 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-80@2x.png"

# iPad 76pt @2x (152x152)
convert "AppStore/base_icon_1024.png" -resize 152x152 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-152@2x.png"

# iPad 83.5pt @2x (167x167)
convert "AppStore/base_icon_1024.png" -resize 167x167 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-167@2x.png"

# App Store Icon
echo "🏪 Generating App Store icon..."
convert "AppStore/base_icon_1024.png" -resize 1024x1024 "Cheffy/Assets.xcassets/AppIcon.appiconset/Icon-1024@1x.png"

echo "✅ App icons generated successfully!"
echo "📁 Icons saved to: Cheffy/Assets.xcassets/AppIcon.appiconset/"
echo ""
echo "Next steps:"
echo "1. Open Xcode and verify all icons are displayed correctly"
echo "2. Build and test the app to ensure icons load properly"
echo "3. Archive the app for App Store submission" 