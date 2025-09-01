# 🚀 Xcode Cloud Automation Setup Guide for Cheffy

## ✅ **Current Status**
- ✅ API Key ID: `PZZU8CMTA6`
- ⏳ **Need**: Issuer ID (from App Store Connect)
- ⏳ **Need**: App ID (from your Cheffy app URL)
- ⏳ **Need**: `.p8` private key file

## 📋 **Step-by-Step Setup**

### **1. Get Your Issuer ID**
1. Go to [App Store Connect API Keys](https://appstoreconnect.apple.com/access/api)
2. Look for **"Issuer ID"** on the page
3. Copy the long string (format: `57246b42-0c5e-4e1f-9c8a-1234567890ab`)

### **2. Get Your App ID**
1. Go to [App Store Connect Apps](https://appstoreconnect.apple.com/apps)
2. Click on your **Cheffy** app
3. Look at the URL: `https://appstoreconnect.apple.com/apps/[APP_ID]/...`
4. Copy the **App ID** from the URL

### **3. Download Your Private Key**
1. In App Store Connect API Keys page
2. Find your key `PZZU8CMTA6`
3. Click **"Download"** to get the `.p8` file
4. **Important**: You can only download this once!
5. Save it as `AuthKey_PZZU8CMTA6.p8` in your project directory

### **4. Update Configuration**
Once you have all the values, update these files:

#### **Update `xcode_cloud_config.json`:**
```json
{
  "app_store_connect": {
    "issuer_id": "YOUR_ISSUER_ID_HERE",
    "key_id": "PZZU8CMTA6",
    "private_key_path": "AuthKey_PZZU8CMTA6.p8",
    "app_id": "YOUR_APP_ID_HERE"
  }
}
```

#### **Update `xcode_cloud_automation.py`:**
```python
ISSUER_ID = "YOUR_ISSUER_ID_HERE"
KEY_ID = "PZZU8CMTA6"
PRIVATE_KEY_PATH = "AuthKey_PZZU8CMTA6.p8"
APP_ID = "YOUR_APP_ID_HERE"
```

#### **Update `xcode_cloud_curl_examples.sh`:**
```bash
ISSUER_ID="YOUR_ISSUER_ID_HERE"
KEY_ID="PZZU8CMTA6"
APP_ID="YOUR_APP_ID_HERE"
PRIVATE_KEY_FILE="AuthKey_PZZU8CMTA6.p8"
```

### **5. Install Dependencies**
```bash
# Run the setup script
./setup_xcode_cloud.sh

# Or manually install
pip3 install -r requirements.txt
brew install jq  # For JSON formatting
```

### **6. Test Your Setup**
```bash
# Test with Python
python3 xcode_cloud_automation.py

# Test with cURL (after generating JWT token)
./xcode_cloud_curl_examples.sh
```

## 🔧 **Common Issues & Solutions**

### **Authentication Errors**
- ✅ Check your Issuer ID is correct
- ✅ Verify your `.p8` file is in the right location
- ✅ Ensure your API key has "App Manager" access

### **App Not Found**
- ✅ Verify your App ID is correct
- ✅ Make sure your app has Xcode Cloud enabled
- ✅ Check that your API key has access to the app

### **Permission Denied**
- ✅ Ensure your API key has the right permissions
- ✅ Check that your Apple Developer account is active
- ✅ Verify you're using the correct Team ID

## 📚 **Available Commands**

### **List Workflows**
```bash
python3 xcode_cloud_automation.py
```

### **Trigger Build**
```python
# In Python script
xcode_cloud.trigger_build(workflow_id, branch="main")
```

### **Monitor Builds**
```python
# List recent builds
builds = xcode_cloud.list_builds(workflow_id, limit=10)

# Get build status
build = xcode_cloud.get_build(build_id)
status = build['attributes']['completionStatus']
```

### **Download Artifacts**
```python
# Get artifacts
artifacts = xcode_cloud.get_build_artifacts(build_id)

# Download artifact
xcode_cloud.download_artifact(artifact_id, "build.zip")
```

## 🔗 **Useful Links**
- [App Store Connect API Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [Xcode Cloud Documentation](https://developer.apple.com/xcode-cloud/)
- [CI Workflows API Reference](https://developer.apple.com/documentation/appstoreconnectapi/ciworkflows)

## 📞 **Need Help?**
If you encounter issues:
1. Check the error messages in the console
2. Verify all IDs are correct
3. Ensure your `.p8` file is properly formatted
4. Check your API key permissions in App Store Connect
