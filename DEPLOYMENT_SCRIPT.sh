#!/bin/bash

echo "================================================================================"
echo "                   FIREBASE DEPLOYMENT SCRIPT"
echo "================================================================================"
echo ""
echo "This script will deploy Cloud Functions and Firestore Rules"
echo "Required for: Device A automatic logout when Device B logs in"
echo ""

# Get project ID
PROJECT_ID=$(grep '"default"' .firebaserc | awk -F'"' '{print $4}')
echo "Project: $PROJECT_ID"
echo ""

# Step 1: Check if authenticated
echo "Step 1: Checking Firebase authentication..."
if ! npx firebase projects:list > /dev/null 2>&1; then
    echo "❌ Not authenticated with Firebase"
    echo ""
    echo "Please run:"
    echo "  npx firebase login"
    echo ""
    echo "Then run this script again."
    exit 1
fi
echo "✅ Authenticated with Firebase"
echo ""

# Step 2: Deploy Functions
echo "Step 2: Deploying Cloud Functions..."
echo "  (This may take 1-2 minutes)"
echo ""

if npx firebase deploy --only functions 2>&1 | tee /tmp/deploy-functions.log; then
    echo "✅ Cloud Functions deployed successfully"
    if grep -q "forceLogoutOtherDevices" /tmp/deploy-functions.log; then
        echo "   ✓ forceLogoutOtherDevices function deployed"
    fi
else
    echo "❌ Cloud Functions deployment failed"
    echo ""
    echo "Check the error above and try again"
    exit 1
fi
echo ""

# Step 3: Deploy Rules
echo "Step 3: Deploying Firestore Rules..."
echo ""

if npx firebase deploy --only firestore:rules 2>&1 | tee /tmp/deploy-rules.log; then
    echo "✅ Firestore Rules deployed successfully"
else
    echo "❌ Firestore Rules deployment failed"
    echo ""
    echo "Check the error above and try again"
    exit 1
fi
echo ""

# Step 4: Verify Deployment
echo "Step 4: Verifying deployment..."
echo ""

# Check functions
echo "Checking deployed functions..."
if npx firebase functions:list 2>&1 | grep -q "forceLogoutOtherDevices"; then
    echo "✅ forceLogoutOtherDevices function is active"
else
    echo "⚠️  forceLogoutOtherDevices function not found in list"
fi
echo ""

# Summary
echo "================================================================================"
echo "                        DEPLOYMENT COMPLETE!"
echo "================================================================================"
echo ""
echo "✅ Cloud Functions deployed"
echo "✅ Firestore Rules deployed"
echo ""
echo "Next steps:"
echo "1. Run two emulators:"
echo "   Terminal 1: flutter run -d emulator-5554"
echo "   Terminal 2: flutter run -d emulator-5556"
echo ""
echo "2. On Device A (emulator-5554):"
echo "   - Login with: test@example.com / password123"
echo "   - Wait for app to fully load (30 seconds)"
echo ""
echo "3. On Device B (emulator-5556):"
echo "   - Login with SAME: test@example.com / password123"
echo "   - You should see loading spinner, then main app"
echo ""
echo "4. Expected Result:"
echo "   - Device A: Shows login screen (logged out) ✓"
echo "   - Device B: Shows main app (logged in) ✓"
echo ""
echo "Check Device A logs for:"
echo "   [DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED"
echo "   [RemoteLogout] ✓ Firebase sign out completed"
echo ""
echo "================================================================================"
echo ""
