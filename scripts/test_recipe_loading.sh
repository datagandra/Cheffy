#!/bin/bash

echo "🧪 Testing Recipe Database Loading"
echo "=================================="

# Check if recipe files exist in the app bundle
APP_PATH="/Users/naveen/Library/Developer/Xcode/DerivedData/Cheffy-fxkxjxnrnigsmwfurecsvkswvxgq/Build/Products/Debug-iphonesimulator/Cheffy.app"

echo "📁 Checking recipe files in app bundle..."
echo "App path: $APP_PATH"

# List all JSON files in the app bundle
echo ""
echo "📋 Recipe files found:"
find "$APP_PATH" -name "*.json" -type f | while read -r file; do
    filename=$(basename "$file")
    size=$(stat -f%z "$file" 2>/dev/null || echo "unknown")
    echo "  ✅ $filename ($size bytes)"
done

echo ""
echo "🔍 Checking specific recipe files:"

# Check for specific recipe files
recipe_files=(
    "indian_cuisines.json"
    "american_cuisines.json"
    "mexican_cuisines.json"
    "european_cuisines.json"
    "asian_cuisines_extended.json"
    "middle_eastern_african_cuisines.json"
    "latin_american_cuisines.json"
)

for file in "${recipe_files[@]}"; do
    if [ -f "$APP_PATH/$file" ]; then
        size=$(stat -f%z "$APP_PATH/$file" 2>/dev/null || echo "unknown")
        echo "  ✅ $file ($size bytes)"
    else
        echo "  ❌ $file (not found)"
    fi
done

echo ""
echo "📊 Summary:"
echo "  - Recipe files should be loaded from the app bundle"
echo "  - The app should display recipe counts in Settings > Database Test"
echo "  - Check the simulator to see if recipes are loading correctly"
echo ""
echo "🎯 Next steps:"
echo "  1. Open the app in the simulator"
echo "  2. Go to Settings tab"
echo "  3. Tap 'Database Test' button"
echo "  4. Check if recipe counts are displayed correctly" 