#!/bin/bash

# App Validation Script for Cheffy
# This script validates the app for App Store submission

echo "🔍 Validating Cheffy App for App Store Submission..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo ""
echo "📱 === APP VALIDATION CHECKLIST ==="
echo ""

# 1. Check if project builds successfully
echo "1. Building project..."
xcodebuild -project Cheffy.xcodeproj -scheme Cheffy -destination 'platform=iOS Simulator,name=iPhone 16' build > build.log 2>&1
BUILD_SUCCESS=$?
print_status $BUILD_SUCCESS "Project builds successfully"

# 2. Check for hardcoded API keys
echo ""
echo "2. Checking for hardcoded API keys..."
HARDCODED_KEYS=$(grep -r "AIzaSy" Cheffy/ --include="*.swift" --include="*.plist" | wc -l)
if [ $HARDCODED_KEYS -eq 0 ]; then
    print_status 0 "No hardcoded API keys found"
else
    print_status 1 "Found $HARDCODED_KEYS hardcoded API keys"
    grep -r "AIzaSy" Cheffy/ --include="*.swift" --include="*.plist"
fi

# 3. Check Info.plist usage descriptions
echo ""
echo "3. Checking Info.plist usage descriptions..."
if grep -q "NSMicrophoneUsageDescription" project.yml; then
    print_status 0 "Microphone usage description present"
else
    print_status 1 "Microphone usage description missing"
fi

if grep -q "NSSpeechRecognitionUsageDescription" project.yml; then
    print_status 0 "Speech recognition usage description present"
else
    print_status 1 "Speech recognition usage description missing"
fi

# 4. Check app icons
echo ""
echo "4. Checking app icons..."
ICON_COUNT=$(find Cheffy/Assets.xcassets/AppIcon.appiconset -name "*.png" 2>/dev/null | wc -l)
if [ $ICON_COUNT -gt 0 ]; then
    print_status 0 "App icons found ($ICON_COUNT files)"
else
    print_status 1 "No app icons found"
    print_warning "Run: ./scripts/generate_app_icons.sh"
fi

# 5. Check for debug code
echo ""
echo "5. Checking for debug code..."
DEBUG_CODE=$(grep -r "print(" Cheffy/ --include="*.swift" | grep -v "//" | wc -l)
if [ $DEBUG_CODE -eq 0 ]; then
    print_status 0 "No debug print statements found"
else
    print_warning "Found $DEBUG_CODE debug print statements"
    grep -r "print(" Cheffy/ --include="*.swift" | grep -v "//"
fi

# 6. Check for TODO comments
echo ""
echo "6. Checking for TODO comments..."
TODO_COUNT=$(grep -r "TODO" Cheffy/ --include="*.swift" | wc -l)
if [ $TODO_COUNT -eq 0 ]; then
    print_status 0 "No TODO comments found"
else
    print_warning "Found $TODO_COUNT TODO comments"
    grep -r "TODO" Cheffy/ --include="*.swift"
fi

# 7. Check deployment target
echo ""
echo "7. Checking deployment target..."
DEPLOYMENT_TARGET=$(grep "iOS:" project.yml | head -1 | sed 's/.*iOS: "\(.*\)"/\1/')
if [ "$DEPLOYMENT_TARGET" = "17.0" ]; then
    print_status 0 "Deployment target is iOS 17.0 (current)"
else
    print_status 1 "Deployment target is $DEPLOYMENT_TARGET (should be 17.0)"
fi

# 8. Check bundle identifier
echo ""
echo "8. Checking bundle identifier..."
BUNDLE_ID=$(grep "PRODUCT_BUNDLE_IDENTIFIER" project.yml | head -1 | sed 's/.*PRODUCT_BUNDLE_IDENTIFIER: \(.*\)/\1/')
if [ "$BUNDLE_ID" = "com.cheffy.app" ]; then
    print_status 0 "Bundle identifier is correct: $BUNDLE_ID"
else
    print_status 1 "Bundle identifier is incorrect: $BUNDLE_ID"
fi

# 9. Check for required files
echo ""
echo "9. Checking required files..."
REQUIRED_FILES=(
    "Cheffy/CheffyApp.swift"
    "Cheffy/ContentView.swift"
    "Cheffy/Presentation/Views/OnboardingView.swift"
    "Cheffy/Data/API/OpenAIClient.swift"
    "Cheffy/Domain/Entities/Recipe.swift"
    "project.yml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status 0 "✓ $file"
    else
        print_status 1 "✗ $file (missing)"
    fi
done

# 10. Check for localization files
echo ""
echo "10. Checking localization..."
LOCALIZATION_DIRS=$(find Cheffy/Resources -name "*.lproj" -type d 2>/dev/null | wc -l)
if [ $LOCALIZATION_DIRS -gt 0 ]; then
    print_status 0 "Localization found ($LOCALIZATION_DIRS languages)"
else
    print_warning "No localization files found"
fi

# 11. Check for accessibility features
echo ""
echo "11. Checking accessibility features..."
ACCESSIBILITY_FEATURES=$(grep -r "accessibility" Cheffy/ --include="*.swift" | wc -l)
if [ $ACCESSIBILITY_FEATURES -gt 0 ]; then
    print_status 0 "Accessibility features found ($ACCESSIBILITY_FEATURES references)"
else
    print_warning "No accessibility features found"
fi

# 12. Check for error handling
echo ""
echo "12. Checking error handling..."
ERROR_HANDLING=$(grep -r "catch\|Error\|throw" Cheffy/ --include="*.swift" | wc -l)
if [ $ERROR_HANDLING -gt 0 ]; then
    print_status 0 "Error handling found ($ERROR_HANDLING references)"
else
    print_warning "Limited error handling found"
fi

echo ""
echo "📊 === VALIDATION SUMMARY ==="
echo ""

if [ $BUILD_SUCCESS -eq 0 ]; then
    echo -e "${GREEN}🎉 App validation completed successfully!${NC}"
    echo ""
    echo "Next steps for App Store submission:"
    echo "1. Generate app icons: ./scripts/generate_app_icons.sh"
    echo "2. Create screenshots for all device sizes"
    echo "3. Archive the app in Xcode: Product > Archive"
    echo "4. Validate the archive: Archive > Validate App"
    echo "5. Upload to App Store Connect"
    echo ""
    echo "📱 Your Cheffy app is ready for submission!"
else
    echo -e "${RED}❌ App validation failed. Please fix the issues above.${NC}"
    echo ""
    echo "Common fixes:"
    echo "- Ensure all required files are present"
    echo "- Fix any compilation errors"
    echo "- Remove hardcoded API keys"
    echo "- Add missing usage descriptions"
fi

echo ""
echo "📋 For detailed App Store requirements, see: AppStore/README.md" 