@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo Logout Real Device Testing
echo ==========================================

REM Step 1: Build
echo.
echo STEP 1: Building APK...
call flutter clean
call flutter pub get
call flutter build apk --release

if errorlevel 1 (
    echo Error: Build failed!
    exit /b 1
)

echo Success: build\app\outputs\flutter-apk\app-release.apk

REM Step 2: Ask for device IDs
echo.
echo STEP 2: Device Setup
set /p DEVICE_A="Enter Device A serial (logged in device): "
set /p DEVICE_B="Enter Device B serial (logout device): "

if "%DEVICE_A%"=="" (
    echo Error: Device A serial required!
    exit /b 1
)
if "%DEVICE_B%"=="" (
    echo Error: Device B serial required!
    exit /b 1
)

REM Step 3: Install
echo.
echo STEP 3: Installing APK...
adb -s %DEVICE_A% install -r build\app\outputs\flutter-apk\app-release.apk
adb -s %DEVICE_B% install -r build\app\outputs\flutter-apk\app-release.apk

echo Installation complete

REM Step 4: Monitor logs
echo.
echo STEP 4: Monitoring logs (Device A)...
echo.
echo Instructions:
echo 1. On Device A: Open app - Login with email/password - Stay on home
echo 2. On Device B: Open app - Click "Already Logged In" - Click "Logout Other Device"
echo 3. Watch Device A: Should see red notification within 2-3 seconds
echo.
echo Logs will appear below. Press Ctrl+C to stop.
echo.

adb -s %DEVICE_A% logcat | findstr "[Poll] [DirectDetection] [ForceLogout] [RemoteLogout] [Logout] [RegisterDevice]"

pause
