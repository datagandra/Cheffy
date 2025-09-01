#!/bin/bash

# Xcode Cloud Automation - cURL Examples
# Replace the variables below with your actual values

# Configuration
ISSUER_ID="1fe78bc1-c522-4611-94d9-5e49639f876e"
KEY_ID="PZZU8CMTA6"
APP_ID="6751781514"
PRIVATE_KEY_FILE="AuthKey_PZZU8CMTA6.p8"

# Generate JWT Token (requires jwt-cli or similar tool)
# You can use: npm install -g jsonwebtoken-cli
# Then: jwt encode --secret @$PRIVATE_KEY_FILE --alg ES256 --iss $ISSUER_ID --aud appstoreconnect-v1 --exp +20m

JWT_TOKEN="YOUR_GENERATED_JWT_TOKEN"

# Base URL
BASE_URL="https://api.appstoreconnect.apple.com/v1"

echo "🚀 Xcode Cloud Automation Examples"
echo "=================================="

# 1. List all workflows for the app
echo -e "\n📋 1. Listing workflows..."
curl -X GET \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE_URL/apps/$APP_ID/ciWorkflows" | jq '.'

# 2. Get specific workflow details
echo -e "\n🔍 2. Getting workflow details..."
WORKFLOW_ID="YOUR_WORKFLOW_ID"
curl -X GET \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE_URL/ciWorkflows/$WORKFLOW_ID" | jq '.'

# 3. List recent builds
echo -e "\n📦 3. Listing recent builds..."
curl -X GET \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE_URL/apps/$APP_ID/ciBuildRuns?limit=10" | jq '.'

# 4. Get specific build details
echo -e "\n🔍 4. Getting build details..."
BUILD_ID="YOUR_BUILD_ID"
curl -X GET \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE_URL/ciBuildRuns/$BUILD_ID" | jq '.'

# 5. Trigger a new build
echo -e "\n🚀 5. Triggering new build..."
curl -X POST \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "type": "ciBuildRuns",
      "attributes": {
        "branch": "main"
      }
    }
  }' \
  "$BASE_URL/ciWorkflows/$WORKFLOW_ID/builds" | jq '.'

# 6. Cancel a build
echo -e "\n❌ 6. Canceling build..."
curl -X PATCH \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "type": "ciBuildRuns",
      "id": "'$BUILD_ID'",
      "attributes": {
        "canceled": true
      }
    }
  }' \
  "$BASE_URL/ciBuildRuns/$BUILD_ID" | jq '.'

# 7. Retry a failed build
echo -e "\n🔄 7. Retrying build..."
curl -X POST \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE_URL/ciBuildRuns/$BUILD_ID/retry" | jq '.'

# 8. Get build artifacts
echo -e "\n📁 8. Getting build artifacts..."
curl -X GET \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  "$BASE_URL/ciBuildRuns/$BUILD_ID/artifacts" | jq '.'

# 9. Download artifact
echo -e "\n⬇️ 9. Downloading artifact..."
ARTIFACT_ID="YOUR_ARTIFACT_ID"
curl -X GET \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -o "artifact.zip" \
  "$BASE_URL/ciArtifacts/$ARTIFACT_ID/download"

echo -e "\n✅ Examples completed!"
echo -e "\n📝 Notes:"
echo "1. Replace all placeholder values with your actual IDs"
echo "2. Generate JWT token using your .p8 private key"
echo "3. Install 'jq' for JSON formatting: brew install jq"
echo "4. Make sure your API key has the correct permissions"
