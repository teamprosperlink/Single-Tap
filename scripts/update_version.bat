@echo off
REM Version Update Script for Supper App (Windows)
REM Usage: scripts\update_version.bat <version_type> [description]
REM version_type: major, minor, patch

setlocal enabledelayedexpansion

set VERSION_TYPE=%1
set DESCRIPTION=%2

if "%VERSION_TYPE%"=="" (
    echo Usage: scripts\update_version.bat ^<major^|minor^|patch^> [description]
    echo.
    echo Examples:
    echo   scripts\update_version.bat patch "Fixed voice call bug"
    echo   scripts\update_version.bat minor "Added new matching algorithm"
    echo   scripts\update_version.bat major "Complete redesign"
    exit /b 1
)

REM Get current version from pubspec.yaml
for /f "tokens=2" %%i in ('findstr /r "^version:" pubspec.yaml') do set CURRENT_VERSION=%%i

REM Split version and build number
for /f "tokens=1 delims=+" %%a in ("%CURRENT_VERSION%") do set CURRENT_VERSION_NUMBER=%%a
for /f "tokens=2 delims=+" %%b in ("%CURRENT_VERSION%") do set CURRENT_BUILD_NUMBER=%%b

REM Split version into parts
for /f "tokens=1,2,3 delims=." %%a in ("%CURRENT_VERSION_NUMBER%") do (
    set MAJOR=%%a
    set MINOR=%%b
    set PATCH=%%c
)

REM Increment based on type
if "%VERSION_TYPE%"=="major" (
    set /a MAJOR=MAJOR+1
    set MINOR=0
    set PATCH=0
) else if "%VERSION_TYPE%"=="minor" (
    set /a MINOR=MINOR+1
    set PATCH=0
) else if "%VERSION_TYPE%"=="patch" (
    set /a PATCH=PATCH+1
) else (
    echo Invalid version type. Use: major, minor, or patch
    exit /b 1
)

REM Increment build number
set /a NEW_BUILD_NUMBER=CURRENT_BUILD_NUMBER+1
set NEW_VERSION=%MAJOR%.%MINOR%.%PATCH%+%NEW_BUILD_NUMBER%

echo Current version: %CURRENT_VERSION%
echo New version: %NEW_VERSION%
echo.

REM Update pubspec.yaml (Windows compatible)
powershell -Command "(Get-Content pubspec.yaml) -replace '^version:.*', 'version: %NEW_VERSION%' | Set-Content pubspec.yaml"

echo Updated pubspec.yaml
echo.
echo Next steps:
echo 1. Update CHANGELOG.md with your changes
echo 2. Review and commit: git add pubspec.yaml CHANGELOG.md
echo 3. Commit: git commit -m "Bump version to %NEW_VERSION%"
echo 4. Tag: git tag -a v%MAJOR%.%MINOR%.%PATCH% -m "Version %MAJOR%.%MINOR%.%PATCH%"
echo.

endlocal
