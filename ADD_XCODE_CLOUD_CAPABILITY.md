# 🔧 Visual Guide: Adding Xcode Cloud Capability

## **Step-by-Step with Visual References**

### **Step 1: Project Selection**
```
┌─────────────────────────────────────────────────────────┐
│ Xcode Project Navigator (Left Sidebar)                  │
├─────────────────────────────────────────────────────────┤
│ 📁 Cheffy.xcodeproj  ← CLICK HERE (blue project icon)   │
│   ├─ 📁 Cheffy                                        │
│   ├─ 📁 CheffyTests                                   │
│   └─ 📁 CheffyUITests                                 │
└─────────────────────────────────────────────────────────┘
```

### **Step 2: Signing & Capabilities Tab**
```
┌─────────────────────────────────────────────────────────┐
│ Main Editor Area                                        │
├─────────────────────────────────────────────────────────┤
│ [General] [Signing & Capabilities] [Build Settings] ... │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Signing & Capabilities                              │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │ Team: Your Team Name                                │ │
│ │ Bundle Identifier: com.cheffy.app                  │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ Capabilities                                    │ │ │
│ │ │                                                 │ │ │
│ │ │ [Other capabilities...]                         │ │ │
│ │ │                                                 │ │ │
│ │ │ [+ Capability] ← CLICK THIS BUTTON              │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### **Step 3: Add Capability Dialog**
```
┌─────────────────────────────────────────────────────────┐
│ Add Capability                                         │
├─────────────────────────────────────────────────────────┤
│ Search: [Xcode Cloud                    ]              │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Results:                                            │ │
│ │                                                     │ │
│ │ ☐ Access WiFi Information                           │ │
│ │ ☐ App Groups                                       │ │
│ │ ☐ Associated Domains                               │ │
│ │ ☐ Background Modes                                 │ │
│ │ ☐ Data Protection                                  │ │
│ │ ☐ HealthKit                                        │ │
│ │ ☐ iCloud                                           │ │
│ │ ☐ In-App Purchase                                  │ │
│ │ ☐ Maps                                             │ │
│ │ ☐ Network Extensions                               │ │
│ │ ☐ Personal VPN                                     │ │
│ │ ☐ Push Notifications                               │ │
│ │ ☐ Siri                                             │ │
│ │ ☐ Xcode Cloud ← DOUBLE-CLICK THIS                  │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ [Cancel] [Add]                                         │
└─────────────────────────────────────────────────────────┘
```

### **Step 4: After Adding Xcode Cloud**
```
┌─────────────────────────────────────────────────────────┐
│ Signing & Capabilities                                  │
├─────────────────────────────────────────────────────────┤
│ Team: Your Team Name                                    │
│ Bundle Identifier: com.cheffy.app                      │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Capabilities                                        │ │
│ │                                                     │ │
│ │ [Other capabilities...]                             │ │
│ │                                                     │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ Xcode Cloud ← NEW SECTION ADDED                 │ │ │
│ │ │                                                 │ │ │
│ │ │ [Get Started] ← CLICK THIS TO CONFIGURE         │ │ │
│ │ │                                                 │ │ │
│ │ │ Status: Not configured                           │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## **Troubleshooting**

### **If You Don't See "+ Capability" Button:**

1. **Make sure you're on the project level**:
   - Click the blue "Cheffy" project icon (not any target)
   - You should see "Cheffy" at the top of the editor

2. **Check if you're in the right tab**:
   - Make sure you're on "Signing & Capabilities" tab
   - Not "General" or "Build Settings"

3. **Try alternative method**:
   - Right-click in the capabilities area
   - Look for "Add Capability" in context menu

### **If "Xcode Cloud" Doesn't Appear in Search:**

1. **Check your Apple Developer account**:
   - Make sure you're signed in with the correct account
   - Verify your account has the right permissions

2. **Check app status**:
   - App must be in "Ready for Submission" or later
   - Cannot add Xcode Cloud to apps in "Prepare for Submission"

3. **Try refreshing**:
   - Close and reopen Xcode
   - Sign out and sign back in to Apple Developer account

### **If You Get an Error:**

1. **"Xcode Cloud not available"**:
   - Check Apple Developer account status
   - Ensure you have Admin or App Manager role

2. **"Cannot add capability"**:
   - Verify app is not in "Prepare for Submission"
   - Check if you have the right permissions

## **Next Steps After Adding**

Once you successfully add Xcode Cloud:

1. **Click "Get Started"** in the Xcode Cloud section
2. **Connect your repository** (GitHub)
3. **Create your first workflow**:
   - Name: "Production Build"
   - Branch: main
   - Actions: Build, Test, Archive

## **Verification**

After adding Xcode Cloud capability, run:
```bash
python3 test_app_access.py
```

You should see:
```
✅ Successfully accessed Xcode Cloud workflows
   Found 1 workflows
   - Production Build (ID: workflow-id-here)
```
