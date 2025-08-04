#!/bin/bash

# Create Base App Icon for Cheffy
# This script creates a simple 1024x1024 base icon using ImageMagick

echo "🎨 Creating base app icon for Cheffy..."

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "❌ Error: ImageMagick (convert) is not installed"
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Create AppStore directory if it doesn't exist
mkdir -p AppStore

# Create a simple 1024x1024 icon with a chef hat design
convert -size 1024x1024 xc:transparent \
  -fill "#FF6B35" \
  -draw "circle 512,512 512,512" \
  -fill "#FFFFFF" \
  -font Arial-Bold -pointsize 120 -gravity center \
  -draw "text 0,0 '🍽️'" \
  -fill "#FF6B35" \
  -font Arial-Bold -pointsize 60 -gravity center \
  -draw "text 0,100 'Cheffy'" \
  AppStore/base_icon_1024.png

echo "✅ Base icon created: AppStore/base_icon_1024.png"
echo ""
echo "Next steps:"
echo "1. Review the generated icon"
echo "2. Run: ./scripts/generate_app_icons.sh"
echo "3. Open Xcode to verify all icons are displayed correctly" 