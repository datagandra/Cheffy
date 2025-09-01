#!/usr/bin/env python3
"""
Test script to verify Xcode Cloud automation setup
"""

import os
import sys

def test_dependencies():
    """Test if all required dependencies are installed"""
    print("🔍 Testing dependencies...")
    
    try:
        import jwt
        print("✅ PyJWT installed")
    except ImportError:
        print("❌ PyJWT not installed")
        return False
    
    try:
        import requests
        print("✅ requests installed")
    except ImportError:
        print("❌ requests not installed")
        return False
    
    try:
        import cryptography
        print("✅ cryptography installed")
    except ImportError:
        print("❌ cryptography not installed")
        return False
    
    return True

def test_config_files():
    """Test if configuration files exist"""
    print("\n📁 Testing configuration files...")
    
    required_files = [
        "xcode_cloud_automation.py",
        "xcode_cloud_config.json",
        "requirements.txt"
    ]
    
    missing_files = []
    for file in required_files:
        if os.path.exists(file):
            print(f"✅ {file} exists")
        else:
            print(f"❌ {file} missing")
            missing_files.append(file)
    
    return len(missing_files) == 0

def test_private_key():
    """Test if private key file exists"""
    print("\n🔑 Testing private key...")
    
    private_key_path = "AuthKey_PZZU8CMTA6.p8"
    if os.path.exists(private_key_path):
        print(f"✅ {private_key_path} exists")
        return True
    else:
        print(f"❌ {private_key_path} missing")
        print("   Please download your .p8 file from App Store Connect")
        return False

def check_config_values():
    """Check if configuration values are set"""
    print("\n⚙️  Checking configuration values...")
    
    # Read config file
    try:
        with open("xcode_cloud_config.json", "r") as f:
            import json
            config = json.load(f)
            
        app_config = config.get("app_store_connect", {})
        
        # Check each required value
        required_values = {
            "issuer_id": app_config.get("issuer_id"),
            "key_id": app_config.get("key_id"),
            "app_id": app_config.get("app_id"),
            "private_key_path": app_config.get("private_key_path")
        }
        
        for key, value in required_values.items():
            if value and value != f"YOUR_{key.upper()}_HERE":
                print(f"✅ {key}: {value}")
            else:
                print(f"❌ {key}: Not set")
        
        return all(value and value != f"YOUR_{key.upper()}_HERE" 
                  for key, value in required_values.items())
        
    except Exception as e:
        print(f"❌ Error reading config: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 Xcode Cloud Setup Verification")
    print("=================================")
    
    all_tests_passed = True
    
    # Test dependencies
    if not test_dependencies():
        all_tests_passed = False
    
    # Test config files
    if not test_config_files():
        all_tests_passed = False
    
    # Test private key
    if not test_private_key():
        all_tests_passed = False
    
    # Check config values
    if not check_config_values():
        all_tests_passed = False
    
    print("\n" + "="*50)
    if all_tests_passed:
        print("✅ All tests passed! Your setup is ready.")
        print("\n📋 Next steps:")
        print("1. Update your Issuer ID and App ID in the config files")
        print("2. Run: python3 xcode_cloud_automation.py")
        print("3. Start automating your Xcode Cloud builds!")
    else:
        print("❌ Some tests failed. Please fix the issues above.")
        print("\n📖 See XCODE_CLOUD_SETUP_GUIDE.md for detailed instructions.")
    
    return all_tests_passed

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
