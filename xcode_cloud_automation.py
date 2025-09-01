#!/usr/bin/env python3
"""
Xcode Cloud Automation Script for Cheffy App
Uses App Store Connect API to manage Xcode Cloud workflows and builds
"""

import jwt
import time
import requests
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional

class XcodeCloudAutomation:
    def __init__(self, issuer_id: str, key_id: str, private_key_path: str, app_id: str):
        """
        Initialize Xcode Cloud automation client
        
        Args:
            issuer_id: Your App Store Connect Issuer ID
            key_id: Your API Key ID
            private_key_path: Path to your .p8 private key file
            app_id: Your app's App Store Connect ID
        """
        self.issuer_id = issuer_id
        self.key_id = key_id
        self.private_key_path = private_key_path
        self.app_id = app_id
        self.base_url = "https://api.appstoreconnect.apple.com/v1"
        self.token = None
        self.token_expiry = None
    
    def _generate_jwt_token(self) -> str:
        """Generate JWT token for App Store Connect API authentication"""
        if self.token and self.token_expiry and datetime.now() < self.token_expiry:
            return self.token
        
        # Read private key
        with open(self.private_key_path, 'r') as f:
            private_key = f.read()
        
        # Create JWT payload
        payload = {
            'iss': self.issuer_id,
            'iat': int(time.time()),
            'exp': int(time.time()) + 1200,  # 20 minutes expiry
            'aud': 'appstoreconnect-v1'
        }
        
        # Generate JWT
        self.token = jwt.encode(payload, private_key, algorithm='ES256', headers={
            'kid': self.key_id,
            'typ': 'JWT'
        })
        
        self.token_expiry = datetime.now() + timedelta(minutes=19)  # Refresh 1 min early
        return self.token
    
    def _make_request(self, endpoint: str, method: str = 'GET', data: Dict = None) -> Dict:
        """Make authenticated request to App Store Connect API"""
        token = self._generate_jwt_token()
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        url = f"{self.base_url}{endpoint}"
        
        if method == 'GET':
            response = requests.get(url, headers=headers)
        elif method == 'POST':
            response = requests.post(url, headers=headers, json=data)
        elif method == 'DELETE':
            response = requests.delete(url, headers=headers)
        else:
            raise ValueError(f"Unsupported method: {method}")
        
        response.raise_for_status()
        return response.json()
    
    def list_workflows(self) -> List[Dict]:
        """List all Xcode Cloud workflows for the app"""
        endpoint = f"/apps/{self.app_id}/ciWorkflows"
        response = self._make_request(endpoint)
        return response.get('data', [])
    
    def get_workflow(self, workflow_id: str) -> Dict:
        """Get details of a specific workflow"""
        endpoint = f"/ciWorkflows/{workflow_id}"
        response = self._make_request(endpoint)
        return response.get('data', {})
    
    def list_builds(self, workflow_id: str = None, limit: int = 20) -> List[Dict]:
        """List builds, optionally filtered by workflow"""
        if workflow_id:
            endpoint = f"/ciWorkflows/{workflow_id}/builds"
        else:
            endpoint = f"/apps/{self.app_id}/ciBuildRuns"
        
        endpoint += f"?limit={limit}"
        response = self._make_request(endpoint)
        return response.get('data', [])
    
    def get_build(self, build_id: str) -> Dict:
        """Get details of a specific build"""
        endpoint = f"/ciBuildRuns/{build_id}"
        response = self._make_request(endpoint)
        return response.get('data', {})
    
    def trigger_build(self, workflow_id: str, branch: str = None, tag: str = None, commit: str = None) -> Dict:
        """Trigger a new build for a workflow"""
        endpoint = f"/ciWorkflows/{workflow_id}/builds"
        
        data = {
            "data": {
                "type": "ciBuildRuns",
                "attributes": {}
            }
        }
        
        if branch:
            data["data"]["attributes"]["branch"] = branch
        elif tag:
            data["data"]["attributes"]["tag"] = tag
        elif commit:
            data["data"]["attributes"]["commit"] = commit
        
        response = self._make_request(endpoint, method='POST', data=data)
        return response.get('data', {})
    
    def cancel_build(self, build_id: str) -> Dict:
        """Cancel a running build"""
        endpoint = f"/ciBuildRuns/{build_id}"
        data = {
            "data": {
                "type": "ciBuildRuns",
                "id": build_id,
                "attributes": {
                    "canceled": True
                }
            }
        }
        response = self._make_request(endpoint, method='PATCH', data=data)
        return response.get('data', {})
    
    def retry_build(self, build_id: str) -> Dict:
        """Retry a failed build"""
        endpoint = f"/ciBuildRuns/{build_id}/retry"
        response = self._make_request(endpoint, method='POST')
        return response.get('data', {})
    
    def get_build_artifacts(self, build_id: str) -> List[Dict]:
        """Get artifacts for a build"""
        endpoint = f"/ciBuildRuns/{build_id}/artifacts"
        response = self._make_request(endpoint)
        return response.get('data', [])
    
    def download_artifact(self, artifact_id: str, output_path: str):
        """Download a build artifact"""
        endpoint = f"/ciArtifacts/{artifact_id}/download"
        token = self._generate_jwt_token()
        headers = {'Authorization': f'Bearer {token}'}
        
        response = requests.get(f"{self.base_url}{endpoint}", headers=headers, stream=True)
        response.raise_for_status()
        
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

