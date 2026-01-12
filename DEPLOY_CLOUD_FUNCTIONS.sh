#!/bin/bash

# Cloud Functions Deployment Script
# Run this when Blaze plan APIs are fully enabled

echo "🚀 Deploying Cloud Functions to Firebase..."
echo ""

cd "$(dirname "$0")"

# Check if Firebase CLI is available
if ! command -v firebase &> /dev/null && ! npx firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

echo "📦 Deploying functions..."
echo ""

# Deploy only functions
npx firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Cloud Functions deployed successfully!"
    echo ""
    echo "📋 Deployed Functions:"
    echo "  - forceLogoutOtherDevices (Device logout)"
    echo "  - onMessageCreated (Push notifications)"
    echo "  - onCallCreated (Call notifications)"
    echo "  - onInquiryCreated (Inquiry notifications)"
    echo ""
    echo "🎉 Device logout feature is now live!"
else
    echo ""
    echo "❌ Deployment failed. Check the error above."
    echo ""
    echo "💡 If you see 'missing required API' errors:"
    echo "   1. Wait 5-10 minutes for Blaze plan to fully activate"
    echo "   2. Manually enable APIs in Firebase Console:"
    echo "      https://console.firebase.google.com/project/dlink-f6cc9/settings/apis"
    echo "   3. Try again"
    exit 1
fi
