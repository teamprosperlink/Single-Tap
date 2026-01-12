@echo off
REM Cloud Functions Deployment Script (Windows)
REM Run this when Blaze plan APIs are fully enabled

echo 🚀 Deploying Cloud Functions to Firebase...
echo.

REM Check if we're in the right directory
if not exist "functions" (
    echo Error: functions directory not found
    echo Please run this script from the project root
    exit /b 1
)

echo 📦 Deploying functions...
echo.

REM Deploy only functions
call npx firebase deploy --only functions

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Cloud Functions deployed successfully!
    echo.
    echo 📋 Deployed Functions:
    echo   - forceLogoutOtherDevices (Device logout)
    echo   - onMessageCreated (Push notifications)
    echo   - onCallCreated (Call notifications)
    echo   - onInquiryCreated (Inquiry notifications)
    echo.
    echo 🎉 Device logout feature is now live!
) else (
    echo.
    echo ❌ Deployment failed. Check the error above.
    echo.
    echo 💡 If you see 'missing required API' errors:
    echo    1. Wait 5-10 minutes for Blaze plan to fully activate
    echo    2. Manually enable APIs in Firebase Console:
    echo       https://console.firebase.google.com/project/dlink-f6cc9/settings/apis
    echo    3. Try again
    exit /b 1
)
