#!/bin/bash

echo "🚀 Setting up Xcode Cloud Automation for Cheffy"
echo "================================================"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "Please install Python 3 and try again."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is required but not installed."
    echo "Please install pip3 and try again."
    exit 1
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install -r requirements.txt

# Install jq for JSON formatting
if ! command -v jq &> /dev/null; then
    echo "📦 Installing jq for JSON formatting..."
    if command -v brew &> /dev/null; then
        brew install jq
    else
        echo "⚠️  Please install jq manually for JSON formatting"
        echo "   macOS: brew install jq"
        echo "   Ubuntu: sudo apt-get install jq"
    fi
fi

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x xcode_cloud_automation.py
chmod +x xcode_cloud_curl_examples.sh

# Create directories
echo "📁 Creating directories..."
mkdir -p builds
mkdir -p logs

echo ""
echo "✅ Setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Get your App Store Connect API key:"
echo "   - Go to https://appstoreconnect.apple.com/access/api"
echo "   - Generate a new API key with 'App Manager' access"
echo "   - Download the .p8 file"
echo ""
echo "2. Get your app identifiers:"
echo "   - App ID: From App Store Connect URL"
echo "   - Issuer ID: From API Keys page"
echo "   - Key ID: From downloaded .p8 filename"
echo ""
echo "3. Update configuration:"
echo "   - Edit xcode_cloud_config.json with your values"
echo "   - Place your .p8 file in the project directory"
echo ""
echo "4. Test the setup:"
echo "   - Run: python3 xcode_cloud_automation.py"
echo "   - Or run: ./xcode_cloud_curl_examples.sh"
echo ""
echo "🔗 Useful links:"
echo "- App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi"
echo "- Xcode Cloud: https://developer.apple.com/xcode-cloud/"
echo "- API Reference: https://developer.apple.com/documentation/appstoreconnectapi/ciworkflows"
