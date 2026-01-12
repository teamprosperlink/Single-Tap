@echo off
setlocal enabledelayedexpansion

echo ================================================================================
echo                   FIREBASE DEPLOYMENT SCRIPT
echo ================================================================================
echo.
echo This script will deploy Cloud Functions and Firestore Rules
echo Required for: Device A automatic logout when Device B logs in
echo.

REM Step 1: Check if authenticated
echo Step 1: Checking Firebase authentication...
npx firebase projects:list >nul 2>&1
if errorlevel 1 (
    echo.
    echo ❌ NOT AUTHENTICATED WITH FIREBASE
    echo.
    echo Please run:
    echo   npx firebase login
    echo.
    echo Then run this script again.
    echo.
    pause
    exit /b 1
)
echo ✅ Authenticated with Firebase
echo.

REM Step 2: Deploy Functions
echo Step 2: Deploying Cloud Functions...
echo   (This may take 1-2 minutes)
echo.

call npx firebase deploy --only functions
if errorlevel 1 (
    echo.
    echo ❌ Cloud Functions deployment FAILED
    echo.
    pause
    exit /b 1
)
echo ✅ Cloud Functions deployed successfully
echo.

REM Step 3: Deploy Rules
echo Step 3: Deploying Firestore Rules...
echo.

call npx firebase deploy --only firestore:rules
if errorlevel 1 (
    echo.
    echo ❌ Firestore Rules deployment FAILED
    echo.
    pause
    exit /b 1
)
echo ✅ Firestore Rules deployed successfully
echo.

REM Step 4: Summary
echo ================================================================================
echo                        DEPLOYMENT COMPLETE!
echo ================================================================================
echo.
echo ✅ Cloud Functions deployed
echo ✅ Firestore Rules deployed
echo.
echo Next steps:
echo 1. Run two emulators:
echo    Terminal 1: flutter run -d emulator-5554
echo    Terminal 2: flutter run -d emulator-5556
echo.
echo 2. On Device A (emulator-5554):
echo    - Login with: test@example.com / password123
echo    - Wait for app to fully load (30 seconds)
echo.
echo 3. On Device B (emulator-5556):
echo    - Login with SAME: test@example.com / password123
echo    - You should see loading spinner, then main app
echo.
echo 4. Expected Result:
echo    - Device A: Shows login screen (logged out) ✓
echo    - Device B: Shows main app (logged in) ✓
echo.
echo Check Device A logs for:
echo    [DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED
echo    [RemoteLogout] ✓ Firebase sign out completed
echo.
echo ================================================================================
echo.
pause
