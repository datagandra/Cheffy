# 🚀 Quick Start Commands for Xcode Cloud Automation

## **After completing setup, run these commands:**

### **1. Test Your Setup**
```bash
python3 test_xcode_cloud_setup.py
```

### **2. List Your Workflows**
```bash
python3 xcode_cloud_automation.py
```

### **3. Trigger a Build (Python)**
```python
# Edit xcode_cloud_automation.py and uncomment the trigger line
# Then run:
python3 xcode_cloud_automation.py
```

### **4. Monitor Builds**
```bash
# Check build status
python3 -c "
from xcode_cloud_automation import XcodeCloudAutomation
xcode_cloud = XcodeCloudAutomation('YOUR_ISSUER_ID', 'PZZU8CMTA6', 'AuthKey_PZZU8CMTA6.p8', 'YOUR_APP_ID')
builds = xcode_cloud.list_builds(limit=5)
for build in builds:
    print(f'Build {build[\"id\"]}: {build[\"attributes\"][\"completionStatus\"]}')
"
```

### **5. Generate JWT Token for cURL**
```bash
# Install jwt-cli
npm install -g jsonwebtoken-cli

# Generate token
jwt encode --secret @AuthKey_PZZU8CMTA6.p8 --alg ES256 --iss YOUR_ISSUER_ID --aud appstoreconnect-v1 --exp +20m
```

### **6. Use cURL Examples**
```bash
# Update the JWT_TOKEN variable in xcode_cloud_curl_examples.sh
# Then run:
./xcode_cloud_curl_examples.sh
```

## **Common Workflows:**

### **Daily Build Check**
```bash
python3 -c "
from xcode_cloud_automation import XcodeCloudAutomation
xcode_cloud = XcodeCloudAutomation('YOUR_ISSUER_ID', 'PZZU8CMTA6', 'AuthKey_PZZU8CMTA6.p8', 'YOUR_APP_ID')
workflows = xcode_cloud.list_workflows()
for workflow in workflows:
    print(f'Workflow: {workflow[\"attributes\"][\"name\"]}')
    builds = xcode_cloud.list_builds(workflow['id'], limit=1)
    if builds:
        latest = builds[0]
        print(f'  Latest build: {latest[\"attributes\"][\"completionStatus\"]}')
"
```

### **Trigger Production Build**
```bash
python3 -c "
from xcode_cloud_automation import XcodeCloudAutomation
xcode_cloud = XcodeCloudAutomation('YOUR_ISSUER_ID', 'PZZU8CMTA6', 'AuthKey_PZZU8CMTA6.p8', 'YOUR_APP_ID')
workflows = xcode_cloud.list_workflows()
for workflow in workflows:
    if 'production' in workflow['attributes']['name'].lower():
        result = xcode_cloud.trigger_build(workflow['id'], branch='main')
        print(f'Triggered build: {result[\"id\"]}')
        break
"
```

## **Troubleshooting:**

### **Check API Key Permissions**
```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/apps"
```

### **Verify App Access**
```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/apps/YOUR_APP_ID"
```

### **Test Workflow Access**
```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/apps/YOUR_APP_ID/ciWorkflows"
```