def main():
    """Example usage of Xcode Cloud automation"""
    
    # Configuration - Replace with your actual values
    ISSUER_ID = "1fe78bc1-c522-4611-94d9-5e49639f876e"  # From App Store Connect
    KEY_ID = "PZZU8CMTA6"        # From downloaded .p8 file
    PRIVATE_KEY_PATH = "AuthKey_PZZU8CMTA6.p8"  # Path to your .p8 file
    APP_ID = "6751781514"        # Your app's App Store Connect ID
    
    # Initialize automation client
    xcode_cloud = XcodeCloudAutomation(ISSUER_ID, KEY_ID, PRIVATE_KEY_PATH, APP_ID)
    
    try:
        # List all workflows
        print("📋 Listing workflows...")
        workflows = xcode_cloud.list_workflows()
        for workflow in workflows:
            workflow_id = workflow['id']
            workflow_name = workflow['attributes']['name']
            print(f"  - {workflow_name} (ID: {workflow_id})")
        
        if workflows:
            # Get first workflow details
            first_workflow = workflows[0]
            workflow_id = first_workflow['id']
            
            print(f"\n🔍 Workflow details for: {first_workflow['attributes']['name']}")
            workflow_details = xcode_cloud.get_workflow(workflow_id)
            print(f"  Status: {workflow_details['attributes']['isEnabled']}")
            print(f"  Repository: {workflow_details['attributes']['repositoryName']}")
            
            # List recent builds
            print(f"\n📦 Recent builds for workflow: {workflow_id}")
            builds = xcode_cloud.list_builds(workflow_id, limit=5)
            for build in builds:
                build_id = build['id']
                status = build['attributes']['completionStatus']
                created = build['attributes']['createdDate']
                print(f"  - Build {build_id}: {status} (Created: {created})")
            
            # Trigger a new build (uncomment to use)
            # print(f"\n🚀 Triggering new build for workflow: {workflow_id}")
            # new_build = xcode_cloud.trigger_build(workflow_id, branch="main")
            # print(f"  New build ID: {new_build['id']}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        print("\n🔧 Troubleshooting:")
        print("1. Check your Issuer ID, Key ID, and App ID")
        print("2. Ensure your .p8 file is in the correct location")
        print("3. Verify your API key has the correct permissions")
        print("4. Make sure your app has Xcode Cloud enabled")

if __name__ == "__main__":
    main()
