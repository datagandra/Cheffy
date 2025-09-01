#!/usr/bin/env python3
"""
Test script to check App Store Connect API access and Xcode Cloud status
"""

import jwt
import time
import requests
from datetime import datetime, timedelta

def generate_jwt_token(issuer_id, key_id, private_key_path):
    """Generate JWT token for App Store Connect API authentication"""
    with open(private_key_path, 'r') as f:
        private_key = f.read()
    
    payload = {
        'iss': issuer_id,
        'iat': int(time.time()),
        'exp': int(time.time()) + 1200,  # 20 minutes expiry
        'aud': 'appstoreconnect-v1'
    }
    
    token = jwt.encode(payload, private_key, algorithm='ES256', headers={
        'kid': key_id,
        'typ': 'JWT'
    })
    
    return token

def test_app_access():
    """Test basic app access"""
    # Configuration
    ISSUER_ID = "1fe78bc1-c522-4611-94d9-5e49639f876e"
    KEY_ID = "PZZU8CMTA6"
    PRIVATE_KEY_PATH = "AuthKey_PZZU8CMTA6.p8"
    APP_ID = "6751781514"
    
    try:
        # Generate token
        token = generate_jwt_token(ISSUER_ID, KEY_ID, PRIVATE_KEY_PATH)
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        base_url = "https://api.appstoreconnect.apple.com/v1"
        
        print("🔍 Testing App Store Connect API access...")
        
        # 1. Test basic apps endpoint
        print("\n1. Testing apps endpoint...")
        response = requests.get(f"{base_url}/apps", headers=headers)
        if response.status_code == 200:
            apps = response.json().get('data', [])
            print(f"✅ Successfully accessed apps endpoint")
            print(f"   Found {len(apps)} apps")
            for app in apps:
                app_id = app['id']
                app_name = app['attributes']['name']
                print(f"   - {app_name} (ID: {app_id})")
        else:
            print(f"❌ Failed to access apps endpoint: {response.status_code}")
            print(f"   Response: {response.text}")
        
        # 2. Test specific app access
        print(f"\n2. Testing access to app {APP_ID}...")
        response = requests.get(f"{base_url}/apps/{APP_ID}", headers=headers)
        if response.status_code == 200:
            app_data = response.json().get('data', {})
            app_name = app_data.get('attributes', {}).get('name', 'Unknown')
            print(f"✅ Successfully accessed app: {app_name}")
        else:
            print(f"❌ Failed to access app {APP_ID}: {response.status_code}")
            print(f"   Response: {response.text}")
        
        # 3. Test Xcode Cloud workflows endpoint
        print(f"\n3. Testing Xcode Cloud workflows...")
        response = requests.get(f"{base_url}/apps/{APP_ID}/ciWorkflows", headers=headers)
        if response.status_code == 200:
            workflows = response.json().get('data', [])
            print(f"✅ Successfully accessed Xcode Cloud workflows")
            print(f"   Found {len(workflows)} workflows")
            for workflow in workflows:
                workflow_name = workflow['attributes']['name']
                workflow_id = workflow['id']
                print(f"   - {workflow_name} (ID: {workflow_id})")
        else:
            print(f"❌ Failed to access Xcode Cloud workflows: {response.status_code}")
            print(f"   Response: {response.text}")
            print(f"\n💡 This might mean:")
            print(f"   - Xcode Cloud is not enabled for this app")
            print(f"   - No workflows are configured")
            print(f"   - API key doesn't have CI/CD permissions")
        
        # 4. Test builds endpoint
        print(f"\n4. Testing builds endpoint...")
        response = requests.get(f"{base_url}/apps/{APP_ID}/ciBuildRuns", headers=headers)
        if response.status_code == 200:
            builds = response.json().get('data', [])
            print(f"✅ Successfully accessed builds endpoint")
            print(f"   Found {len(builds)} builds")
        else:
            print(f"❌ Failed to access builds endpoint: {response.status_code}")
            print(f"   Response: {response.text}")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_app_access()
