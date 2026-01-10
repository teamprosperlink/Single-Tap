#!/bin/bash

echo "=========================================="
echo "Logout Real Device Testing"
echo "=========================================="

# Step 1: Build
echo ""
echo "STEP 1: Building APK..."
flutter clean
flutter pub get
flutter build apk --release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful: build/app/outputs/flutter-apk/app-release.apk"

# Step 2: Ask for device IDs
echo ""
echo "STEP 2: Device Setup"
read -p "Enter Device A serial (logged in device): " DEVICE_A
read -p "Enter Device B serial (logout device): " DEVICE_B

if [ -z "$DEVICE_A" ] || [ -z "$DEVICE_B" ]; then
    echo "❌ Device IDs required!"
    exit 1
fi

# Step 3: Install
echo ""
echo "STEP 3: Installing APK..."
adb -s $DEVICE_A install -r build/app/outputs/flutter-apk/app-release.apk
adb -s $DEVICE_B install -r build/app/outputs/flutter-apk/app-release.apk

echo "✅ Installation complete"

# Step 4: Monitor logs
echo ""
echo "STEP 4: Monitoring logs (Device A)..."
echo ""
echo "Instructions:"
echo "1. On Device A: Open app → Login with email/password → Stay on home"
echo "2. On Device B: Open app → Click 'Already Logged In' → Click 'Logout Other Device'"
echo "3. Watch Device A: Should see red notification within 2-3 seconds"
echo ""
echo "Logs will appear below. Press Ctrl+C to stop."
echo ""

adb -s $DEVICE_A logcat | grep -E "\[Poll\]|\[DirectDetection\]|\[ForceLogout\]|\[RemoteLogout\]|\[Logout\]|\[RegisterDevice\]"
