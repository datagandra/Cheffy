#!/bin/bash

# API Key Setup Script for Cheffy
# This script helps developers set up their Gemini API key

echo "🔧 Cheffy API Key Setup"
echo "=========================="
echo ""

# Check if SecureConfig.plist exists
if [ ! -f "Cheffy/Resources/SecureConfig.plist" ]; then
    echo "❌ SecureConfig.plist not found!"
    echo "Creating from template..."
    cp Cheffy/Resources/SecureConfig.template.plist Cheffy/Resources/SecureConfig.plist
    echo "✅ SecureConfig.plist created from template"
fi

echo ""
echo "📋 To set up your Gemini API key:"
echo ""
echo "1. Go to Google AI Studio: https://makersuite.google.com/app/apikey"
echo "2. Create a new API key"
echo "3. Copy the key (starts with 'AIza')"
echo "4. Open Cheffy/Resources/SecureConfig.plist"
echo "5. Replace 'YOUR_GEMINI_API_KEY_HERE' with your actual API key"
echo ""
echo "⚠️  IMPORTANT: Never commit your real API key to git!"
echo "   The SecureConfig.plist file is already in .gitignore"
echo ""

# Check if API key is still the placeholder
if grep -q "YOUR_GEMINI_API_KEY_HERE" Cheffy/Resources/SecureConfig.plist; then
    echo "❌ API key not configured yet"
    echo "   Please follow the steps above to add your API key"
else
    echo "✅ API key appears to be configured"
fi

echo ""
echo "🔍 Additional troubleshooting:"
echo "- Check your internet connection"
echo "- Verify the API key format (should start with 'AIza')"
echo "- Ensure Gemini API is enabled in your Google Cloud project"
echo "- Check API quota and billing status"
echo ""
echo "📱 In the app, you can also:"
echo "- Go to Settings > LLM Diagnostics to run connection tests"
echo "- Use the API key input in the diagnostic view"
echo "" 