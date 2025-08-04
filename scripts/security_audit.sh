#!/bin/bash

# Security Audit Script for Cheffy
# This script validates API key security and configuration

echo "🔒 Security Audit for Cheffy App"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "🔍 Checking for hardcoded API keys..."
HARDCODED_KEYS=$(grep -r "AIzaSy" Cheffy/ --include="*.swift" --include="*.plist" | grep -v "YOUR_GEMINI_API_KEY_HERE" | wc -l)
if [ $HARDCODED_KEYS -eq 0 ]; then
    print_status 0 "No hardcoded API keys found"
else
    print_status 1 "Found $HARDCODED_KEYS hardcoded API keys"
    echo "   Hardcoded keys found in:"
    grep -r "AIzaSy" Cheffy/ --include="*.swift" --include="*.plist" | grep -v "YOUR_GEMINI_API_KEY_HERE"
fi

echo ""
echo "🔍 Checking .gitignore for sensitive files..."
if grep -q "SecureConfig.plist" .gitignore; then
    print_status 0 "SecureConfig.plist is in .gitignore"
else
    print_status 1 "SecureConfig.plist is NOT in .gitignore"
fi

if grep -q "\.env" .gitignore; then
    print_status 0 "Environment files are in .gitignore"
else
    print_status 1 "Environment files are NOT in .gitignore"
fi

echo ""
echo "🔍 Checking for secure configuration files..."
if [ -f "Cheffy/Resources/SecureConfig.template.plist" ]; then
    print_status 0 "Secure configuration template exists"
else
    print_status 1 "Secure configuration template missing"
fi

if [ -f "Cheffy/Resources/SecureConfig.plist" ]; then
    print_warning "SecureConfig.plist exists - ensure it's not committed"
else
    print_info "SecureConfig.plist not found (expected for production)"
fi

echo ""
echo "🔍 Checking for environment variable usage..."
ENV_USAGE=$(grep -r "ProcessInfo.processInfo.environment" Cheffy/ --include="*.swift" | wc -l)
if [ $ENV_USAGE -gt 0 ]; then
    print_status 0 "Environment variable usage found ($ENV_USAGE references)"
else
    print_warning "No environment variable usage found"
fi

echo ""
echo "🔍 Checking for keychain usage..."
KEYCHAIN_USAGE=$(grep -r "Keychain" Cheffy/ --include="*.swift" | wc -l)
if [ $KEYCHAIN_USAGE -gt 0 ]; then
    print_status 0 "Keychain usage found ($KEYCHAIN_USAGE references)"
else
    print_warning "No keychain usage found"
fi

echo ""
echo "🔍 Checking for encryption usage..."
ENCRYPTION_USAGE=$(grep -r "CryptoKit\|AES\|encrypt\|decrypt" Cheffy/ --include="*.swift" | wc -l)
if [ $ENCRYPTION_USAGE -gt 0 ]; then
    print_status 0 "Encryption usage found ($ENCRYPTION_USAGE references)"
else
    print_warning "No encryption usage found"
fi

echo ""
echo "🔍 Checking for secure logging..."
SECURE_LOGGING=$(grep -r "logger\.security\|os_log" Cheffy/ --include="*.swift" | wc -l)
if [ $SECURE_LOGGING -gt 0 ]; then
    print_status 0 "Secure logging found ($SECURE_LOGGING references)"
else
    print_warning "Limited secure logging found"
fi

echo ""
echo "🔍 Checking for debug print statements..."
DEBUG_PRINTS=$(grep -r "print(" Cheffy/ --include="*.swift" | grep -v "//" | wc -l)
if [ $DEBUG_PRINTS -eq 0 ]; then
    print_status 0 "No debug print statements found"
else
    print_warning "Found $DEBUG_PRINTS debug print statements"
fi

echo ""
echo "🔍 Checking for TODO comments..."
TODO_COUNT=$(grep -r "TODO" Cheffy/ --include="*.swift" | wc -l)
if [ $TODO_COUNT -eq 0 ]; then
    print_status 0 "No TODO comments found"
else
    print_warning "Found $TODO_COUNT TODO comments"
fi

echo ""
echo "📊 === SECURITY AUDIT SUMMARY ==="
echo ""

# Calculate security score
SCORE=0
TOTAL_CHECKS=10

if [ $HARDCODED_KEYS -eq 0 ]; then SCORE=$((SCORE + 1)); fi
if grep -q "SecureConfig.plist" .gitignore; then SCORE=$((SCORE + 1)); fi
if grep -q "\.env" .gitignore; then SCORE=$((SCORE + 1)); fi
if [ -f "Cheffy/Resources/SecureConfig.template.plist" ]; then SCORE=$((SCORE + 1)); fi
if [ $ENV_USAGE -gt 0 ]; then SCORE=$((SCORE + 1)); fi
if [ $KEYCHAIN_USAGE -gt 0 ]; then SCORE=$((SCORE + 1)); fi
if [ $ENCRYPTION_USAGE -gt 0 ]; then SCORE=$((SCORE + 1)); fi
if [ $SECURE_LOGGING -gt 0 ]; then SCORE=$((SCORE + 1)); fi
if [ $DEBUG_PRINTS -eq 0 ]; then SCORE=$((SCORE + 1)); fi
if [ $TODO_COUNT -eq 0 ]; then SCORE=$((SCORE + 1)); fi

PERCENTAGE=$((SCORE * 100 / TOTAL_CHECKS))

echo "Security Score: $SCORE/$TOTAL_CHECKS ($PERCENTAGE%)"

if [ $PERCENTAGE -ge 90 ]; then
    echo -e "${GREEN}🎉 Excellent security posture!${NC}"
elif [ $PERCENTAGE -ge 70 ]; then
    echo -e "${YELLOW}⚠️  Good security posture, but room for improvement${NC}"
else
    echo -e "${RED}❌ Security issues need to be addressed${NC}"
fi

echo ""
echo "🔒 Security Recommendations:"
echo "1. Use environment variables for production API keys"
echo "2. Store sensitive data in keychain"
echo "3. Use encryption for highly sensitive data"
echo "4. Implement secure logging"
echo "5. Remove debug print statements"
echo "6. Add SecureConfig.plist to .gitignore"
echo "7. Use the SecureConfigManager for all API key access"
echo ""
echo "📋 For detailed security setup, see: AppStore/README.md" 