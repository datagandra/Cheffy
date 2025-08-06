#!/bin/bash

# Generate iOS App Icons from SVG
# This script converts the SVG logo to all required iOS app icon sizes

echo "🎨 Generating iOS App Icons for Cheffy..."

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick is required. Please install it first:"
    echo "   brew install imagemagick"
    exit 1
fi

# Create icons directory if it doesn't exist
mkdir -p Cheffy/Resources/AppIcons

# iOS App Icon sizes (in pixels)
sizes=(
    "20x20"
    "29x29" 
    "40x40"
    "58x58"
    "60x60"
    "76x76"
    "80x80"
    "87x87"
    "120x120"
    "152x152"
    "167x167"
    "180x180"
    "1024x1024"
)

# Generate each size
for size in "${sizes[@]}"; do
    echo "📱 Generating ${size} icon..."
    
    # Extract dimensions
    width=$(echo $size | cut -d'x' -f1)
    height=$(echo $size | cut -d'x' -f2)
    
    # Convert SVG to PNG
    convert Cheffy/Resources/AppIcon.svg \
        -resize "${width}x${height}" \
        -background transparent \
        -gravity center \
        -extent "${width}x${height}" \
        "Cheffy/Resources/AppIcons/AppIcon-${size}.png"
done

echo "✅ App icons generated successfully!"
echo "📁 Icons saved to: Cheffy/Resources/AppIcons/"
echo ""
echo "🎯 Next steps:"
echo "1. Add the PNG files to your Xcode project's Assets.xcassets"
echo "2. Update your Info.plist to reference the new app icon"
echo "3. Test the icons on different devices and orientations" 